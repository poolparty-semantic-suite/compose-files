#!/usr/bin/env bash
set -euo pipefail

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
# shellcheck source=../../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib.sh"

require_es

echo "Checking deprecation warnings..."
deprecations=$(es_curl "/_migration/deprecations")
critical_count=$(echo "$deprecations" | grep -c '"level":"critical"' || true)
if [[ "$critical_count" -gt 0 ]]; then
    echo "ERROR: $critical_count critical deprecation(s) found — resolve before upgrading to 9.x." >&2
    echo "$deprecations" >&2
    echo "  → For readable output: curl -s '$ES_URL/_migration/deprecations' | python3 -m json.tool" >&2
    exit 1
fi
warning_count=$(echo "$deprecations" | grep -c '"level":"warning"' || true)
echo "Deprecation check: 0 critical, $warning_count warning(s) — proceeding"

response=$(es_curl "/_cluster/settings" \
    -X PUT \
    -H 'Content-Type: application/json' \
    -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}')
echo "$response" | grep -q '"acknowledged":true' \
    || { echo "ERROR: Cluster settings update was not acknowledged by Elasticsearch." >&2; exit 1; }
echo "Shard allocation restricted to primaries"

es_curl "/_flush" -X POST > /dev/null
echo "Indices flushed"
