#!/usr/bin/env bash
# file: scripts/sys/setup-legion-5-hdmi.sh
# Legion 5 HDMI setup for Ubuntu 24.04 (Xorg + NVIDIA open kernel driver)
# - PRIME auto-switch to nvidia (reboot required → require_reboot_or_throw)
# Policy: no fallbacks, fail-fast
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "setup-legion-5-hdmi must run as root"
  fi

  must_cmd_or_throw prime-select
  must_cmd_or_throw update-initramfs

  local target_prime="${TARGET_PRIME:-nvidia}"
  local current_prime=""
  current_prime="$(prime-select query 2>/dev/null || true)"

  log "[prime] current=${current_prime:-unknown} target=${target_prime}"

  if [[ "${current_prime}" != "${target_prime}" ]]; then
    log "[prime] switching PRIME -> ${target_prime}"
    prime-select "${target_prime}"

    log "[prime] update-initramfs -u"
    update-initramfs -u

    require_reboot_or_throw "PRIME switched to ${target_prime} (display stack), reboot required"
  fi

  log "[prime] PRIME already desired: ${target_prime}"
}

main "$@"
