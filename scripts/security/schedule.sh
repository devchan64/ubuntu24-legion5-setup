#!/usr/bin/env bash
# 보안 스캔(systemd timer) 스케줄러 (Ubuntu 24.04 전용)
# 정책: 폴백 없음, 에러 즉시 종료
# 사용:
#   sudo bash scripts/security/schedule.sh --enable-weekly
#   sudo bash scripts/security/schedule.sh --disable
#   sudo bash scripts/security/schedule.sh --status
#   sudo bash scripts/security/schedule.sh --run-now
set -Eeuo pipefail

# 공통 유틸 로드 (ts/log/err, ensure_root_or_reexec_with_sudo, require_ubuntu_2404)
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

require_cmd systemctl
require_cmd cat
require_cmd tee

UNIT_NAME="ubuntu24-legion5-security-scan"
SERVICE_FILE="/etc/systemd/system/${UNIT_NAME}.service"
TIMER_FILE="/etc/systemd/system/${UNIT_NAME}.timer"
WRAPPER="/usr/local/sbin/${UNIT_NAME}"

SCAN_SH="${ROOT_DIR}/scripts/security/scan.sh"
[[ -x "${SCAN_SH}" ]] || err "scan 스크립트를 찾지 못했거나 실행 권한이 없습니다: ${SCAN_SH}"

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/security/schedule.sh --enable-weekly
  sudo bash scripts/security/schedule.sh --disable
  sudo bash scripts/security/schedule.sh --status
  sudo bash scripts/security/schedule.sh --run-now

옵션:
  --enable-weekly  매주 일요일 03:15에 보안 스캔 실행(systemd timer)
  --disable        타이머/서비스 비활성화
  --status         타이머/서비스 상태 확인
  --run-now        지금 즉시 1회 스캔 실행(타이머 유지)
EOF
}

make_wrapper() {
  log "[sec/schedule] wrapper 생성: ${WRAPPER}"
  cat >"${WRAPPER}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
export LEGION_SETUP_ROOT="${ROOT_DIR}"
exec bash "${SCAN_SH}" --yes
EOF
  chmod 0755 "${WRAPPER}"
}

make_units() {
  log "[sec/schedule] systemd unit 생성: ${SERVICE_FILE}, ${TIMER_FILE}"

  # 서비스 유닛 (비대화형 실행, 자원 보호)
  cat >"${SERVICE_FILE}" <<EOF
[Unit]
Description=Weekly security scan (clamav / rkhunter / lynis)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=${WRAPPER}
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=6
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
CapabilityBoundingSet=
LockPersonality=yes

[Install]
WantedBy=multi-user.target
EOF

  # 타이머 유닛 (매주 일요일 03:15, 로컬타임)
  cat >"${TIMER_FILE}" <<EOF
[Unit]
Description=Weekly timer for ${UNIT_NAME}

[Timer]
OnCalendar=Sun *-*-* 03:15:00
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF
}

enable_weekly() {
  make_wrapper
  make_units
  systemctl daemon-reload
  systemctl enable --now "${UNIT_NAME}.timer"
  systemctl is-enabled "${UNIT_NAME}.timer" >/dev/null || err "타이머 enable 실패"
  log "[sec/schedule] 주간 스케줄 활성화 완료: ${UNIT_NAME}.timer (매주 일 03:15)"
}

disable_all() {
  systemctl disable --now "${UNIT_NAME}.timer" || true
  systemctl disable --now "${UNIT_NAME}.service" || true
  log "[sec/schedule] 비활성화 완료: ${UNIT_NAME}.timer / ${UNIT_NAME}.service"
}

status_all() {
  systemctl status "${UNIT_NAME}.timer" || true
  echo "------------------------------------------------------------"
  systemctl status "${UNIT_NAME}.service" || true
  echo "------------------------------------------------------------"
  systemctl list-timers --all | grep -E "${UNIT_NAME}\.timer" || true
}

run_now() {
  [[ -x "${WRAPPER}" ]] || make_wrapper
  [[ -f "${SERVICE_FILE}" && -f "${TIMER_FILE}" ]] || make_units
  systemctl daemon-reload
  log "[sec/schedule] 지금 즉시 1회 실행: ${UNIT_NAME}.service"
  systemctl start "${UNIT_NAME}.service"
  systemctl is-active --quiet "${UNIT_NAME}.service" || err "서비스 실행 실패(로그 확인 필요)"
}

main() {
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404

  [[ $# -gt 0 ]] || { usage; exit 1; }
  case "$1" in
    --enable-weekly) enable_weekly ;;
    --disable)       disable_all ;;
    --status)        status_all ;;
    --run-now)       run_now ;;
    -h|--help)       usage ;;
    *) err "unknown option: $1" ;;
  esac
}

main "$@"
