#!/usr/bin/env bash
set -Eeuo pipefail

ops_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  must_run "scripts/ops/monitors-install.sh"
  log "[ops] done"
}
