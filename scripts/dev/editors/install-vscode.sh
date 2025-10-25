#!/usr/bin/env bash
# Visual Studio Code install via Microsoft repository (Ubuntu 24.04)
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404
  require_cmd dpkg
  require_cmd wget
  require_cmd gpg
  require_cmd apt-get

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  log "[vscode] prerequisites 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates wget gpg

  log "[vscode] repo/keyring 정리 및 통일"
  apt_fix_vscode_repo_singleton

  log "[vscode] code 패키지 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends code

  require_cmd code
  log "[vscode] Installed VS Code: $(code --version | head -n1)"
  log "[vscode] 설치 완료"
}

main "$@"
