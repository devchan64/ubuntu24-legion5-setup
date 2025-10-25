#!/usr/bin/env bash
# 보안 도구 설치 (Ubuntu 24.04 전용)
# - clamav / clamav-freshclam : 서비스 방식 업데이트(수동 freshclam 금지)
# - rkhunter, lynis
# 정책: 폴백 없음, 에러 즉시 중단
set -Eeuo pipefail

# 공통 유틸
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404
  require_cmd apt-get
  require_cmd systemctl

  local SEC_STATE_DIR="${PROJECT_STATE_DIR}/security"
  mkdir -p "${SEC_STATE_DIR}"

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # APT VSCode repo 충돌 가능성 사전 제거(키링/형식 단일화)
  apt_fix_vscode_repo_singleton

  log "[sec] 보안 패키지 설치 시작"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    clamav clamav-freshclam rkhunter lynis

  # ClamAV 로그/DB 디렉터리 보장(멱등)
  install -d -o clamav -g clamav -m 0755 /var/log/clamav
  install -d -o clamav -g clamav -m 0755 /var/lib/clamav

  # freshclam 데몬 활성화 (수동 freshclam 호출 금지: 로그/락 충돌 방지)
  log "[sec] freshclam 서비스 활성화 및 재시작"
  systemctl enable clamav-freshclam.service
  systemctl restart clamav-freshclam.service
  systemctl is-active --quiet clamav-freshclam.service \
    || err "clamav-freshclam.service 활성화 실패"

  # 첫 업데이트 진행 상황 출력(참고용, 실패해도 진행)
  journalctl -u clamav-freshclam -n 50 --no-pager || true

  # rkhunter 초기 데이터베이스 생성(필수)
  require_cmd rkhunter
  log "[sec] rkhunter 초기 속성 데이터베이스 생성"
  rkhunter --propupd -q || err "rkhunter --propupd 실패"

  # lynis는 추가 설정 없음(점검 시 수동 실행)
  require_cmd lynis
  log "[sec] 설치 완료: clamav(freshclam 데몬), rkhunter, lynis"
}

main "$@"
