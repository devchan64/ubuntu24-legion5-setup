#!/usr/bin/env bash
set -Eeuo pipefail

ops_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:ops}"

  resume_run_step_or_throw "$RESUME_SCOPE" "ops:monitors install" -- must_run "scripts/ops/monitors-install.sh"
  log "[ops] done"
}
