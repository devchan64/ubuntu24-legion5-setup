#!/usr/bin/env bash
# 보안 점검/스캔 실행 (Ubuntu 24.04 전용)
# - ClamAV: 지정 대상(기본은 sudo 사용자 홈) 스캔(감염파일만 리포트)
# - rkhunter: 루트킷 점검(비대화형)
# - Lynis: 시스템 보안 감사(요약 경로 안내)
# 정책: 폴백 없음, 에러 즉시 중단 / 실행 전 동의 필요
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

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# -------------------------------
# 동의 프롬프트 (동의 미저장, 매 실행 1회)
# -------------------------------
AUTO_YES=0
if [[ "${1:-}" == "--yes" ]]; then
  AUTO_YES=1
  shift || true
fi

if (( AUTO_YES != 1 )); then
  if [[ -t 0 || -r /dev/tty ]]; then
    log "[scan] 본 스캔은 시간이 다소 소요됩니다."
    printf "보안 스캔(ClamAV + rkhunter + Lynis)을 지금 실행할까요? [y/N] " > /dev/tty
    read -r __ans < /dev/tty || err "입력 실패"
    if [[ "$__ans" != "y" && "$__ans" != "Y" ]]; then
      warn "[scan] 사용자가 취소했습니다. 아무 작업도 수행하지 않습니다."
      exit 0
    fi
  else
    err "대화형 입력을 사용할 수 없습니다. --yes 로 동의를 명시하고 재실행하세요."
  fi
else
  log "[scan] --yes 지정됨. 프롬프트 없이 진행합니다."
fi

# -------------------------------
# 상태/로그 디렉터리
# -------------------------------
[[ -n "${PROJECT_STATE_DIR:-}" ]] || err "PROJECT_STATE_DIR 가 정의되지 않았습니다 (lib/common.sh 확인)."
SEC_STATE_DIR="${PROJECT_STATE_DIR}/security"
mkdir -p "${SEC_STATE_DIR}"

TS="$(date +'%Y%m%d_%H%M%S')"

# ─────────────────────────────────────────────────────────────
# 1) ClamAV 스캔 — 감염 항목만 출력
#    - 종료코드: 0=감염 없음, 1=감염 발견(정상 시나리오), >1=실패
# ─────────────────────────────────────────────────────────────
declare -a CLAM_TARGETS
if [[ -n "${SEC_CLAM_TARGETS:-}" ]]; then
  read -r -a CLAM_TARGETS <<< "${SEC_CLAM_TARGETS}"
else
  [[ -n "${SUDO_USER:-}" ]] || err "스캔 대상이 없습니다. SEC_CLAM_TARGETS를 지정하거나 sudo로 실행하세요."
  HOME_DIR="/home/${SUDO_USER}"
  [[ -d "${HOME_DIR}" ]] || err "홈 디렉터리를 찾을 수 없습니다: ${HOME_DIR}"
  CLAM_TARGETS=("${HOME_DIR}")
fi

CLAM_LOG="${SEC_STATE_DIR}/clamav_${TS}.log"
log "ClamAV 스캔 시작: ${CLAM_TARGETS[*]}"
clamscan \
  --infected \
  --recursive \
  --scan-archive=yes \
  --cross-fs=no \
  --log="${CLAM_LOG}" \
  "${CLAM_TARGETS[@]}" || {
    ec=$?
    if [[ $ec -eq 1 ]]; then
      warn "ClamAV: 감염 항목 발견(상세 로그: ${CLAM_LOG})"
    else
      err "ClamAV 스캔 실패 (exit=${ec})"
    fi
  }
log "ClamAV 스캔 완료(로그: ${CLAM_LOG})"

# ─────────────────────────────────────────────────────────────
# 2) rkhunter 점검 — 비대화형
#    - 종료코드: 0=문제 없음, 1=경고, >1=실패
# ─────────────────────────────────────────────────────────────
RKH_LOG="${SEC_STATE_DIR}/rkhunter_${TS}.log"
log "rkhunter 루트킷 점검 시작"
rkhunter --update || warn "rkhunter 업데이트 경고 발생(무시하고 계속 진행)"
set +o pipefail
rkhunter --check --sk --rwo --nocolors --quiet | tee "${RKH_LOG}" >/dev/null
rc_rkh=${PIPESTATUS[0]}
set -o pipefail
if [[ $rc_rkh -eq 0 ]]; then
  log "rkhunter 점검 완료: 이상 없음 (${RKH_LOG})"
elif [[ $rc_rkh -eq 1 ]]; then
  warn "rkhunter 점검 완료: 경고 존재(상세: ${RKH_LOG})"
else
  err "rkhunter 실행 실패(rc=${rc_rkh}) (로그: ${RKH_LOG})"
fi

# ─────────────────────────────────────────────────────────────
# 3) Lynis 시스템 감사 — quick
# ─────────────────────────────────────────────────────────────
log "Lynis 시스템 감사 시작(quick)"
if lynis audit system --quick --no-colors --quiet; then
  log "Lynis 감사 완료 (/var/log/lynis/report.dat, /var/log/lynis/lynis.log 참고)"
else
  warn "Lynis 감사에서 경고/오류가 보고되었습니다. (/var/log/lynis 확인)"
fi

# ─────────────────────────────────────────────────────────────
# 결과 안내
# ─────────────────────────────────────────────────────────────
cat <<EOF
[보안 점검 완료]

• ClamAV 로그:         ${CLAM_LOG}
  - 감염 발견 시 경로가 기록되어 있습니다. 필요 시 직접 격리/삭제하세요.

• rkhunter 로그:       ${RKH_LOG}
  - 경고(Red) 항목을 우선 확인하세요.

• Lynis 리포트:        /var/log/lynis/report.dat
• Lynis 상세 로그:     /var/log/lynis/lynis.log
  - 권고 사항(Hardening index 개선)을 참고하여 조치하세요.
EOF

log "모든 보안 점검 단계가 완료되었습니다."
