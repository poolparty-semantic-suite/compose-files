#!/usr/bin/env bash
# Shared helpers — source this file; requires ES_URL to be set by the caller.
# Optional: set POOLPARTY_INDEX_USERNAME and POOLPARTY_INDEX_PASSWORD for basic auth.

# Build auth args once at source time; empty array when no credentials are configured.
_ES_CURL_AUTH=()
if [[ -n "${POOLPARTY_INDEX_USERNAME:-}" && -n "${POOLPARTY_INDEX_PASSWORD:-}" ]]; then
    _ES_CURL_AUTH=(-u "${POOLPARTY_INDEX_USERNAME}:${POOLPARTY_INDEX_PASSWORD}")
fi

# Returns 0 if status meets the required health level.
# required defaults to EXPECTED_HEALTH_STATUS (set by the orchestrator) or "yellow".
health_ok() {
    local status="$1" required="${2:-${EXPECTED_HEALTH_STATUS:-yellow}}"
    [[ "$status" == "green" ]] || [[ "$status" == "yellow" && "$required" == "yellow" ]]
}

_es_curl_error() {
    local exit_code="$1" endpoint="$2"
    echo "ERROR: Cannot reach Elasticsearch at '${ES_URL}${endpoint}'" >&2
    case "$exit_code" in
        6)  echo "  → Hostname could not be resolved." >&2
            echo "    Verify the host portion of POOLPARTY_INDEX_URL (currently: $ES_URL)." >&2 ;;
        7)  echo "  → Connection refused — Elasticsearch is not running or not yet ready." >&2
            echo "    Status:  docker compose ps" >&2
            echo "    Logs:    docker compose logs --tail=50 <elasticsearch-service>" >&2 ;;
        22) echo "  → Elasticsearch returned an HTTP error." >&2
            if [[ -z "${POOLPARTY_INDEX_USERNAME:-}" ]]; then
                echo "  → If ES security is enabled, set POOLPARTY_INDEX_USERNAME and POOLPARTY_INDEX_PASSWORD." >&2
            fi
            echo "    Logs:    docker compose logs --tail=50 <elasticsearch-service>" >&2 ;;
        28) echo "  → Connection timed out." >&2
            echo "    Check network connectivity and firewall rules between this host and ES." >&2 ;;
        *)  echo "  → curl exit code: $exit_code." >&2 ;;
    esac
    echo "  → To override the URL: POOLPARTY_INDEX_URL=http://<host>:9200 $0" >&2
}

# Verifies ES is reachable; dies with an actionable message if not.
require_es() {
    local exit_code=0
    curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" "$ES_URL" > /dev/null 2>&1 || exit_code=$?
    [[ $exit_code -eq 0 ]] && return 0
    _es_curl_error "$exit_code" ""
    exit 1
}

# Wraps curl for ES API calls; dies with endpoint-specific context on failure.
# Usage: es_curl <endpoint> [extra curl args...]
es_curl() {
    local endpoint="$1"; shift
    local response exit_code=0
    response=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" "$ES_URL$endpoint" "$@" 2>/dev/null) \
        || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        _es_curl_error "$exit_code" "$endpoint"
        exit 1
    fi
    echo "$response"
}
