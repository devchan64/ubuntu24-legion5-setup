#!/usr/bin/env bash
set -Eeuo pipefail

security_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  must_run "scripts/security/install.sh"
  must_run "scripts/security/scan.sh"          || err "first scan failed"
  must_run "scripts/security/summarize-last-scan.sh"

  log "[security] done"
}
