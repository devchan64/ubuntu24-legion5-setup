#!/usr/bin/env bash
# file: scripts/cmd/ops.sh
set -Eeuo pipefail
set -o errtrace

ops_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:ops}"

  resume_step "${resume_scope}" "ops:monitors:install" \
    must_run_or_throw "scripts/ops/monitors-install.sh"

  log "[ops] done"
}

ops_main "$@"
