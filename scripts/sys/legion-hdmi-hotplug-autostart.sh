#!/usr/bin/env bash
# file: scripts/sys/legion-hdmi-hotplug-autostart.sh
# Domain: HDMI 복구 스크립트(수동 실행용) 배포
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
  local internal_pos="3840x0"
  local external_pos="0x0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) desk_user="${2:-}"; shift 2 ;;
      --rate) rate="${2:-}"; shift 2 ;;
      --internal-mode) internal_mode="${2:-}"; shift 2 ;;
      --external-mode) external_mode="${2:-}"; shift 2 ;;
      --internal-pos) internal_pos="${2:-}"; shift 2 ;;
      --external-pos) external_pos="${2:-}"; shift 2 ;;
      *) err "unknown arg: $1" ;;
    esac
  done

  [[ -n "${desk_user}" ]] || err "--user <desktopUser> required"
  [[ "${rate}" =~ ^[0-9]+([.][0-9]+)?$ ]] || err "invalid --rate: ${rate}"
  [[ "${internal_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --internal-mode: ${internal_mode}"
  [[ "${external_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --external-mode: ${external_mode}"
  [[ "${internal_pos}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --internal-pos: ${internal_pos}"
  [[ "${external_pos}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --external-pos: ${external_pos}"

  id -u "${desk_user}" >/dev/null 2>&1 || err "user not found: ${desk_user}"
  must_cmd_or_throw install

  local user_home=""
  user_home="$(getent passwd "${desk_user}" | cut -d: -f6 || true)"
  [[ -n "${user_home}" ]] || err "home directory not found: ${desk_user}"

  local bin_dir="${user_home}/.local/bin"
  local hook_script="${bin_dir}/monitor-hotplug-apply.sh"

  install -d -m 0755 -o "${desk_user}" -g "${desk_user}" "${bin_dir}"

  cat > "${hook_script}" <<SCRIPT_EOF
#!/usr/bin/env bash
set -Eeuo pipefail

log_file="${XDG_RUNTIME_DIR:-/tmp}/monitor-hotplug-apply.log"
ts() { date +"%Y-%m-%dT%H:%M:%S%z"; }
log() { printf '[%s] %s\n' "\$(ts)" "\$*" >> "\${log_file}"; }

ensure_x_env() {
  if [[ -n "\${DISPLAY:-}" && -n "\${XAUTHORITY:-}" && -r "\${XAUTHORITY}" ]]; then
    return 0
  fi

  local pid=""
  pid="\$(pgrep -u "\$(id -u)" -n gnome-shell 2>/dev/null || true)"
  [[ -n "\${pid}" ]] || return 1

  local env_file="/proc/\${pid}/environ"
  [[ -r "\${env_file}" ]] || return 1

  local disp=""
  disp="\$(tr '\\0' '\\n' < "\${env_file}" | awk -F= '\$1=="DISPLAY"{print \$2; exit}' || true)"
  local xauth=""
  xauth="\$(tr '\\0' '\\n' < "\${env_file}" | awk -F= '\$1=="XAUTHORITY"{print \$2; exit}' || true)"

  [[ -n "\${disp}" ]] || return 1
  if [[ -z "\${xauth}" || ! -r "\${xauth}" ]]; then
    xauth="\${HOME}/.Xauthority"
  fi
  [[ -r "\${xauth}" ]] || return 1

  export DISPLAY="\${disp}"
  export XAUTHORITY="\${xauth}"
  return 0
}

if ! ensure_x_env; then
  log "x env unavailable: DISPLAY/XAUTHORITY not resolved"
  exit 1
fi

xq="\$(xrandr --query 2>/dev/null || true)"
internal="\$(printf '%s\\n' "\${xq}" | awk '/ connected/ {print \$1}' | grep -E '^(eDP|LVDS)' | head -n1 || true)"
if [[ -z "\${internal}" ]]; then
  internal="\$(printf '%s\\n' "\${xq}" | awk '/ connected/ {print \$1}' | grep -Ev '^(HDMI|DP|DisplayPort)' | head -n1 || true)"
fi
external="\$(printf '%s\\n' "\${xq}" | awk '/ connected/ {print \$1}' | grep -E '^(HDMI|DP|DisplayPort)' | head -n1 || true)"

if [[ -z "\${internal}" || -z "\${external}" ]]; then
  log "connected output not found: internal=\${internal:-none} external=\${external:-none}"
  exit 1
fi

xrandr --output "\${external}" --mode "${external_mode}" --rate "${rate}" --pos "${external_pos}" --primary \
       --output "\${internal}" --mode "${internal_mode}" --rate "${rate}" --pos "${internal_pos}"
log "manual recovery applied: internal=\${internal} external=\${external}"
SCRIPT_EOF

  chown "${desk_user}:${desk_user}" "${hook_script}"
  chmod 0755 "${hook_script}"

  log "[hdmi] 자동복원 비활성 정책: 수동 복구 스크립트 배포 완료: user=${desk_user} script=${hook_script}"
}

legion_hdmi_hotplug_autostart_main "$@"
