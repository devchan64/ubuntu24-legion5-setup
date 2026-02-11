#!/usr/bin/env bash
# file: scripts/dev/editors/install-vscode.sh
# Visual Studio Code install via Microsoft repository (Ubuntu 24.04)
# Policy: no fallbacks, exit on error
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  ensure_root_or_reexec_with_sudo_or_throw "$@"

  require_ubuntu_2404
  must_cmd_or_throw apt-get
  must_cmd_or_throw gpg
  must_cmd_or_throw wget

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  log "[vscode] install prerequisites"
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates wget gpg

  # Contract: VS Code repo/keyring은 단일 SSOT로 관리한다.
  # SideEffect: /etc/apt/sources.list.d, /etc/apt/keyrings 변경 가능
  log "[vscode] enforce repo/keyring singleton"
  apt_fix_vscode_repo_singleton

  log "[vscode] install package: code"
  apt-get update -y
  apt-get install -y --no-install-recommends code

  must_cmd_or_throw code
  log "[vscode] installed: $(code --version | head -n1)"
  log "[vscode] done"
}

main "$@"
