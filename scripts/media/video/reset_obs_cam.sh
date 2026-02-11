#!/usr/bin/env bash
# file: scripts/media/video/reset_obs_cam.sh
#
# /** Domain: Contract: Fail-Fast: SideEffect: */
# - Domain: v4l2loopback 기반 OBS Virtual Camera 커널 모듈을 리셋(재로드)한다.
# - Contract:
#   - Ubuntu 환경에서 v4l2loopback 모듈이 설치되어 있어야 한다(SSOT: scripts/media/* 설치 스텝)
#   - root 권한 필요(modprobe). 본 스크립트는 sudo 폴백을 하지 않는다(무폴백)
# - Fail-Fast: 전제조건/명령 부재/로드 실패 시 즉시 종료
# - SideEffect: 커널 모듈 언로드/로드, /dev/video* 디바이스 노출 변경

set -Eeuo pipefail
set -o errtrace

_ts(){ date +'%F %T'; }
log(){ printf "[INFO ][%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERR  ][%s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

# -------------------------------
# Contract: root required (no sudo fallback)
# -------------------------------
if [[ "${EUID}" -ne 0 ]]; then
  err "root 권한 필요(modprobe). sudo로 재실행하세요: sudo -E $0"
fi

# -------------------------------
# Contract: commands
# -------------------------------
for c in modprobe; do
  command -v "$c" >/dev/null 2>&1 || err "required command not found: $c"
done

# -------------------------------
# SSOT: module options
# -------------------------------
V4L2_MODULE="v4l2loopback"
V4L2_DEVICES="1"
V4L2_VIDEO_NR="10"
V4L2_CARD_LABEL="OBS Virtual Camera"
V4L2_EXCLUSIVE_CAPS="1"

reset_v4l2loopback_or_throw() {
  log "Resetting v4l2loopback virtual camera..."
  # Domain: 없는 경우에도 리셋이 목적이므로 unload는 best-effort(여기만 예외적으로 허용)
  modprobe -r "${V4L2_MODULE}" >/dev/null 2>&1 || true

  modprobe "${V4L2_MODULE}" \
    devices="${V4L2_DEVICES}" \
    video_nr="${V4L2_VIDEO_NR}" \
    card_label="${V4L2_CARD_LABEL}" \
    exclusive_caps="${V4L2_EXCLUSIVE_CAPS}"
}

reset_v4l2loopback_or_throw
log "[OK] Done. Launch OBS manually if needed."
