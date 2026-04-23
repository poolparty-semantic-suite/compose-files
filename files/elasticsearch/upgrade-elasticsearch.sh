#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
ES_SERVICE_PATTERN="${ES_SERVICE_PATTERN:-elasticsearch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
ENV_FILE="$PROJECT_DIR/.env"
SNAPSHOT_REPO="${SNAPSHOT_REPO:-backup}"
KNOWN_VERSIONS=("8.19.13" "9.2.4")

# Timeout overrides (seconds)
SHARD_DRAIN_TIMEOUT="${SHARD_DRAIN_TIMEOUT:-600}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-300}"
NODE_REJOIN_TIMEOUT="${NODE_REJOIN_TIMEOUT:-120}"

# ── Bootstrap: credentials ────────────────────────────────────────────────────
# _env_val is defined early because it is needed before lib.sh is sourced.
# It handles values with = in them (cut -f2-) and strips surrounding quotes.
_env_val() {
    local raw
    raw=$(grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-) || true
    raw="${raw#\"}" ; raw="${raw%\"}"
    raw="${raw#\'}" ; raw="${raw%\'}"
    printf '%s' "$raw"
}

: "${POOLPARTY_INDEX_USERNAME:=$(_env_val POOLPARTY_INDEX_USERNAME)}"
: "${POOLPARTY_INDEX_PASSWORD:=$(_env_val POOLPARTY_INDEX_PASSWORD)}"
export POOLPARTY_INDEX_USERNAME POOLPARTY_INDEX_PASSWORD

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# ── Utilities ─────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

# ── Health helpers ────────────────────────────────────────────────────────────

wait_for_healthy() {
    local required="${1:-${EXPECTED_HEALTH_STATUS:-yellow}}"
    local deadline=$((SECONDS + HEALTH_TIMEOUT))
    log "Waiting for cluster health: $required or better (timeout: ${HEALTH_TIMEOUT}s)..."
    while [[ $SECONDS -lt $deadline ]]; do
        local status
        status=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
            "$ES_URL/_cluster/health" 2>/dev/null \
            | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        health_ok "$status" "$required" && { log "Cluster health: $status"; return 0; }
        sleep 5
    done
    echo "ERROR: Elasticsearch did not reach '$required' health within ${HEALTH_TIMEOUT}s." >&2
    echo "  → Status:  docker compose ps" >&2
    echo "  → Logs:    docker compose logs --tail=100 $(printf '"%s" ' "${ES_SERVICES[@]}")" >&2
    echo "  → Check:   $ES_URL/_cluster/health" >&2
    exit 1
}

# ── Cluster rolling-restart helpers ───────────────────────────────────────────

# Tracks which nodes we have excluded so undrain removes only the target node
# rather than clearing all exclusions globally.
_EXCLUDED_NODES=()

_sync_allocation_exclusions() {
    local value
    if [[ ${#_EXCLUDED_NODES[@]} -eq 0 ]]; then
        value='null'
    else
        local list
        list=$(IFS=','; printf '%s' "${_EXCLUDED_NODES[*]}")
        value="\"${list}\""
    fi
    local response
    response=$(es_curl "/_cluster/settings" \
        -X PUT -H 'Content-Type: application/json' \
        -d "{\"transient\":{\"cluster.routing.allocation.exclude._name\":${value}}}")
    echo "$response" | grep -q '"acknowledged":true' \
        || { echo "ERROR: Failed to sync shard allocation exclusions." >&2; exit 1; }
}

drain_node() {
    local node_name="$1"
    _EXCLUDED_NODES+=("$node_name")
    _sync_allocation_exclusions
    log "Node '$node_name' excluded from shard allocation"
}

undrain_node() {
    local node_name="$1"
    local remaining=()
    if [[ ${#_EXCLUDED_NODES[@]} -gt 0 ]]; then
        for n in "${_EXCLUDED_NODES[@]}"; do
            [[ "$n" != "$node_name" ]] && remaining+=("$n")
        done
    fi
    _EXCLUDED_NODES=("${remaining[@]:+${remaining[@]}}")
    _sync_allocation_exclusions
    log "Node '$node_name' re-included in shard allocation"
}

wait_for_shards_drained() {
    local node_name="$1"
    local deadline=$((SECONDS + SHARD_DRAIN_TIMEOUT))
    log "Waiting for primary shards to drain from '$node_name' (timeout: ${SHARD_DRAIN_TIMEOUT}s)..."
    while [[ $SECONDS -lt $deadline ]]; do
        local count
        count=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
            "$ES_URL/_cat/shards?h=node,prirep" 2>/dev/null \
            | awk -v n="$node_name" '$1 == n && $2 == "p" {c++} END {print c+0}')
        [[ "$count" -eq 0 ]] && return 0
        log "  $count primary shard(s) still on '$node_name'..."
        sleep 10
    done
    die "Primary shards did not drain from '$node_name' within ${SHARD_DRAIN_TIMEOUT}s"
}

wait_for_node_rejoin() {
    local node_name="$1"
    local deadline=$((SECONDS + NODE_REJOIN_TIMEOUT))
    log "Waiting for node '$node_name' to rejoin (timeout: ${NODE_REJOIN_TIMEOUT}s)..."
    while [[ $SECONDS -lt $deadline ]]; do
        # Exact line match (-x) prevents 'elasticsearch' matching 'elasticsearch2'
        curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
            "$ES_URL/_cat/nodes?h=name" 2>/dev/null \
            | grep -qxF "$node_name" \
            && { log "Node '$node_name' has rejoined"; return 0; }
        sleep 5
    done
    die "Node '$node_name' did not rejoin within ${NODE_REJOIN_TIMEOUT}s — check: docker compose logs $node_name"
}

validate_node_names() {
    local nodes
    # Use es_curl so connectivity failures produce the standard diagnostic
    nodes=$(es_curl "/_cat/nodes?h=name")
    for svc in "${ES_SERVICES[@]}"; do
        # Exact line match (-x) prevents 'elasticsearch' matching 'elasticsearch2'
        printf '%s\n' "$nodes" | grep -qxF "$svc" && continue
        echo "ERROR: No ES node named '$svc' found in the cluster." >&2
        echo "  → Known nodes: $(printf '%s\n' "$nodes" | tr '\n' ' ')" >&2
        echo "  → ES uses the container hostname as node.name by default." >&2
        echo "  → If node.name is overridden in your ES config, set ES_SERVICE_PATTERN" >&2
        echo "    to a prefix that matches the actual node names instead." >&2
        exit 1
    done
}

rolling_restart() {
    if [[ "$IS_CLUSTER" == "true" ]]; then
        validate_node_names
    fi

    local total=${#ES_SERVICES[@]}
    local i=0
    for svc in "${ES_SERVICES[@]}"; do
        i=$((i + 1))

        if [[ "$IS_CLUSTER" == "true" ]]; then
            log "Rolling restart $i/$total: $svc"
            drain_node "$svc"
            wait_for_shards_drained "$svc"
        fi

        docker compose -f "$PROJECT_DIR/docker-compose.yaml" --env-file "$ENV_FILE" \
            up -d "$svc" \
            || die "docker compose up failed for $svc — check: docker compose logs $svc"

        if [[ "$IS_CLUSTER" == "true" ]]; then
            wait_for_node_rejoin "$svc"
            undrain_node "$svc"
            # Stabilise before the next node
            [[ $i -lt $total ]] && wait_for_healthy "yellow"
        fi
    done

    wait_for_healthy
}

# ── Snapshot ──────────────────────────────────────────────────────────────────

take_snapshot() {
    local target="$1"
    local name="pre-upgrade-to-${target}-$(date '+%Y%m%d%H%M%S')"

    log "Taking snapshot '$name' in repository '$SNAPSHOT_REPO'..."
    # wait_for_completion=false ensures the response is always {"accepted":true},
    # even on fast/small clusters that would otherwise return synchronously.
    local response
    response=$(es_curl "/_snapshot/$SNAPSHOT_REPO/$name?wait_for_completion=false" \
        -X PUT -H 'Content-Type: application/json' \
        -d '{"ignore_unavailable":true,"include_global_state":true}')
    echo "$response" | grep -q '"accepted":true' \
        || die "Snapshot '$name' was not accepted — check: docker compose logs $(printf '"%s" ' "${ES_SERVICES[@]}")"

    local deadline=$((SECONDS + 1800))
    local state=""
    while [[ $SECONDS -lt $deadline ]]; do
        state=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
            "$ES_URL/_snapshot/$SNAPSHOT_REPO/$name" 2>/dev/null \
            | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        case "$state" in
            SUCCESS) log "Snapshot '$name' complete"; return 0 ;;
            FAILED|PARTIAL) die "Snapshot '$name' ended with state '$state' — check: docker compose logs $(printf '"%s" ' "${ES_SERVICES[@]}")" ;;
        esac
        sleep 10
    done
    die "Snapshot '$name' did not complete within 30 minutes"
}

# ── State management ──────────────────────────────────────────────────────────

set_version_in_env() {
    sed -i.bak "s|^ELASTICSEARCH_VERSION=.*|ELASTICSEARCH_VERSION=$1|" "$ENV_FILE"
    rm -f "$ENV_FILE.bak"
}

# ── Argument parsing ──────────────────────────────────────────────────────────

FROM_VERSION=""
TO_VERSION=""
SNAPSHOT=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)     FROM_VERSION="$2"; shift 2 ;;
        --to)       TO_VERSION="$2";   shift 2 ;;
        --snapshot) SNAPSHOT=true;     shift   ;;
        *)          die "Unknown argument: $1" ;;
    esac
done

if [[ -z "$FROM_VERSION" ]]; then
    FROM_VERSION=$(_env_val ELASTICSEARCH_VERSION)
    [[ -n "$FROM_VERSION" ]] || die "Cannot detect current version from $ENV_FILE; pass --from <version>"
    log "Detected current version from .env: $FROM_VERSION"
fi
[[ -n "$TO_VERSION" ]] || die "--to <version> is required"

version_known=false
for v in "${KNOWN_VERSIONS[@]}"; do
    [[ "$v" == "$TO_VERSION" ]] && version_known=true && break
done
$version_known || die "Unknown target version '$TO_VERSION' (known: ${KNOWN_VERSIONS[*]})"

steps=()
for v in "${KNOWN_VERSIONS[@]}"; do
    if [[ "$(printf '%s\n' "$FROM_VERSION" "$v" | sort -V | head -1)" == "$v" ]]; then
        continue
    fi
    steps+=("$v")
    [[ "$v" == "$TO_VERSION" ]] && break
done

[[ ${#steps[@]} -gt 0 ]] || die "No upgrade steps found for $FROM_VERSION → $TO_VERSION"

# ── Pre-flight ────────────────────────────────────────────────────────────────

require_es

node_count=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
    "$ES_URL/_cat/nodes?h=name" 2>/dev/null | wc -l | tr -d '[:space:]')
node_count="${node_count:-1}"
IS_CLUSTER=false
[[ "$node_count" -gt 1 ]] && IS_CLUSTER=true

if [[ "$IS_CLUSTER" == "true" ]]; then
    log "Topology: cluster ($node_count nodes)"
else
    log "Topology: single-node"
fi

ES_SERVICES=()
while IFS= read -r svc; do
    [[ -n "$svc" ]] && ES_SERVICES+=("$svc")
done < <(docker compose -f "$PROJECT_DIR/docker-compose.yaml" config --services 2>/dev/null \
    | grep -E "^${ES_SERVICE_PATTERN}")

[[ ${#ES_SERVICES[@]} -gt 0 ]] \
    || die "No compose services matching pattern '${ES_SERVICE_PATTERN}' found.
  → Set ES_SERVICE_PATTERN=<prefix> to match your service names."
log "Elasticsearch service(s): ${ES_SERVICES[*]}"

EXPECTED_HEALTH_STATUS="yellow"
[[ "$IS_CLUSTER" == "true" ]] && EXPECTED_HEALTH_STATUS="green"
export EXPECTED_HEALTH_STATUS

log "Upgrade path: $FROM_VERSION → $(IFS=' → '; echo "${steps[*]}")"

if $SNAPSHOT; then
    curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" "$ES_URL/_snapshot/$SNAPSHOT_REPO" \
        > /dev/null 2>&1 || {
        echo "ERROR: Snapshot repository '$SNAPSHOT_REPO' was not found in Elasticsearch." >&2
        echo "  → Create the repository before running with --snapshot." >&2
        echo "  → Repository name (override with SNAPSHOT_REPO=<name>): $SNAPSHOT_REPO" >&2
        exit 1
    }
    log "Snapshot repository '$SNAPSHOT_REPO' verified"
fi

# ── Main upgrade loop ─────────────────────────────────────────────────────────

for target in "${steps[@]}"; do
    mig_dir="$MIGRATIONS_DIR/$target"
    [[ -d "$mig_dir" ]] || die "Migration directory not found: $mig_dir"

    log "────────────────────────────────────────────"
    log "Step: upgrading to $target"

    if bash "$mig_dir/is-migrated.sh"; then
        log "Already migrated to $target — skipping"
        continue
    fi

    $SNAPSHOT && take_snapshot "$target"

    log "Running pre-upgrade for $target"
    bash "$mig_dir/pre-upgrade.sh" \
        || die "pre-upgrade.sh failed for $target"

    # Patch .env before rolling_restart (docker compose reads it for the image tag).
    # Register a trap to restore the previous version if rolling_restart fails,
    # keeping .env consistent with what is actually running.
    old_version=$(_env_val ELASTICSEARCH_VERSION)
    log "Updating .env: ELASTICSEARCH_VERSION=$target"
    set_version_in_env "$target"
    trap "set_version_in_env '$old_version'" EXIT

    log "Restarting Elasticsearch to $target"
    rolling_restart

    trap - EXIT  # Clear restore trap — restart succeeded

    log "Running post-upgrade for $target"
    bash "$mig_dir/post-upgrade.sh" \
        || die "post-upgrade.sh failed for $target"

    log "Successfully upgraded to $target"
done

log "────────────────────────────────────────────"
log "Upgrade complete. Elasticsearch is now at $TO_VERSION."
