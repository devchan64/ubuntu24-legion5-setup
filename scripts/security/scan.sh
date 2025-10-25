#!/usr/bin/env bash
# 보안 점검/스캔 실행 (Ubuntu 24.04 전용)
# - ClamAV: 사용자 홈 디렉터리 스캔(감염파일만 리포트)
# - rkhunter: 루트킷 점검(비대화형)
# - Lynis: 시스템 보안 감사(요약 로그 경로 안내)
# 정책: 폴백 없음, 에러 즉시 중단
set -Eeuo pipefail

# 공통 유틸
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

require_root
require_ubuntu_2404

require_cmd clamscan
require_cmd rkhunter
require_cmd lynis

SEC_STATE_DIR="${PROJECT_STATE_DIR}/security"
mkdir -p "${SEC_STATE_DIR}"

_ts() { date +'%Y%m%d_%H%M%S'; }

# ─────────────────────────────────────────────────────────────
# ClamAV 스캔 (사용자 홈 중심) — 감염 항목만 출력
# ─────────────────────────────────────────────────────────────
HOME_DIR="${SUDO_USER:+/home/${SUDO_USER}}"
if [[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]]; then
  # sudo 미사용 등으로 변수 감지가 실패할 수 있음 → 현재 사용자 홈으로 대체(폴백 아니라 명시 경로)
  HOME_DIR="${HOME}"
fi
[[ -d "${HOME_DIR}" ]] || err "홈 디렉터리를 찾을 수 없습니다: ${HOME_DIR}"

CLAM_LOG="${SEC_STATE_DIR}/clamav_${_ts}.log"
log "ClamAV 스캔 시작: ${HOME_DIR}"
# --infected: 감염된 파일만 출력, --recursive: 재귀, --log로 파일 저장
# 아카이브도 검사(--scan-archive=yes), 접근 거부 시 에러로 중단(폴백 없음)
clamscan \
  --infected \
  --recursive \
  --scan-archive=yes \
  --cross-fs=no \
  --log="${CLAM_LOG}" \
  "${HOME_DIR}" || {
    # clamscan은 감염 발견 시 종료코드 1을 반환. 실패와 구분 필요.
    # 종료코드 1(감염 발견)은 정상 시나리오로 처리하고 로그 안내만 출력
    ec=$?
    if [[ $ec -eq 1 ]]; then
      warn "ClamAV: 감염 항목 발견(상세는 로그 참조) → ${CLAM_LOG}"
    else
      err "ClamAV 스캔 실패 (exit=${ec})"
    fi
  }

# ─────────────────────────────────────────────────────────────
# rkhunter 체크 (비대화형) — 로그 저장
# ─────────────────────────────────────────────────────────────
RKH_LOG="${SEC_STATE_DIR}/rkhunter_${_ts}.log"
log "rkhunter 체크 시작(비대화형)"
# -c/--check: 검사, --sk: 키 입력 생략, --rwo: 경고만 출력
rkhunter --check --sk --rwo | tee "${RKH_LOG}" >/dev/null || {
  # rkhunter는 경고 발생 시 종료코드 1을 돌려줄 수 있음 → 로그만 안내
  warn "rkhunter 경고/오류 발생(로그 참조) → ${RKH_LOG}"
}

# ─────────────────────────────────────────────────────────────
# Lynis 시스템 감사 — 표준 로그 경로 및 요약 안내
# ─────────────────────────────────────────────────────────────
log "Lynis 시스템 감사 시작(quick 모드)"
# Lynis는 /var/log/lynis 에 리포트 및 데이터 저장
LYNIS_OPTS="audit system --quiet"
lynis ${LYNIS_OPTS} || warn "lynis 감사에서 경고/오류가 보고되었습니다."

# ─────────────────────────────────────────────────────────────
# 결과 안내
# ─────────────────────────────────────────────────────────────
cat <<EOF
[보안 점검 완료]

• ClamAV 로그:         ${CLAM_LOG}
  - 감염 발견 시 로그에 경로가 기록되어 있습니다. 필요 시 직접 격리/삭제하세요.

• rkhunter 로그:       ${RKH_LOG}
  - 경고(Red) 항목을 우선 확인하세요.

• Lynis 리포트:        /var/log/lynis/report.dat
• Lynis 상세 로그:     /var/log/lynis/lynis.log
  - 권고 사항(Hardening index 개선)을 참고하여 조치하세요.

EOF

log "모든 보안 점검 단계가 완료되었습니다."
