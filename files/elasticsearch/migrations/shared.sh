# shellcheck source=../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib.sh"

check_is_migrated() {
    [[ -f "$MARKER" ]] && { echo "Sentinel file found — migration to $TARGET was already completed. Skipping."; exit 0; }

    local current
    current=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]:+${_ES_CURL_AUTH[@]}}" "$ES_URL" 2>/dev/null \
        | grep -o '"number"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4 || true)

    if [[ -z "$current" ]]; then
        echo "WARNING: Could not reach Elasticsearch at '$ES_URL' — assuming not yet migrated to $TARGET" >&2
        echo "  → If ES is running, check POOLPARTY_INDEX_URL." >&2
        exit 1
    fi

    if [[ "$(printf '%s\n' "$TARGET" "$current" | sort -V | head -1)" == "$TARGET" ]]; then
        touch "$MARKER"
        exit 0
    fi

    exit 1
}

run_pre_upgrade() {
    local check_deprecations=false
    for arg in "$@"; do [[ "$arg" == "--deprecations" ]] && check_deprecations=true; done

    require_es

    if $check_deprecations; then
        echo "Checking deprecation warnings..."
        local deprecations
        deprecations=$(es_curl "/_migration/deprecations")
        local critical_count
        critical_count=$(echo "$deprecations" | grep -c '"level"\s*:\s*"critical"' || true)
        if [[ "$critical_count" -gt 0 ]]; then
            echo "ERROR: $critical_count critical deprecation(s) found — resolve before upgrading to 9.x." >&2
            echo "$deprecations" >&2
            echo "  → For readable output: curl -s '$ES_URL/_migration/deprecations' | python3 -m json.tool" >&2
            exit 1
        fi
        local warning_count
        warning_count=$(echo "$deprecations" | grep -c '"level"\s*:\s*"warning"' || true)
        echo "Deprecation check: 0 critical, $warning_count warning(s) — proceeding"
    fi

    local response
    response=$(es_curl "/_cluster/settings" \
        -X PUT \
        -H 'Content-Type: application/json' \
        -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}')
    echo "$response" | grep -q '"acknowledged"\s*:\s*true' \
        || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
    echo "Shard allocation restricted to primaries"

    es_curl "/_flush" -X POST > /dev/null
    echo "Indices flushed"
}

run_post_upgrade() {
    local check_red_indices=false
    for arg in "$@"; do [[ "$arg" == "--red-indices" ]] && check_red_indices=true; done

    require_es

    local actual
    actual=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]:+${_ES_CURL_AUTH[@]}}" "$ES_URL" 2>/dev/null \
        | grep -o '"number"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if [[ "$actual" != "$TARGET" ]]; then
        echo "ERROR: Expected Elasticsearch $TARGET but found '${actual:-unknown}' — upgrade may not have applied." >&2
        exit 1
    fi
    echo "Version check passed: Elasticsearch $actual"

    local response
    response=$(es_curl "/_cluster/settings" \
        -X PUT \
        -H 'Content-Type: application/json' \
        -d '{"persistent":{"cluster.routing.allocation.enable":null}}')
    echo "$response" | grep -q '"acknowledged"\s*:\s*true' \
        || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
    echo "Shard allocation re-enabled"

    if $check_red_indices; then
        echo "Checking index health..."
        local red_indices
        red_indices=$(es_curl "/_cat/indices?h=index,health&format=json" \
            | grep '"health"\s*:\s*"red"' || true)
        if [[ -n "$red_indices" ]]; then
            echo "ERROR: Found red indices after upgrade:" >&2
            echo "$red_indices" >&2
            echo "  → These indices have unassigned primary shards and may require manual recovery." >&2
            echo "  → Check: $ES_URL/_cat/indices?v&health=red" >&2
            exit 1
        fi
        echo "Index health check passed — no red indices"
    fi

    local deadline
    deadline=$((SECONDS + ${HEALTH_TIMEOUT:-120}))
    local status=""
    while [[ $SECONDS -lt $deadline ]]; do
        status=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]:+${_ES_CURL_AUTH[@]}}" \
            "$ES_URL/_cluster/health" 2>/dev/null \
            | grep -o '"status"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4 || true)
        health_ok "$status" && break
        sleep 5
    done

    if ! health_ok "$status"; then
        echo "ERROR: Cluster health is '$status' (expected: ${EXPECTED_HEALTH_STATUS:-yellow} or better)." >&2
        echo "  → Logs:  docker compose logs --tail=100 elasticsearch" >&2
        echo "  → Check: $ES_URL/_cluster/health" >&2
        exit 1
    fi
    echo "Cluster health: $status"

    touch "$MARKER"
    echo "Migration to $TARGET marked complete"
}
