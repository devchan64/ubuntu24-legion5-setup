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
  local internal_mode=""
  local external_mode=""
  local internal_pos=""
  local external_pos=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)   desk_user="${2:-}"; shift 2 ;;
      --layout) layout="${2:-}"; shift 2 ;;
      --rate)   rate="${2:-}"; shift 2 ;;
      --internal-mode) internal_mode="${2:-}"; shift 2 ;;
      --external-mode) external_mode="${2:-}"; shift 2 ;;
      --internal-pos) internal_pos="${2:-}"; shift 2 ;;
      --external-pos) external_pos="${2:-}"; shift 2 ;;
      *)        err "unknown arg: $1" ;;
    esac
  done

  [[ -n "${desk_user}" ]] || err "--user <desktopUser> required"
  [[ -n "${layout}" ]] || err "--layout <left|right|above|below|mirror> required"
  [[ -n "${rate}" ]] || err "--rate <hz> required"
  [[ "${rate}" =~ ^[0-9]+([.][0-9]+)?$ ]] || err "invalid --rate: ${rate}"
  [[ -z "${internal_mode}" || "${internal_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --internal-mode: ${internal_mode} (ex: 2560x1600)"
  [[ -z "${external_mode}" || "${external_mode}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --external-mode: ${external_mode} (ex: 1920x1080)"
  [[ -z "${internal_pos}" || "${internal_pos}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --internal-pos: ${internal_pos} (ex: 3840x0)"
  [[ -z "${external_pos}" || "${external_pos}" =~ ^[0-9]+x[0-9]+$ ]] || err "invalid --external-pos: ${external_pos} (ex: 0x0)"
  if [[ -n "${internal_pos}" && -z "${external_pos}" ]]; then
    err "--external-pos required when --internal-pos is set"
  fi
  if [[ -n "${external_pos}" && -z "${internal_pos}" ]]; then
    err "--internal-pos required when --external-pos is set"
  fi

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
  if [[ -z "${external}" ]]; then
    local nvidia_state="nvidia-smi 명령 없음"
    if command -v nvidia-smi >/dev/null 2>&1; then
      if nvidia-smi >/dev/null 2>&1; then
        nvidia_state="nvidia-smi 정상"
      else
        nvidia_state="nvidia-smi 실패: 현재 커널용 NVIDIA 모듈/드라이버 계열 불일치 가능"
      fi
    fi

    local drm_status=""
    drm_status="$(for status_file in /sys/class/drm/*/status; do
      [[ -e "${status_file}" ]] || continue
      printf '%s=%s\n' "${status_file}" "$(cat "${status_file}")"
    done)"

    err "외부 디스플레이를 찾지 못했습니다(HDMI/DP).
NVIDIA 상태: ${nvidia_state}

점검 순서:
1. 현재 커널용 NVIDIA 모듈이 설치됐는지 확인: modinfo -k \$(uname -r) nvidia
2. NVIDIA 드라이버 계열이 590/595 등으로 섞여 있으면 실제 사용 계열 하나로 정리
3. GNOME 모니터 캐시가 오래됐으면 ~/.config/monitors.xml 백업 후 재로그인
4. NVIDIA Runtime PM 영향이 의심되면 dGPU power/control을 on으로 고정 후 재부팅

xrandr 출력:
${xq}

DRM 커넥터 상태:
${drm_status}"
  fi

  local internal_mode_arg="--auto"
  local external_mode_arg="--auto"
  if [[ -n "${internal_mode}" ]]; then
    internal_mode_arg="--mode ${internal_mode}"
  fi
  if [[ -n "${external_mode}" ]]; then
    external_mode_arg="--mode ${external_mode}"
  fi

  log "[hdmi] internal=${internal} external=${external} layout=${layout} rate=${rate} internal_mode=${internal_mode:-auto} external_mode=${external_mode:-auto} internal_pos=${internal_pos:-auto} external_pos=${external_pos:-auto}"

  if [[ -n "${internal_pos}" && -n "${external_pos}" ]]; then
    sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --pos "${internal_pos}" --output "${external}" ${external_mode_arg} --pos "${external_pos}" --rate "${rate}" --primary
  else
    case "${layout}" in
      right)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --output "${external}" ${external_mode_arg} --right-of "${internal}" --rate "${rate}" --primary ;;
      left)   sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --output "${external}" ${external_mode_arg} --left-of "${internal}" --rate "${rate}" --primary ;;
      above)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --output "${external}" ${external_mode_arg} --above "${internal}" --rate "${rate}" --primary ;;
      below)  sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --output "${external}" ${external_mode_arg} --below "${internal}" --rate "${rate}" --primary ;;
      mirror) sudo -u "${desk_user}" env "${user_env[@]}" xrandr --output "${internal}" ${internal_mode_arg} --output "${external}" ${external_mode_arg} --same-as "${internal}" --rate "${rate}" --primary ;;
      *) err "invalid --layout: ${layout}" ;;
    esac
  fi

  log "[hdmi] layout applied"
}

legion_hdmi_layout_main "$@"
