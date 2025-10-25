#!/usr/bin/env bash
# Ubuntu 24.04(noble) 공통 부트스트랩 (비대화형, 폴백 없음)
set -Eeuo pipefail

# 공용 유틸 사용: ts, log, err, require_cmd, ensure_root_or_reexec_with_sudo, require_ubuntu_2404
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404
  require_cmd apt-get
  require_cmd add-apt-repository

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  log "[bootstrap] APT 인덱스 업데이트"
  apt-get update -y || err "apt-get update 실패"

  log "[bootstrap] 공통 패키지 설치 (멱등)"
  apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip jq gnupg software-properties-common \
    build-essential xclip || err "공통 패키지 설치 실패"

  log "[bootstrap] universe 리포지토리 활성화"
  add-apt-repository -y universe || err "universe 리포지토리 활성화 실패"

  log "[bootstrap] 완료"
}

main "$@"
