#!/usr/bin/env bash
# 보안 도구 설치 (Ubuntu 24.04 전용)
# - clamav / clamav-freshclam
# - rkhunter
# - lynis
# 정책: 폴백 없음, 에러 즉시 중단
set -Eeuo pipefail

# 공통 유틸
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

require_root
require_ubuntu_2404
require_cmd apt-get
require_cmd systemctl

SEC_STATE_DIR="${PROJECT_STATE_DIR}/security"
mkdir -p "${SEC_STATE_DIR}"

log "보안 패키지 설치 시작"
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  clamav clamav-freshclam rkhunter lynis

# clamav 정의 업데이트 데몬 활성화
log "freshclam 서비스 활성화 및 재시작"
systemctl enable clamav-freshclam.service
systemctl restart clamav-freshclam.service
systemctl is-active --quiet clamav-freshclam.service || err "clamav-freshclam.service 활성화 실패"

# 즉시 한 번 시그니처 동기화(서비스가 이미 수행했더라도 재시도)
if command -v freshclam >/dev/null 2>&1; then
  log "freshclam 수동 실행(최신화 보장)"
  freshclam || err "freshclam 실패"
fi

# rkhunter 초기 데이터베이스 생성(필수)
log "rkhunter 초기 속성 데이터베이스 생성"
rkhunter --propupd -q || err "rkhunter --propupd 실패"

# lynis는 추가 설정 필요 없음(점검 시에 실행)
log "설치 완료: clamav / rkhunter / lynis"
