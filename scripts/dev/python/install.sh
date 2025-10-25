#!/usr/bin/env bash
# Python toolchain install for Ubuntu 24.04
# - Installs python3, python3-venv, python3-pip
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

# 공용 유틸 재사용
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

ensure_root_or_reexec_with_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    require_cmd sudo
    log "[python] root 권한이 필요합니다. sudo 인증을 진행합니다."
    sudo -v || err "sudo 인증 실패"
    exec sudo --preserve-env=LEGION_SETUP_ROOT,DEBIAN_FRONTEND,NEEDRESTART_MODE \
      -E bash "$0" "$@"
  fi
}

main() {
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404
  require_cmd apt-get

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  log "[python] apt-get update"
  apt-get update -y

  log "[python] python3/python3-venv/python3-pip 설치"
  apt-get install -y --no-install-recommends python3 python3-venv python3-pip

  log "[python] Python: $(python3 --version)"
  log "[python] Pip: $(python3 -m pip --version)"
  log "[python] 설치 완료"
}

main "$@"
