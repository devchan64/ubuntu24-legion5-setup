#!/usr/bin/env bash
# file: scripts/cmd/dev.sh
set -Eeuo pipefail
set -o errtrace

dev_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:dev}"

  resume_step "${resume_scope}" "dev:docker:install" \
    must_run_or_throw "scripts/dev/docker/install.sh"

  resume_step "${resume_scope}" "dev:node:install" \
    must_run_or_throw "scripts/dev/node/install.sh"

  resume_step "${resume_scope}" "dev:python:install" \
    must_run_or_throw "scripts/dev/python/install.sh"

  resume_step "${resume_scope}" "dev:vscode:install" \
    must_run_or_throw "scripts/dev/editors/install-vscode.sh"

  resume_step "${resume_scope}" "dev:vscode:extensions" \
    must_run_or_throw "scripts/dev/editors/install-extensions.sh"

  resume_step "${resume_scope}" "dev:nvidia-toolkit" \
    must_run_or_throw "scripts/dev/docker/nvidia-toolkit.sh"

  resume_step "${resume_scope}" "dev:github:web-login" \
    must_run_or_throw "scripts/dev/github-web-login.sh"

  log "[dev] done"
}

dev_main "$@"
