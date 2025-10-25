#!/usr/bin/env bash
set -Eeuo pipefail

net_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  must_run "scripts/net/tools-install.sh"
  log "[net] done"
}
