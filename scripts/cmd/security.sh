#!/usr/bin/env bash
# file: scripts/cmd/security.sh
set -Eeuo pipefail
set -o errtrace

security_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:security}"

  resume_step "${resume_scope}" "security:install" \
    must_run_or_throw "scripts/security/install.sh"

  resume_step "${resume_scope}" "security:scan:first" \
    must_run_or_throw "scripts/security/scan.sh"

  resume_step "${resume_scope}" "security:scan:summarize:last" \
    must_run_or_throw "scripts/security/summarize-last-scan.sh"

  log "[security] done"
}

security_main "$@"
