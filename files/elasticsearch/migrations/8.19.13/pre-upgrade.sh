#!/usr/bin/env bash
set -euo pipefail

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
# shellcheck source=../../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib.sh"

require_es

response=$(es_curl "/_cluster/settings" \
    -X PUT \
    -H 'Content-Type: application/json' \
    -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}')
echo "$response" | grep -q '"acknowledged":true' \
    || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
echo "Shard allocation restricted to primaries"

es_curl "/_flush" -X POST > /dev/null
echo "Indices flushed"
