#!/usr/bin/env bash
set -euo pipefail

ES_URL="${POOLPARTY_INDEX_URL:-http://localhost:9200}"
# shellcheck source=../shared.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared.sh"

run_pre_upgrade
