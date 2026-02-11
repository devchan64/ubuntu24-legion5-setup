#!/usr/bin/env bash
# file: scripts/sys/bootstrap.sh
# Ubuntu 24.04(noble) 공통 부트스트랩 (비대화형, 폴백 없음)
#
# /** Domain: Contract: Fail-Fast: SideEffect: */
# - Domain: sys 도메인 공통 전제(apt 가능, 기본 패키지, universe enable)를 만족시키는 부트스트랩 단계
# - Contract: Ubuntu 24.04(noble)만 지원, root 필요(불가 시 sudo 재실행), bash + strict mode
# - Fail-Fast: 전제조건/명령 실패 시 즉시 err(throw)
# - SideEffect: apt index 갱신, 패키지 설치, apt repo(universe) 활성화
set -Eeuo pipefail
set -o errtrace

bootstrap_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  # -------------------------------
  # Contract: root + OS + required commands
  # -------------------------------
  ensure_root_or_reexec_with_sudo_or_throw "$@"
  require_ubuntu_2404
  must_cmd_or_throw apt-get
  must_cmd_or_throw add-apt-repository

  # -------------------------------
  # Contract: non-interactive (SSOT)
  # -------------------------------
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # -------------------------------
  # SideEffect: enable universe (idempotent)
  # -------------------------------
  log "[bootstrap] enable universe"
  add-apt-repository -y universe

  # -------------------------------
  # SideEffect: apt index update
  # -------------------------------
  log "[bootstrap] apt-get update"
  apt-get update -y

  # -------------------------------
  # SideEffect: install common packages (idempotent)
  # -------------------------------
  log "[bootstrap] install common packages"
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    jq \
    gnupg \
    software-properties-common \
    build-essential \
    xclip \
    fonts-firacode \
    fonts-jetbrains-mono \
    gnome-themes-extra

  log "[bootstrap] done"
}

bootstrap_main "$@"
