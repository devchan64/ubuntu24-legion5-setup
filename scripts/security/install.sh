#!/usr/bin/env bash
# 보안 도구 설치 (Ubuntu 24.04 전용)
# - clamav / clamav-freshclam  : 서비스 방식으로만 업데이트 (수동 freshclam 호출 금지)
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

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

log "보안 패키지 설치 시작"
apt-get update -y
apt-get install -y --no-install-recommends \
  clamav clamav-freshclam rkhunter lynis

# ClamAV 로그/DB 디렉터리 보장(멱등)
install -d -o clamav -g clamav -m 0755 /var/log/clamav
install -d -o clamav -g clamav -m 0755 /var/lib/clamav

# freshclam 데몬 활성화 (수동 freshclam 호출 금지: 로그 락 충돌 방지)
log "freshclam 서비스 활성화 및 재시작"
systemctl enable clamav-freshclam.service
systemctl restart clamav-freshclam.service
systemctl is-active --quiet clamav-freshclam.service \
  || err "clamav-freshclam.service 활성화 실패"

# 첫 업데이트 진행 상황을 참고용으로 출력(실패해도 스크립트는 계속)
journalctl -u clamav-freshclam -n 50 --no-pager || true

# rkhunter 초기 데이터베이스 생성(필수)
log "rkhunter 초기 속성 데이터베이스 생성"
rkhunter --propupd -q || err "rkhunter --propupd 실패"

# lynis는 추가 설정 없음(점검 시 실행)
log "설치 완료: clamav(freshclam 데몬), rkhunter, lynis"
