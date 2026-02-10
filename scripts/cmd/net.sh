#!/usr/bin/env bash
set -Eeuo pipefail

net_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:net}"

  resume_run_step_or_throw "$RESUME_SCOPE" "net:tools install" -- must_run "scripts/net/tools-install.sh"
  log "[net] done"
}
