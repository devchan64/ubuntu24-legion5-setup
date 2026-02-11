#!/usr/bin/env bash
# file: lib/desktop-session-env.sh
# Desktop(Xorg) 세션 컨텍스트에서만 안전한 작업(gsettings/xrandr 등)을 수행하기 위한 ENV 추출 유틸
# 정책:
#   - Fail-Fast: 조건 불충족 시 즉시 err
#   - SSOT: 세션/ENV 해석 로직은 여기 한 곳에만 둔다.
# 사용:
#   eval "$(_desktop_session_env_exports_or_throw <desktopUser>)"
#
# /** Domain: Contract: Fail-Fast: SideEffect: */
set -Eeuo pipefail
set -o errtrace

_desktop_session_env_exports_or_throw() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  # -------------------------------
  # Contract: root only
  # -------------------------------
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "_desktop_session_env_exports_or_throw must run as root"
  fi

  local desk_user="${1:-}"
  [[ -n "${desk_user}" ]] || err "desktop user required: _desktop_session_env_exports_or_throw <user>"
  id -u "${desk_user}" >/dev/null 2>&1 || err "user not found: ${desk_user}"

  must_cmd_or_throw loginctl
  must_cmd_or_throw pgrep
  must_cmd_or_throw awk
  must_cmd_or_throw tr

  local desk_uid=""
  desk_uid="$(id -u "${desk_user}")" || err "failed to resolve uid: ${desk_user}"

  # -------------------------------
  # Contract: active Xorg session
  # -------------------------------
  local session_id=""
  local session_type=""
  local session_state=""

  while read -r sid uid user _; do
    [[ "${uid:-}" == "${desk_uid}" ]] || continue
    [[ "${user:-}" == "${desk_user}" ]] || continue

    session_type="$(loginctl show-session "${sid}" -p Type --value 2>/dev/null || true)"
    session_state="$(loginctl show-session "${sid}" -p State --value 2>/dev/null || true)"

    if [[ "${session_type}" == "x11" && "${session_state}" == "active" ]]; then
      session_id="${sid}"
      break
    fi
  done < <(loginctl list-sessions --no-legend 2>/dev/null || true)

  [[ -n "${session_id}" ]] || err "active Xorg(x11) session not found (login with GNOME on Xorg)"

  # -------------------------------
  # DISPLAY/XAUTHORITY: extract from real GUI process environ (no normalization except SSOT fallback)
  # -------------------------------
  local pid=""
  pid="$(pgrep -u "${desk_user}" -n gnome-shell 2>/dev/null || true)"
  if [[ -z "${pid}" ]]; then
    pid="$(pgrep -u "${desk_user}" -n Xorg 2>/dev/null || true)"
  fi
  [[ -n "${pid}" ]] || err "GUI process not found: user=${desk_user} (gnome-shell/Xorg)"

  local env_file="/proc/${pid}/environ"
  [[ -r "${env_file}" ]] || err "cannot read environ: ${env_file} (pid=${pid})"

  local session_display=""
  session_display="$(tr '\0' '\n' < "${env_file}" | awk -F= '$1=="DISPLAY"{print $2; exit}' || true)"
  [[ -n "${session_display}" ]] || err "DISPLAY not found in environ: user=${desk_user} pid=${pid}"

  local xauth_file=""
  xauth_file="$(tr '\0' '\n' < "${env_file}" | awk -F= '$1=="XAUTHORITY"{print $2; exit}' || true)"
  if [[ -n "${xauth_file}" && -e "${xauth_file}" ]]; then
    : # ok
  else
    # Contract: we do NOT attempt multiple fallbacks; single SSOT fallback only
    local cand="/run/user/${desk_uid}/gdm/Xauthority"
    [[ -e "${cand}" ]] || err "XAUTHORITY not found (hint: ${cand}) user=${desk_user} pid=${pid}"
    xauth_file="${cand}"
  fi

  # -------------------------------
  # DBus / runtime
  # -------------------------------
  local runtime_dir="/run/user/${desk_uid}"
  [[ -d "${runtime_dir}" ]] || err "XDG_RUNTIME_DIR not found: ${runtime_dir}"

  local bus_path="${runtime_dir}/bus"
  [[ -S "${bus_path}" || -e "${bus_path}" ]] || err "DBus session bus not found: ${bus_path}"

  # -------------------------------
  # Output: eval-able exports (explicit SideEffect in caller)
  # -------------------------------
  printf 'export %s=%q\n' "XDG_RUNTIME_DIR" "${runtime_dir}"
  printf 'export %s=%q\n' "DBUS_SESSION_BUS_ADDRESS" "unix:path=${bus_path}"
  printf 'export %s=%q\n' "DISPLAY" "${session_display}"
  printf 'export %s=%q\n' "XAUTHORITY" "${xauth_file}"
  printf 'export %s=%q\n' "XDG_SESSION_TYPE" "x11"
}
