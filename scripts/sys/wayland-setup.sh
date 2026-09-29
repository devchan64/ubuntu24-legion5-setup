#!/usr/bin/env bash
# 기존 Xorg 강제 설정을 해제하고 재부팅 경계를 보장한다.
set -Eeuo pipefail
source "${LEGION_SETUP_ROOT:?}/lib/common.sh"
require_supported_ubuntu_or_throw
[[ "${VERSION_ID}" == 26.04 ]] || err "Wayland 전환 단계는 Ubuntu 26.04 전용입니다."
cfg=/etc/gdm3/custom.conf
[[ -f "${cfg}" ]] || err "GDM 설정이 없습니다: ${cfg}"
if grep -Eq '^[[:space:]]*(WaylandEnable[[:space:]]*=[[:space:]]*false|DefaultSession[[:space:]]*=.*xorg)' "${cfg}"; then
  ensure_sudo_auth_or_throw
  sudo_run_or_throw cp -a --backup=numbered "${cfg}" "${cfg}.before-wayland"
  sudo_run_or_throw sed -i -E '/^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false/s/^/# /; /^[[:space:]]*DefaultSession[[:space:]]*=.*xorg/s/^/# /' "${cfg}"
  require_reboot_or_throw "Wayland 활성화를 위해 GDM의 Xorg 강제 설정을 해제했습니다."
fi
log "[sys] Wayland 세션 설정 확인 완료"
