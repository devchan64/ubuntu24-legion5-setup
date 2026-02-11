#!/usr/bin/env bash
# file: scripts/sys/legion-hdmi-layout.sh
# Domain: Xorg 세션에서만 xrandr 레이아웃 적용
# Contract: root 실행 + --user <desktopUser> 필수
# Fail-Fast: 내부/외부 디스플레이를 못 찾으면 즉시 err
set -Eeuo pipefail
set -o errtrace

legion_hdmi_layout_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"
  # shellcheck disable=SC1090
  source "${root_dir}/scripts/sys/_desktop-session-env.sh"

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "legion-hdmi-layout must run as root"
  fi

  local desk_user=""
  local layout=""
  local rate=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)   desk_user="${2:-}"; shift 2 ;;
      --layout) layout="${2:-}"; shift 2 ;;
      --rate)   rate="${2:-}"; shift 2 ;;
      *)        err "unknown arg: $1" ;;
    esac
  done

  [[ -n "${desk_user}" ]] || err "--user <desktopUser> required"
  [[ -n "${layout}" ]] || err "--layout <left|right|above|below|mirror> required"
  [[ -n "${rate}" ]] || err "--rate <hz> required"
  [[ "${rate}" =~ ^[0-9]+([.][0-9]+)?$ ]] || err "invalid --rate: ${rate}"

  id -u "${desk_user}" >/dev/null 2>&1 || err "user not found: ${desk_user}"
  must_cmd_or_throw xrandr
  must_cmd_or_throw sudo

  eval "$(_desktop_session_env_exports_or_throw "${desk_user}")"

  local -a user_env=(
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
    "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS}"
    "DISPLAY=${DISPLAY}"
    "XAUTHORITY=${XAUTHORITY}"
    "XDG_SESSION_TYPE=${XDG_SESSION_TYPE}"
  )

  local xq=""
  xq="$(sudo -u "${desk_user}" env "${user_env[@]}" xrandr --query)"

  local internal=""
  internal="$(echo "${xq}" | awk '/ connected/ {print $1}' | grep -E '^(eDP|LVDS)' | head -n 1 || true)"
  [[ -n "${internal}" ]] || err "internal display not found (eDP/LVDS). xrandr connected outputs:\n${xq}"

  local external=""
  external="$(echo "${xq}" | awk '/ connected/ {print $1}' | grep -E '^(HDMI|DP|DisplayPort)' | head -n 1 || true)"
  [[ -n "${external}" ]] || err "external display not found (HDMI/DP). xrandr connected outputs:\n${xq}"

  log "[hdmi] internal=${internal} external=${external} layout=${layout} rate=${rate}"

  case "${layout}" in
    right)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" --auto --output "${external}" --auto --right-of "${internal}" --rate "${rate}" ;;
    left)   sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" --auto --output "${external}" --auto --left-of "${internal}" --rate "${rate}" ;;
    above)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" --auto --output "${external}" --auto --above "${internal}" --rate "${rate}" ;;
    below)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" --auto --output "${external}" --auto --below "${internal}" --rate "${rate}" ;;
    mirror) sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" --auto --output "${external}" --auto --same-as "${internal}" --rate "${rate}" ;;
    *) err "invalid --layout: ${layout}" ;;
  esac

  log "[hdmi] layout applied"
}

legion_hdmi_layout_main "$@"
