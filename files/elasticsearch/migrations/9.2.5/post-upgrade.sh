#!/usr/bin/env bash
set -euo pipefail

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
MARKER="$(dirname "${BASH_SOURCE[0]}")/.done"
# shellcheck source=../../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib.sh"

require_es

TARGET="9.2.5"
actual=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]:+${_ES_CURL_AUTH[@]}}" "$ES_URL" 2>/dev/null \
    | grep -o '"number"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4 || true)
if [[ "$actual" != "$TARGET" ]]; then
    echo "ERROR: Expected Elasticsearch $TARGET but found '${actual:-unknown}' — upgrade may not have applied." >&2
    exit 1
fi
echo "Version check passed: Elasticsearch $actual"

response=$(es_curl "/_cluster/settings" \
    -X PUT \
    -H 'Content-Type: application/json' \
    -d '{"persistent":{"cluster.routing.allocation.enable":null}}')
echo "$response" | grep -q '"acknowledged"\s*:\s*true' \
    || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
echo "Shard allocation re-enabled"

echo "Checking index health..."
red_indices=$(es_curl "/_cat/indices?h=index,health&format=json" \
    | grep '"health"\s*:\s*"red"' || true)
if [[ -n "$red_indices" ]]; then
    echo "ERROR: Found red indices after major version upgrade:" >&2
    echo "$red_indices" >&2
    echo "  → These indices have unassigned primary shards and may require manual recovery." >&2
    echo "  → Check: $ES_URL/_cat/indices?v&health=red" >&2
    exit 1
fi
echo "Index health check passed — no red indices"

deadline=$((SECONDS + ${HEALTH_TIMEOUT:-120}))
status=""
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
echo "Migration to 9.2.5 marked complete"
