#!/usr/bin/env bash
# file: scripts/sys/nvidia-stack.sh
# NVIDIA stack prerequisite for Legion HDMI
# 정책:
#   - 전제조건 불충족 시 즉시 실패(err), 폴백 없음
#   - 설치 필요 시 설치를 시도하고, 재부팅 요구 시 require_reboot_or_throw
set -Eeuo pipefail
set -o errtrace

nvidia_stack_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  # -------------------------------
  # Root Contract
  # -------------------------------
  if [[ "${EUID}" -ne 0 ]]; then
    err "nvidia-stack은 root 권한이 필요합니다."
  fi

  must_cmd_or_throw ubuntu-drivers
  must_cmd_or_throw apt-get

  # -------------------------------
  # Check current driver state
  # -------------------------------
  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
      log "[nvidia] nvidia-smi OK (already installed)"
      return 0
    fi
    warn "[nvidia] nvidia-smi exists but not working (driver not loaded?). continue..."
  else
    warn "[nvidia] nvidia-smi not found. continue install..."
  fi

  # -------------------------------
  # Install
  # -------------------------------
  log "[nvidia] ubuntu-drivers autoinstall"
  ubuntu-drivers autoinstall

  # Contract: NVIDIA stack 설치/전환 직후에는 reboot를 요구한다.
  require_reboot_or_throw "nvidia stack installed (driver/tooling), reboot required"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  nvidia_stack_main "$@"
fi

# [ReleaseNote] sys: reboot barrier SSOT (replace exit 5 with require_reboot_or_throw)
