#!/usr/bin/env bash
# NVIDIA stack prerequisite for Legion HDMI
# 정책:
#   - 전제조건 불충족 시 즉시 실패(err), 폴백 없음
#   - 설치 필요 시 설치를 시도하고, 재부팅 요구 시 exit 5
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

  # -------------------------------
  # Flags
  # -------------------------------
  local AUTO_INSTALL=1
  local argv=("$@")

  local i=0
  while (( i < ${#argv[@]} )); do
    case "${argv[$i]}" in
      --no-install) AUTO_INSTALL=0 ;;
      *) ;;
    esac
    (( i++ ))
  done

  require_cmd "lspci" || err "lspci not found"
  require_cmd "xrandr" || err "xrandr not found"

  ensure_nvidia_userspace_installed_or_throw() {
    # Domain: Legion HDMI는 NVIDIA userspace prerequisite.
    # SideEffect: missing이면 설치 시도 후 reboot 요구.
    if command -v nvidia-smi >/dev/null 2>&1; then
      return 0
    fi

    (( AUTO_INSTALL == 1 )) || err "NVIDIA 스택이 설치되지 않았습니다(nvidia-smi 없음). --no-install 이므로 중단합니다."

    log "[nvidia] NVIDIA userspace 미설치(nvidia-smi 없음) → 설치 시도"
    if ! command -v ubuntu-drivers >/dev/null 2>&1; then
      log "[nvidia] ubuntu-drivers 없음 → ubuntu-drivers-common 설치"
      apt-get update -y || err "apt-get update failed"
      apt-get install -y ubuntu-drivers-common || err "install ubuntu-drivers-common failed"
    fi

    ubuntu-drivers devices >/dev/null 2>&1 || err "ubuntu-drivers devices failed"
    ubuntu-drivers autoinstall || err "ubuntu-drivers autoinstall failed"

    warn "[nvidia] 드라이버 설치 완료. 재부팅 후 다시 실행하세요."
    exit 5
  }

  assert_nvidia_kernel_loaded_or_throw() {
    # Domain: 커널 드라이버 활성 여부는 userspace(nvidia-smi) 또는 lspci가 SSOT.
    if command -v nvidia-smi >/dev/null 2>&1; then
      nvidia-smi >/dev/null 2>&1 && return 0
    fi

    if lspci -k 2>/dev/null | grep -A3 -E 'NVIDIA' | grep -q 'Kernel driver in use: nvidia'; then
      return 0
    fi

    err "NVIDIA 커널 드라이버가 활성화되지 않았습니다.
- 확인: lspci -k | grep -A3 NVIDIA
- 권장: sudo reboot
- 그래도 실패 시: sudo ubuntu-drivers autoinstall"
  }

  assert_nvidia_prime_tools_ready_or_throw() {
    # Contract: HDMI 절차는 NVIDIA userspace + PRIME 도구가 준비되어야 한다.
    if ! command -v nvidia-smi >/dev/null 2>&1; then
      err "NVIDIA 스택이 설치되지 않았습니다(nvidia-smi 없음).
- 권장: sudo ubuntu-drivers autoinstall && sudo reboot
- 확인: ubuntu-drivers devices"
    fi

    if ! command -v prime-select >/dev/null 2>&1; then
      err "NVIDIA PRIME 도구가 없습니다(prime-select 없음).
- 권장: sudo apt install -y ubuntu-drivers-common
- 또는: sudo ubuntu-drivers autoinstall && sudo reboot"
    fi
  }

  ensure_nvidia_userspace_installed_or_throw
  assert_nvidia_kernel_loaded_or_throw
  assert_nvidia_prime_tools_ready_or_throw

  log "[nvidia] ok"
}

# [ReleaseNote] sys: extract NVIDIA prerequisite into scripts/sys/nvidia-stack.sh (exit 5 on reboot-required)

nvidia_stack_main "$@"
