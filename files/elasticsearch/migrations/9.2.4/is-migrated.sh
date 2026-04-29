#!/usr/bin/env bash
set -euo pipefail

MARKER="$(dirname "${BASH_SOURCE[0]}")/.done"
[[ -f "$MARKER" ]] && { echo "Sentinel file found — migration to 9.2.4 was already completed. Skipping."; exit 0; }

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
# shellcheck source=../../lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib.sh"

TARGET="9.2.4"

current=$(curl -sf --connect-timeout 10 "${_ES_CURL_AUTH[@]:+${_ES_CURL_AUTH[@]}}" "$ES_URL" 2>/dev/null \
    | grep -o '"number":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

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
