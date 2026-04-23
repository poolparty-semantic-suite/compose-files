#!/usr/bin/env bash
set -euo pipefail

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
MARKER="$(dirname "${BASH_SOURCE[0]}")/.done"
# shellcheck source=../../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib.sh"

require_es

response=$(es_curl "/_cluster/settings" \
    -X PUT \
    -H 'Content-Type: application/json' \
    -d '{"persistent":{"cluster.routing.allocation.enable":null}}')
echo "$response" | grep -q '"acknowledged":true' \
    || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
echo "Shard allocation re-enabled"

deadline=$((SECONDS + 120))
status=""
while [[ $SECONDS -lt $deadline ]]; do
    status=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]}" \
        "$ES_URL/_cluster/health" 2>/dev/null \
        | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
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
echo "Migration to 8.19.13 marked complete"
