#!/usr/bin/env bash
set -Eeuo pipefail

# Domain: Media setup for Ubuntu (OBS + virtual camera + virtual audio)
# Contract: OBS runtime is apt-only (Flatpak OBS is not supported)
# Fail-Fast: no fallback; mixed install state throws
# SideEffect: installs apt packages, configures kernel module options, enables user systemd services

media_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:media}"

  resume_run_step_or_throw "${RESUME_SCOPE}" "${MEDIA_STEPKEY_PRECHECK_OBS_RUNTIME}" -- _media_assert_obs_runtime_is_apt_only_or_throw
  resume_run_step_or_throw "${RESUME_SCOPE}" "${MEDIA_STEPKEY_OBS_INSTALL}" -- must_run "${MEDIA_SCRIPT_REL_OBS_INSTALL}"
  resume_run_step_or_throw "${RESUME_SCOPE}" "${MEDIA_STEPKEY_OBS_VIRTUALCAM_ENSURE}" -- _media_ensure_obs_virtual_camera_or_throw
  resume_run_step_or_throw "${RESUME_SCOPE}" "${MEDIA_STEPKEY_AUDIO_VIRTUAL_INSTALL}" -- must_run "${MEDIA_SCRIPT_REL_AUDIO_INSTALL}"

  log "[media] done"
}

# ─────────────────────────────────────────────────────────────
# Business rules
# ─────────────────────────────────────────────────────────────
_media_assert_obs_runtime_is_apt_only_or_throw() {
  require_cmd dpkg

  local has_flatpak=0
  if command -v flatpak >/dev/null 2>&1; then
    if flatpak info "${OBS_FLATPAK_APP_ID}" >/dev/null 2>&1; then
      has_flatpak=1
    fi
  fi

  local has_apt=0
  if dpkg-query -W -f='${Status}\n' obs-studio 2>/dev/null | grep -q "install ok installed"; then
    has_apt=1
  fi

  if [[ "${has_flatpak}" -eq 1 && "${has_apt}" -eq 1 ]]; then
    err "OBS is installed via both apt and Flatpak. Keep apt only: remove Flatpak (${OBS_FLATPAK_APP_ID}) first."
  fi

  if [[ "${has_flatpak}" -eq 1 && "${has_apt}" -eq 0 ]]; then
    err "Flatpak OBS detected. media supports apt OBS only. Remove Flatpak (${OBS_FLATPAK_APP_ID}) and rerun."
  fi

  log "[media] OBS runtime precheck OK (apt-only policy)"
}

_media_ensure_obs_virtual_camera_or_throw() {
  require_cmd sudo
  require_cmd modprobe

  sudo -v >/dev/null

  local video_nr="${OBS_V4L2_VIDEO_NR:-10}"
  local label="${OBS_V4L2_LABEL:-OBS Virtual Camera}"

  _media_write_v4l2loopback_persist_config_or_throw "${video_nr}" "${label}"

  # 현재 세션 즉시 적용(모듈 reload)
  must_run "${MEDIA_SCRIPT_REL_RESET_OBS_CAM}"

  if [[ ! -e "/dev/video${video_nr}" ]]; then
    err "Virtual camera device not found: /dev/video${video_nr}. Check v4l2loopback-dkms build and SecureBoot."
  fi

  log "[media] virtual camera ready: /dev/video${video_nr} (${label})"
}

# ─────────────────────────────────────────────────────────────
# Adapters / IO
# ─────────────────────────────────────────────────────────────
_media_write_v4l2loopback_persist_config_or_throw() {
  local video_nr="${1:?video_nr required}"
  local label="${2:?label required}"

  # Contract: 숫자만 허용
  if [[ ! "${video_nr}" =~ ^[0-9]+$ ]]; then
    err "invalid OBS_V4L2_VIDEO_NR: '${video_nr}'"
  fi

  # Contract: 모듈 옵션 내 card_label은 따옴표로 감싸지만, 안전 문자만 허용
  # NOTE: bash [[ =~ ]] 우변에 공백이 있으면 문법 오류가 날 수 있어 정규식을 변수로 분리
  local label_regex='^[a-zA-Z0-9._:-][a-zA-Z0-9._: -]*$'
  if [[ ! "${label}" =~ ${label_regex} ]]; then
    err "invalid OBS_V4L2_LABEL: '${label}'"
  fi

  sudo install -d -m 0755 /etc/modprobe.d /etc/modules-load.d

  # v4l2loopback 옵션 SSOT
  sudo tee "${MEDIA_V4L2_MODPROBE_CONF}" >/dev/null <<EOF
options v4l2loopback devices=1 video_nr=${video_nr} card_label="${label}" exclusive_caps=1
EOF

  # 부팅 시 모듈 자동 로드
  sudo tee "${MEDIA_V4L2_MODULES_LOAD_CONF}" >/dev/null <<'EOF'
v4l2loopback
EOF

  log "[media] persisted v4l2loopback config:"
  log " - ${MEDIA_V4L2_MODPROBE_CONF}"
  log " - ${MEDIA_V4L2_MODULES_LOAD_CONF}"
}


# ─────────────────────────────────────────────────────────────
# Options / Constants
# ─────────────────────────────────────────────────────────────
OBS_FLATPAK_APP_ID="com.obsproject.Studio"

MEDIA_SCRIPT_REL_OBS_INSTALL="scripts/media/video/obs-install.sh"
MEDIA_SCRIPT_REL_AUDIO_INSTALL="scripts/media/audio/install-virtual-audio.sh"
MEDIA_SCRIPT_REL_RESET_OBS_CAM="scripts/media/video/reset_obs_cam.sh"

MEDIA_V4L2_MODPROBE_CONF="/etc/modprobe.d/obs-v4l2loopback.conf"
MEDIA_V4L2_MODULES_LOAD_CONF="/etc/modules-load.d/obs-v4l2loopback.conf"

MEDIA_STEPKEY_PRECHECK_OBS_RUNTIME="media:precheck:obs-runtime"
MEDIA_STEPKEY_OBS_INSTALL="media:obs:install"
MEDIA_STEPKEY_OBS_VIRTUALCAM_ENSURE="media:obs:virtualcam:ensure"
MEDIA_STEPKEY_AUDIO_VIRTUAL_INSTALL="media:audio:virtual:install"

# [ReleaseNote] breaking
