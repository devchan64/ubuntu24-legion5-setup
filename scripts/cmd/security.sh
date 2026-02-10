#!/usr/bin/env bash
set -Eeuo pipefail

security_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:security}"

  resume_run_step_or_throw "$RESUME_SCOPE" "security:install" -- must_run "scripts/security/install.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "security:first scan" -- must_run "scripts/security/scan.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "security:summarize scan" -- must_run "scripts/security/summarize-last-scan.sh"

  log "[security] done"
}
