#!/usr/bin/env bash
# OBS Studio 설치(apt/PPA) + obs-backgroundremoval 플러그인(.deb) 자동 설치(기본)
# 정책: 폴백 없음, 실패 즉시 중단
# 옵션:
#   --no-bgremoval : 배경 제거 플러그인 설치를 생략
#
# 동작 개요:
#  - 설치 전 OBS/플러그인 설치 여부를 점검
#  - 이미 설치되어 있으면 사용자에게 재설치(업데이트) 여부를 확인
#  - 비대화형(TTY 아님) 환경에서 설치되어 있는 경우 → 확인이 필요하므로 즉시 중단
set -Eeuo pipefail

# 공통 유틸
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

# 이 스크립트는 "사용자 컨텍스트"에서 돌도록 설계됨(install-all.sh가 user_exec로 호출)
# root로 직접 실행 시 중단
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  err "root로 직접 실행하지 마세요. 일반 사용자로 실행하세요(내부에서 sudo를 사용합니다)."
fi

# 옵션 파싱
INSTALL_BGREMOVAL=1
for arg in "$@"; do
  case "$arg" in
    --no-bgremoval) INSTALL_BGREMOVAL=0 ;;
    *) err "알 수 없는 옵션: $arg  (허용: --no-bgremoval)" ;;
  esac
done

# OS 확인 (22.04/24.04 권장)
[[ -r /etc/os-release ]] || err "/etc/os-release 를 읽을 수 없습니다."
# shellcheck disable=SC1091
. /etc/os-release
UBU_VER="${VERSION_ID:-unknown}"
case "$UBU_VER" in
  22.04|24.04) log "Ubuntu ${UBU_VER} 감지" ;;
  *) log "감지된 Ubuntu 버전: ${UBU_VER}. 22.04/24.04에서 검증되었습니다." ;;
esac

# sudo 세션 확인
sudo -v >/dev/null

# ─────────────────────────────────────────────────────────────
# 유틸
# ─────────────────────────────────────────────────────────────
is_pkg_installed() {
  # dpkg 기반 설치여부 확인
  local name="$1"
  dpkg-query -W -f='${Status}\n' "$name" 2>/dev/null | grep -q "install ok installed"
}

has_flatpak_obs() {
  command -v flatpak >/dev/null 2>&1 && flatpak info com.obsproject.Studio >/dev/null 2>&1
}

ensure_tty_or_die_for_confirmation() {
  # 설치되어 있어 재설치 확인이 필요한 경우, 비대화형이면 중단
  if [[ ! -t 0 ]]; then
    err "재설치 확인 입력이 필요한데 TTY가 아닙니다. GUI 사용자 터미널에서 다시 실행하세요."
  fi
}

ask_yes_no() {
  # 사용: if ask_yes_no "메시지"; then ...; fi
  local prompt="$1"
  local ans
  read -r -p "${prompt} [y/N]: " ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────
# 설치 루틴
# ─────────────────────────────────────────────────────────────
install_obs_via_apt() {
  log "필수 패키지 설치 및 저장소 준비"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends software-properties-common curl ca-certificates

  log "OBS 공식 PPA 추가"
  sudo add-apt-repository -y ppa:obsproject/obs-studio

  log "OBS 및 관련 패키지 설치"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    obs-studio qtwayland5 v4l2loopback-dkms ffmpeg

  # 설치 검증
  command -v obs >/dev/null 2>&1 || err "obs 바이너리를 찾을 수 없습니다."
  log "OBS 설치 완료: $(obs --version | head -n 1)"
}

install_obs_bgremoval_deb() {
  log "obs-backgroundremoval 최신 .deb 검색 및 설치"

  command -v obs >/dev/null 2>&1 || err "OBS가 설치되어 있지 않습니다."

  # jq 필요
  if ! command -v jq >/dev/null 2>&1; then
    log "jq 설치"
    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends jq
  fi

  local owner="${PLUGIN_OWNER:-royshil}"
  local repo="${PLUGIN_REPO:-obs-backgroundremoval}"
  local tag="${PLUGIN_TAG:-latest}"
  local arch; arch="$(dpkg --print-architecture)"
  [[ "$arch" =~ ^(amd64|arm64)$ ]] || err "미지원 아키텍처: $arch"

  local api json deb_url
  if [[ "$tag" == "latest" ]]; then
    api="https://api.github.com/repos/${owner}/${repo}/releases/latest"
  else
    api="https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}"
  fi

  json="$(curl -fsSL "$api")" || err "GitHub API 호출 실패"
  deb_url="$(
    echo "$json" | jq -r --arg arch "$arch" '
      .assets[]?.browser_download_url
      | select(endswith(".deb"))
      | select((test($arch)) or (test("linux|ubuntu"; "i")))
    ' | head -n1
  )"
  [[ -n "$deb_url" && "$deb_url" != "null" ]] || err ".deb 자산을 찾지 못했습니다. 저장소/태그를 확인하세요."

  # _apt 접근권 보장되는 경로에 임시 디렉터리 생성
  local tmpd deb_file
  tmpd="$(mktemp -d -p /var/tmp obsbgremoval.XXXXXX)"
  chmod 755 "$tmpd"
  trap 'rm -rf "$tmpd"' RETURN

  pushd "$tmpd" >/dev/null
  log "다운로드: $deb_url"
  curl -fLO "$deb_url"

  deb_file="$(ls *.deb | head -n1)"
  [[ -f "$deb_file" ]] || err ".deb 파일이 존재하지 않습니다."
  chmod 644 "$deb_file"

  log "패키지 설치: $deb_file"
  sudo apt-get update -y
  sudo apt-get install -y "$PWD/$deb_file"
  popd >/dev/null

  dpkg -L obs-backgroundremoval 2>/dev/null | grep -qE '\.so$' \
    || err "설치 검증 실패: obs-backgroundremoval .so가 확인되지 않음"

  log "플러그인 설치 완료: obs-backgroundremoval"
  log "경로 확인 예: dpkg -L obs-backgroundremoval | grep -E '\\.so$'"
}

post_gpu_tips() {
  log "GPU/Wayland 안내"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
    log "NVENC 사용 가능하려면 ffmpeg/OBS 빌드에 NVENC가 포함되어야 합니다."
  fi

  if lspci | grep -i 'VGA\|3D' | grep -iq 'AMD'; then
    log "AMD GPU 감지됨: VAAPI 사용을 검토하세요 (mesa-va-drivers, libva-drm2, libva2 등)."
  fi

  log "Wayland 권장 사항: xdg-desktop-portal(+gnome/gtk), pipewire, wireplumber 최신화를 유지하세요."
  log "화면 캡처는 'PipeWire (Wayland)' 소스를 사용하세요."
}

# ─────────────────────────────────────────────────────────────
# 설치 전 확인(OBS / 플러그인)
# ─────────────────────────────────────────────────────────────
OBS_INSTALLED_APT=0
OBS_INSTALLED_FLATPAK=0
PLUGIN_INSTALLED=0

if is_pkg_installed obs-studio; then
  OBS_INSTALLED_APT=1
fi

if has_flatpak_obs; then
  OBS_INSTALLED_FLATPAK=1
fi

if is_pkg_installed obs-backgroundremoval; then
  PLUGIN_INSTALLED=1
fi

# OBS 설치/업데이트 여부 질의
proceed_obs_install=1
if [[ "${OBS_INSTALLED_APT}" -eq 1 || "${OBS_INSTALLED_FLATPAK}" -eq 1 ]]; then
  ensure_tty_or_die_for_confirmation
  log "OBS가 이미 설치되어 있습니다."
  if [[ "${OBS_INSTALLED_APT}" -eq 1 ]]; then
    log " - APT 패키지: obs-studio (dpkg 등록됨)"
  fi
  if [[ "${OBS_INSTALLED_FLATPAK}" -eq 1 ]]; then
    log " - Flatpak 패키지: com.obsproject.Studio (flatpak 등록됨)"
  fi
  if ask_yes_no "OBS를 재설치/업데이트 하시겠습니까?"; then
    proceed_obs_install=1
  else
    proceed_obs_install=0
    log "사용자 선택으로 OBS 재설치를 건너뜁니다."
  fi
fi

# 플러그인 설치/업데이트 여부 질의
proceed_plugin_install="${INSTALL_BGREMOVAL}"
if [[ "${INSTALL_BGREMOVAL}" -eq 1 && "${PLUGIN_INSTALLED}" -eq 1 ]]; then
  ensure_tty_or_die_for_confirmation
  log "obs-backgroundremoval 플러그인이 이미 설치되어 있습니다."
  if ask_yes_no "플러그인을 재설치/업데이트 하시겠습니까?"; then
    proceed_plugin_install=1
  else
    proceed_plugin_install=0
    log "사용자 선택으로 플러그인 재설치를 건너뜁니다."
  fi
fi

# ─────────────────────────────────────────────────────────────
# 실제 작업
# ─────────────────────────────────────────────────────────────
if [[ "${proceed_obs_install}" -eq 1 ]]; then
  install_obs_via_apt
else
  # 설치를 건너뛴 경우에도 바이너리가 있는지 점검(Flatpak만 있을 수도 있음)
  if ! command -v obs >/dev/null 2>&1; then
    log "주의: obs 바이너리가 시스템 경로에 없습니다(Flatpak만 설치되었을 수 있음)."
  fi
fi

if [[ "${proceed_plugin_install}" -eq 1 ]]; then
  install_obs_bgremoval_deb
else
  log "요청에 따라 obs-backgroundremoval 설치/업데이트를 생략합니다."
fi

post_gpu_tips

log "설치 스크립트 완료"
printf -- "---------------------------------------------\n"
printf -- "실행: obs\n"
if [[ "${INSTALL_BGREMOVAL}" -eq 1 ]]; then
  printf -- "플러그인: obs-backgroundremoval (기본 설치 대상; 재설치 시 사용자 확인 반영)\n"
else
  printf -- "플러그인: 설치 생략(--no-bgremoval)\n"
fi
printf -- "---------------------------------------------\n"
