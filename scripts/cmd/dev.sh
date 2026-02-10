#!/usr/bin/env bash
set -Eeuo pipefail

dev_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:dev}"

  resume_run_step_or_throw "$RESUME_SCOPE" "dev:docker install" -- must_run "scripts/dev/docker/install.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:node install" -- must_run "scripts/dev/node/install.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:python install" -- must_run "scripts/dev/python/install.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:vscode install" -- must_run "scripts/dev/editors/install-vscode.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:vscode extensions" -- must_run "scripts/dev/editors/install-extensions.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:nvidia toolkit" -- must_run "scripts/dev/docker/nvidia-toolkit.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "dev:github web login" -- must_run "scripts/dev/github-web-login.sh"

  log "[dev] done"
}
