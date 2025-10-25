#!/usr/bin/env bash
# Ubuntu 24.04(noble) 공통 부트스트랩 (비대화형, 폴백 없음)
set -Eeuo pipefail

_ts() { date +'%F %T'; }
log()  { printf "[%s] %s\n" "$(_ts)" "$*"; }
err()  { printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || err "root 권한이 필요합니다. sudo로 실행하세요."; }
require_ubuntu_2404() {
  [[ -r /etc/os-release ]] || err "/etc/os-release 없음"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || err "Ubuntu 환경이 아닙니다 (ID=${ID:-unknown})"
  [[ "${VERSION_CODENAME:-}" == "noble" ]] || err "Ubuntu 24.04(noble) 필요 (codename=${VERSION_CODENAME:-unknown})"
  [[ "${VERSION_ID:-}" == 24.04* ]] || err "Ubuntu 24.04.x 필요 (VERSION_ID=${VERSION_ID:-unknown})"
}

main() {
  require_root
  require_ubuntu_2404
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

  log "APT 인덱스 업데이트"
  apt-get update -y || err "apt-get update 실패"

  log "공통 패키지 설치 (멱등)"
  apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip jq gnupg software-properties-common \
    build-essential xclip || err "공통 패키지 설치 실패"

  log "universe 리포지토리 활성화"
  add-apt-repository -y universe || true

  log "bootstrap 완료"
}

main "$@"
