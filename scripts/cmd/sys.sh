#!/usr/bin/env bash
# file: scripts/cmd/sys.sh
# System bootstrap for Ubuntu 24.04 (Xorg/GNOME tweaks)
# 정책:
#   - 동의는 저장하지 않음. 실행 시마다 "전체 동의" 1회만 질의
#   - --yes 이면 프롬프트 없이 진행
#   - 전제조건 불충족 시 즉시 실패(err), 폴백 없음
set -Eeuo pipefail
set -o errtrace

sys_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  # ─────────────────────────────────────────────────────────────
  # Root Contract (auto elevate)
  # ─────────────────────────────────────────────────────────────
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      local dispatcher="${root_dir}/scripts/install-all.sh"
      [[ -f "${dispatcher}" ]] || err "dispatcher not found: ${dispatcher}"
      log "[sys] root 권한 필요 → sudo 재실행"
      exec sudo -E bash "${dispatcher}" sys "$@"
    fi
    err "sys requires root. sudo not found."
  fi

  # ─────────────────────────────────────────────────────────────
  # IO: Desktop user resolve (SSOT)
  # ─────────────────────────────────────────────────────────────
  local desk_user="${SUDO_USER:-${USER}}"
  if [[ "${1:-}" == "--user" ]]; then
    desk_user="${2:?--user requires value}"
    shift 2
  fi

  confirm_or_throw "[sys] 이 단계는 시스템 설정을 변경합니다. 계속할까요?"

  # ─────────────────────────────────────────────────────────────
  # Business: Orchestration (resume scope: cmd:sys)
  # ─────────────────────────────────────────────────────────────
  local resume_scope="cmd:sys"
  if [[ -n "${RESUME_SCOPE_KEY:-}" ]]; then
    resume_scope="${RESUME_SCOPE_KEY}"
  fi

  # ① Xorg ensure
  resume_step "${resume_scope}" "sys:xorg:ensure" \
    must_run_or_throw "scripts/sys/xorg-ensure.sh"

  # ② GNOME basic
  resume_step "${resume_scope}" "sys:gnome:basic" \
    must_run_or_throw "scripts/sys/bootstrap.sh" --user "${desk_user}"

  # ③ GNOME Nord (run once or it will reapply theme every time)
  resume_step "${resume_scope}" "sys:gnome:nord" \
    must_run_or_throw "scripts/sys/gnome-nord.sh" --user "${desk_user}"

  # ④ Legion HDMI
  resume_step "${resume_scope}" "sys:legion:hdmi" \
    must_run_or_throw "scripts/sys/legion-hdmi.sh" --user "${desk_user}" --layout right --rate 165

  log "[sys] done"
}

# Contract: scripts/install-all.sh expects <domain>_main
sys_main "$@"
