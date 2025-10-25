#!/usr/bin/env bash
# 보안 스캔 주간 스케줄(systemd --user timer)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# 공통 유틸 로드
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd -P)/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: bash scripts/security/av/schedule.sh [--enable-weekly] [--disable]

--enable-weekly : 매주 일요일 02:30에 scan.sh 실행
--disable       : 타이머 비활성화
EOF
}

TIMER_NAME="ubuntu24-legion5-security-scan"
UNIT_DIR="${XDG_CONFIG_HOME}/systemd/user"
mkdir -p "$UNIT_DIR"

write_units() {
  local service="${UNIT_DIR}/${TIMER_NAME}.service"
  local timer="${UNIT_DIR}/${TIMER_NAME}.timer"

  cat >"$service" <<SERVICE
[Unit]
Description=Weekly security scan (clamav/rkhunter/chkrootkit)

[Service]
Type=oneshot
ExecStart=${REPO_ROOT}/scripts/security/av/scan.sh
WorkingDirectory=${REPO_ROOT}
Environment=XDG_STATE_HOME=${XDG_STATE_HOME}
SERVICE

  cat >"$timer" <<TIMER
[Unit]
Description=Run weekly security scan at 02:30 on Sundays

[Timer]
OnCalendar=Sun *-*-* 02:30:00
Persistent=true
Unit=${TIMER_NAME}.service

[Install]
WantedBy=default.target
TIMER
}

enable_weekly() {
  ensure_user_systemd_ready
  write_units
  systemctl --user daemon-reload
  systemctl --user enable  "${TIMER_NAME}.timer"
  systemctl --user restart "${TIMER_NAME}.timer"
  systemctl --user is-active --quiet "${TIMER_NAME}.timer" \
    || err "failed to activate ${TIMER_NAME}.timer"
  log "Enabled: ${TIMER_NAME}.timer (Sun 02:30 weekly)"
}

disable_timer() {
  systemctl --user disable "${TIMER_NAME}.timer" || true
  systemctl --user stop    "${TIMER_NAME}.timer" || true
  log "Disabled: ${TIMER_NAME}.timer"
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 0; }
  case "${1:-}" in
    --enable-weekly) enable_weekly ;;
    --disable)       disable_timer ;;
    -h|--help)       usage ;;
    *) err "unknown option: $1" ;;
  esac
}
main "$@"
