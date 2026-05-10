#!/usr/bin/env bash
# file: scripts/sys/legion-hdmi.sh
set -Eeuo pipefail
set -o errtrace

legion_hdmi_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "legion-hdmi must run as root"
  fi

  local desk_user=""
  local layout="right"
  local req_rate="60"
  local internal_mode="2560x1600"
  local external_mode="3840x2160"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)   desk_user="${2:-}"; shift 2 ;;
      --layout) layout="${2:-}"; shift 2 ;;
      --rate)   req_rate="${2:-}"; shift 2 ;;
      --internal-mode) internal_mode="${2:-}"; shift 2 ;;
      --external-mode) external_mode="${2:-}"; shift 2 ;;
      *)        err "unknown arg: $1" ;;
    esac
  done

  [[ -n "${desk_user}" ]] || err "Contract violation: --user <desktopUser> required"
  id -u "${desk_user}" >/dev/null 2>&1 || err "user not found: ${desk_user}"

  must_run_or_throw "scripts/sys/nvidia-stack.sh"
  must_run_or_throw "scripts/sys/setup-legion-5-hdmi.sh"
  must_run_or_throw "scripts/sys/legion-hdmi-layout.sh" --user "${desk_user}" --layout "${layout}" --rate "${req_rate}" --internal-mode "${internal_mode}" --external-mode "${external_mode}"
  must_run_or_throw "scripts/sys/legion-hdmi-hotplug-autostart.sh" --user "${desk_user}" --rate "${req_rate}" --internal-mode "${internal_mode}" --external-mode "${external_mode}"
}

legion_hdmi_main "$@"
