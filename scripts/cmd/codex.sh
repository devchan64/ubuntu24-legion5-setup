#!/usr/bin/env bash
# file: scripts/cmd/codex.sh
set -Eeuo pipefail
set -o errtrace

codex_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:codex}"

  resume_step "${resume_scope}" "codex:cli:install" \
    -- \
    must_run_or_throw "scripts/codex/install-cli.sh"

  resume_step "${resume_scope}" "codex:remote-control:service" \
    -- \
    must_run_or_throw "scripts/codex/remote-control-service.sh"

  resume_step "${resume_scope}" "codex:remote-control:service-unit-v2" \
    -- \
    must_run_or_throw "scripts/codex/remote-control-service.sh"

  resume_step "${resume_scope}" "codex:remote-control:linger" \
    -- \
    must_run_or_throw "scripts/codex/remote-control-linger.sh"

  log "[codex] 완료"
}

codex_main "$@"
