#!/usr/bin/env bash
set -euo pipefail

TARGET="9.2.5"
MARKER="$(dirname "${BASH_SOURCE[0]}")/.done"
ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
# shellcheck source=../shared.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared.sh"

check_is_migrated
