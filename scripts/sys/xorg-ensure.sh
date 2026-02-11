#!/usr/bin/env bash
# file: scripts/sys/xorg-ensure.sh
# GNOME on Xorg 보장 스크립트 (비대화형)
# - GDM: Wayland 비활성, 기본 세션 gnome-xorg.desktop (멱등)
# - 기본 동작: x11 세션이 없어도 설정만 적용하고 종료(재부팅은 사용자가 나중에 수행)
# - 옵션:
#     --user <name>   : 세션 점검 대상 사용자(기본: SUDO_USER 또는 USER)
#     --reboot-now    : 설정 적용 직후 즉시 재부팅
#     --strict        : x11 세션이 없으면 실패로 종료
# 정책: 폴백 없음, 실패 즉시 종료
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  ensure_root_or_reexec_with_sudo_or_throw "$@"
  require_ubuntu_2404

  must_cmd_or_throw loginctl
  must_cmd_or_throw sed
  must_cmd_or_throw grep
  must_cmd_or_throw cp
  must_cmd_or_throw systemctl

  local target_user=""
  local reboot_now=0
  local strict_mode=0

  # -------------------------------
  # Args (contract at entry)
  # -------------------------------
  while (( $# )); do
    case "$1" in
      --user)
        shift || true
        target_user="${1:-}"
        [[ -n "${target_user}" ]] || err "--user value required"
        ;;
      --reboot-now)
        reboot_now=1
        ;;
      --strict)
        strict_mode=1
        ;;
      *)
        err "unknown option: $1"
        ;;
    esac
    shift || true
  done

  if [[ -z "${target_user}" ]]; then
    target_user="${SUDO_USER:-${USER}}"
  fi

  id -u "${target_user}" >/dev/null 2>&1 || err "user not found: ${target_user}"

  log "[xorg] ensure gdm config"
  ensure_gdm_xorg_or_throw

  log "[xorg] check active x11 session (best-effort unless --strict)"
  assert_or_note_session_or_throw "${target_user}" "${strict_mode}"

  if [[ "${reboot_now}" -eq 1 ]]; then
    warn "[xorg] reboot now requested (--reboot-now)"
    systemctl reboot
    exit 0
  fi

  log "[xorg] done (reboot required to take effect)"
  warn "[xorg] reboot, then select 'GNOME on Xorg' at the login screen"
}

# ─────────────────────────────────────────────────────────────
# Top: Business
# SideEffect: modifies /etc/gdm3/custom.conf (+ .bak one-time)
# ─────────────────────────────────────────────────────────────
ensure_gdm_xorg_or_throw() {
  [[ -x /usr/sbin/gdm3 ]] || err "gdm3 not installed"
  local cfg="/etc/gdm3/custom.conf"
  [[ -f "${cfg}" ]] || err "missing: ${cfg}"

  if [[ ! -f "${cfg}.bak" ]]; then
    cp -a "${cfg}" "${cfg}.bak"
  fi

  # WaylandEnable=false
  if grep -Eq '^\s*#?\s*WaylandEnable\s*=' "${cfg}"; then
    sed -i 's/^\s*#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "${cfg}"
  else
    printf '\nWaylandEnable=false\n' >> "${cfg}"
  fi

  # DefaultSession=gnome-xorg.desktop
  if grep -Eq '^\s*#?\s*DefaultSession\s*=' "${cfg}"; then
    sed -i 's/^\s*#\?\s*DefaultSession\s*=.*/DefaultSession=gnome-xorg.desktop/' "${cfg}"
  else
    printf 'DefaultSession=gnome-xorg.desktop\n' >> "${cfg}"
  fi
}

pick_active_local_x11_session_id_for_user_or_empty() {
  local user="${1:?user required}"
  local sid="" type="" state="" remote=""

  while read -r sid _ uid name; do
    [[ "${name:-}" == "${user}" ]] || continue

    type="$(loginctl show-session "${sid}" -p Type --value 2>/dev/null || true)"
    state="$(loginctl show-session "${sid}" -p State --value 2>/dev/null || true)"
    remote="$(loginctl show-session "${sid}" -p Remote --value 2>/dev/null || true)"

    if [[ "${type}" == "x11" && "${state}" == "active" && "${remote}" != "yes" ]]; then
      echo "${sid}"
      return 0
    fi
  done < <(loginctl list-sessions --no-legend 2>/dev/null || true)

  echo ""
  return 0
}

assert_or_note_session_or_throw() {
  local user="${1:?user required}"
  local strict_mode="${2:?strict_mode required}"

  local sid=""
  sid="$(pick_active_local_x11_session_id_for_user_or_empty "${user}")"

  if [[ -n "${sid}" ]]; then
    log "[xorg] active x11 session: user=${user} session=${sid}"
    return 0
  fi

  if [[ "${strict_mode}" -eq 1 ]]; then
    err "no active local x11 session found (login with 'GNOME on Xorg' then rerun, or drop --strict)"
  fi

  warn "[xorg] no active x11 session; applied config only. reboot and login with 'GNOME on Xorg'."
}

main "$@"

# [ReleaseNote] breaking: ensure_root/must_cmd_or_throw SSOT and args validated at entry
