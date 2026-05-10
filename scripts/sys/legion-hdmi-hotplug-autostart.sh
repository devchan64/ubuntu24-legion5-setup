#!/usr/bin/env bash
# file: scripts/sys/legion-hdmi-hotplug-autostart.sh
# Domain: 로그인 후 HDMI 자동 재감지를 위해 사용자 자동실행 등록
# Contract: root 실행 + --user <desktopUser> 필수
set -Eeuo pipefail
set -o errtrace

legion_hdmi_hotplug_autostart_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "legion-hdmi-hotplug-autostart must run as root"
  fi

  local desk_user=""
  local rate="60"
  local internal_mode="2560x1600"
  local external_mode="3840x2160"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) desk_user="${2:-}"; shift 2 ;;
      --rate) rate="${2:-}"; shift 2 ;;
      --internal-mode) internal_mode="${2:-}"; shift 2 ;;
      --external-mode) external_mode="${2:-}"; shift 2 ;;
      *) err "unknown arg: $1" ;;
    esac
  done

  [[ -n "${desk_user}" ]] || err "--user <desktopUser> required"
  [[ "${rate}" =~ ^[0-9]+([.][0-9]+)?$ ]] || err "invalid --rate: ${rate}"
  [[ "${internal_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --internal-mode: ${internal_mode}"
  [[ "${external_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --external-mode: ${external_mode}"
  id -u "${desk_user}" >/dev/null 2>&1 || err "user not found: ${desk_user}"
  must_cmd_or_throw install

  local user_home=""
  user_home="$(getent passwd "${desk_user}" | cut -d: -f6 || true)"
  [[ -n "${user_home}" ]] || err "home directory not found: ${desk_user}"

  local bin_dir="${user_home}/.local/bin"
  local autostart_dir="${user_home}/.config/autostart"
  local hook_script="${bin_dir}/monitor-hotplug-apply.sh"
  local desktop_file="${autostart_dir}/monitor-hotplug-apply.desktop"

  install -d -m 0755 -o "${desk_user}" -g "${desk_user}" "${bin_dir}" "${autostart_dir}"

  cat > "${hook_script}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

# 로그인 직후 X 세션 안정화 대기
sleep 3

xq="$(xrandr --query)"
internal="$(echo "${xq}" | awk '/ connected/ {print $1}' | grep -E '^(eDP|LVDS)' | head -n1 || true)"
[[ -n "${internal}" ]] || exit 0

external="$(echo "${xq}" | awk '/ connected/ {print $1}' | grep -E '^(HDMI|DP|DisplayPort)' | head -n1 || true)"
if [[ -z "${external}" ]]; then
  exit 0
fi

# 외부 모니터가 이미 감지된 경우 레이아웃 + 외부를 기본(primary)으로 재적용
xrandr --output "\${internal}" --mode "${internal_mode}" --output "\${external}" --mode "${external_mode}" --right-of "\${internal}" --rate "${rate}" --primary
EOF
  chown "${desk_user}:${desk_user}" "${hook_script}"
  chmod 0755 "${hook_script}"

  cat > "${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Name=Monitor Hotplug Apply
Exec=${hook_script}
X-GNOME-Autostart-enabled=true
NoDisplay=false
Terminal=false
EOF
  chown "${desk_user}:${desk_user}" "${desktop_file}"
  chmod 0644 "${desktop_file}"

  log "[hdmi] 로그인 자동 재감지 등록 완료: user=${desk_user}"
}

legion_hdmi_hotplug_autostart_main "$@"
