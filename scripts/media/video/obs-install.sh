#!/usr/bin/env bash
set -Eeuo pipefail

# Domain: Media/OBS 설치(apt SSOT)
# Contract: Flatpak OBS 발견 시 즉시 중단(apt-only). 재설치 확인은 TTY 필요(또는 --yes).
# Fail-Fast: 폴백 없음. 혼합 설치 상태/비대화형 확인 필요/아키텍처 미지원 등 즉시 throw.
# SideEffect: apt repo 추가, 패키지 설치, GitHub API 호출, 로컬 .deb 설치

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

obs_apt_install_main() {
  obs_apt_install_contract_validate_entry_or_throw "$@"
  obs_apt_install_execute_or_throw
  obs_apt_install_print_next_steps
}

# ─────────────────────────────────────────────────────────────
# Top: business logic (SSOT)
# ─────────────────────────────────────────────────────────────
obs_apt_install_contract_validate_entry_or_throw() {
  obs_apt_install_contract_reject_root_or_throw
  obs_apt_install_contract_parse_cli_options_or_throw "$@"
  obs_apt_install_contract_validate_os_release_or_throw
  obs_apt_install_contract_validate_obs_runtime_policy_or_throw
  obs_apt_install_contract_prime_sudo_session_or_throw
}

obs_apt_install_execute_or_throw() {
  local should_reinstall_obs=1
  local should_reinstall_plugin="${OBS_BGREMOVAL_INSTALL_ENABLED}"

  should_reinstall_obs="$(obs_apt_install_decide_obs_reinstall_or_throw)"
  should_reinstall_plugin="$(obs_apt_install_decide_plugin_reinstall_or_throw)"

  if [[ "${should_reinstall_obs}" -eq 1 ]]; then
    obs_apt_install_install_obs_via_apt_or_throw
  else
    obs_apt_install_validate_obs_binary_presence_or_log
  fi

  if [[ "${should_reinstall_plugin}" -eq 1 ]]; then
    obs_apt_install_install_bgremoval_deb_or_throw
  else
    log "[obs] 요청에 따라 obs-backgroundremoval 설치/업데이트 생략"
  fi

  obs_apt_install_post_gpu_and_wayland_tips_log
  log "[obs] 설치 스크립트 완료"
}

obs_apt_install_decide_obs_reinstall_or_throw() {
  local obs_installed_apt=0
  local obs_installed_flatpak=0

  if obs_apt_install_adapter_is_dpkg_package_installed "obs-studio"; then
    obs_installed_apt=1
  fi
  if obs_apt_install_adapter_is_flatpak_obs_installed; then
    obs_installed_flatpak=1
  fi

  if [[ "${obs_installed_flatpak}" -eq 1 ]]; then
    err "Flatpak OBS가 감지되었습니다(정책 위반). 제거 후 재실행하세요: ${OBS_FLATPAK_APP_ID}"
  fi

  if [[ "${obs_installed_apt}" -eq 0 ]]; then
    echo 1
    return 0
  fi

  log "[obs] OBS가 이미 설치되어 있습니다: obs-studio(dpkg)"
  if obs_apt_install_adapter_is_assume_yes_enabled; then
    log "[obs] --yes 감지: OBS 재설치/업데이트 진행"
    echo 1
    return 0
  fi

  obs_apt_install_contract_require_tty_for_confirmation_or_throw
  if obs_apt_install_adapter_ask_yes_no "OBS를 재설치/업데이트 하시겠습니까?"; then
    echo 1
  else
    log "[obs] 사용자 선택: OBS 재설치/업데이트 스킵"
    echo 0
  fi
}

obs_apt_install_decide_plugin_reinstall_or_throw() {
  if [[ "${OBS_BGREMOVAL_INSTALL_ENABLED}" -eq 0 ]]; then
    echo 0
    return 0
  fi

  local plugin_installed=0
  if obs_apt_install_adapter_is_dpkg_package_installed "obs-backgroundremoval"; then
    plugin_installed=1
  fi

  if [[ "${plugin_installed}" -eq 0 ]]; then
    echo 1
    return 0
  fi

  log "[obs] obs-backgroundremoval 플러그인이 이미 설치되어 있습니다"
  if obs_apt_install_adapter_is_assume_yes_enabled; then
    log "[obs] --yes 감지: 플러그인 재설치/업데이트 진행"
    echo 1
    return 0
  fi

  obs_apt_install_contract_require_tty_for_confirmation_or_throw
  if obs_apt_install_adapter_ask_yes_no "플러그인을 재설치/업데이트 하시겠습니까?"; then
    echo 1
  else
    log "[obs] 사용자 선택: 플러그인 재설치/업데이트 스킵"
    echo 0
  fi
}

# ─────────────────────────────────────────────────────────────
# Middle: adapters / IO
# ─────────────────────────────────────────────────────────────
obs_apt_install_install_obs_via_apt_or_throw() {
  log "[obs] 필수 패키지 설치 및 저장소 준비"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends software-properties-common curl ca-certificates

  log "[obs] OBS 공식 PPA 추가"
  sudo add-apt-repository -y "${OBS_APT_PPA}"

  log "[obs] OBS 및 관련 패키지 설치"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    obs-studio qtwayland5 v4l2loopback-dkms ffmpeg

  command -v obs >/dev/null 2>&1 || err "obs 바이너리를 찾을 수 없습니다."
  log "[obs] OBS 설치 완료: $(obs --version | head -n 1)"
}

obs_apt_install_install_bgremoval_deb_or_throw() {
  command -v obs >/dev/null 2>&1 || err "OBS가 설치되어 있지 않습니다(apt OBS 필요)."

  obs_apt_install_adapter_ensure_jq_installed_or_throw

  local deb_url
  deb_url="$(obs_apt_install_adapter_resolve_bgremoval_deb_url_or_throw)"

  local tmp_dir deb_file_path
  tmp_dir="$(mktemp -d -p /var/tmp obsbgremoval.XXXXXX)"
  chmod 755 "${tmp_dir}"
  trap 'rm -rf "${tmp_dir}"' RETURN

  log "[obs] 플러그인 다운로드: ${deb_url}"
  curl -fL "${deb_url}" -o "${tmp_dir}/obs-backgroundremoval.deb"

  deb_file_path="${tmp_dir}/obs-backgroundremoval.deb"
  [[ -f "${deb_file_path}" ]] || err ".deb 파일이 존재하지 않습니다."

  log "[obs] 플러그인 설치(apt local file): ${deb_file_path}"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${deb_file_path}"

  obs_apt_install_adapter_validate_bgremoval_dpkg_payload_or_throw
  log "[obs] 플러그인 설치 완료: obs-backgroundremoval"
}

obs_apt_install_adapter_resolve_bgremoval_deb_url_or_throw() {
  local owner="${OBS_BGREMOVAL_PLUGIN_OWNER}"
  local repo="${OBS_BGREMOVAL_PLUGIN_REPO}"
  local tag="${OBS_BGREMOVAL_PLUGIN_TAG}"

  local arch; arch="$(dpkg --print-architecture)"
  [[ "${arch}" =~ ^(amd64|arm64)$ ]] || err "미지원 아키텍처: ${arch}"

  local api_url
  if [[ "${tag}" == "latest" ]]; then
    api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
  else
    api_url="https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}"
  fi

  local release_json
  release_json="$(curl -fsSL "${api_url}")" || err "GitHub API 호출 실패: ${api_url}"

  local arch_token
  case "${arch}" in
    amd64) arch_token="x86_64" ;;
    arm64) arch_token="aarch64" ;;
    *) err "미지원 아키텍처 토큰 변환 실패: ${arch}" ;;
  esac

  local url
  url="$(
    echo "${release_json}" | jq -r --arg arch_token "${arch_token}" '
      [
        .assets[]?.browser_download_url
        | select(type=="string")
        | select(endswith(".deb"))
      ] as $urls
      | (
          $urls
          | map(select(test("obs-backgroundremoval_.*_" + $arch_token + "-linux-gnu\\.deb$")))
          | .[0]
        ) // (
          $urls
          | map(select(test($arch_token)))
          | .[0]
        ) // (
          $urls
          | .[0]
        )
    '
  )"

  [[ -n "${url}" && "${url}" != "null" ]] || err ".deb 자산을 찾지 못했습니다. 릴리즈 자산을 확인하세요."
  echo "${url}"
}

obs_apt_install_adapter_ensure_jq_installed_or_throw() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  log "[obs] jq 설치"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends jq
  command -v jq >/dev/null 2>&1 || err "jq 설치 실패"
}

obs_apt_install_adapter_validate_bgremoval_dpkg_payload_or_throw() {
  obs_apt_install_adapter_is_dpkg_package_installed "obs-backgroundremoval" \
    || err "설치 검증 실패: obs-backgroundremoval 패키지가 dpkg에 없습니다."

  # Contract: 플러그인 .so가 패키지 payload 내에 최소 1개 존재해야 함
  local so_list
  so_list="$(dpkg -L obs-backgroundremoval 2>/dev/null | grep -E '\.so$' || true)"
  if [[ -z "${so_list}" ]]; then
    err "설치 검증 실패: obs-backgroundremoval의 .so 파일이 확인되지 않음"
  fi

  # Contract: OBS 표준 플러그인 경로에 설치되어야 함(배포별 경로 차이 허용)
  # - /usr/lib/obs-plugins/64bit (일반적)
  # - /usr/share/obs/obs-plugins/64bit (일부 배포/패키징)
  local so_in_obs_path
  so_in_obs_path="$(
    echo "${so_list}" | grep -E '/(usr/lib|usr/share)/.*/obs-plugins/64bit/.*\.so$' || true
  )"
  if [[ -z "${so_in_obs_path}" ]]; then
    log "[obs] 경고: .so는 존재하지만 표준 obs-plugins/64bit 경로에서 찾지 못했습니다."
    log "[obs] dpkg -L obs-backgroundremoval | grep -E '\\.so$' 출력:"
    echo "${so_list}" | while IFS= read -r line; do log " - ${line}"; done
  fi
}

obs_apt_install_validate_obs_binary_presence_or_log() {
  if command -v obs >/dev/null 2>&1; then
    return 0
  fi
  log "[obs] 주의: obs 바이너리가 PATH에 없습니다. 설치를 건너뛰었거나 환경이 깨졌을 수 있습니다."
}

obs_apt_install_post_gpu_and_wayland_tips_log() {
  log "[obs] GPU/Wayland 안내"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
    log "[obs] NVENC 사용 가능 여부는 ffmpeg/OBS 빌드 옵션에 좌우됩니다."
  fi

  if command -v lspci >/dev/null 2>&1 && lspci | grep -E 'VGA|3D' | grep -iq 'AMD'; then
    log "[obs] AMD GPU 감지: VAAPI 관련 패키지(mesa-va-drivers 등) 검토"
  fi

  log "[obs] Wayland: xdg-desktop-portal(+gnome/gtk), pipewire, wireplumber 최신 유지 권장"
  log "[obs] 화면 캡처는 'PipeWire (Wayland)' 소스 사용 권장"
}

# ─────────────────────────────────────────────────────────────
# Contract validation (near entry)
# ─────────────────────────────────────────────────────────────
obs_apt_install_contract_reject_root_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "root로 직접 실행하지 마세요. 일반 사용자로 실행하세요(내부에서 sudo를 사용합니다)."
  fi
}

obs_apt_install_contract_parse_cli_options_or_throw() {
  OBS_BGREMOVAL_INSTALL_ENABLED=1
  for arg in "$@"; do
    case "${arg}" in
      --no-bgremoval) OBS_BGREMOVAL_INSTALL_ENABLED=0 ;;
      *) err "알 수 없는 옵션: ${arg}  (허용: --no-bgremoval)" ;;
    esac
  done
}

obs_apt_install_contract_validate_os_release_or_throw() {
  [[ -r /etc/os-release ]] || err "/etc/os-release 를 읽을 수 없습니다."
  # shellcheck disable=SC1091
  . /etc/os-release

  local ubuntu_version="${VERSION_ID:-unknown}"
  if [[ "${ID:-}" != "ubuntu" ]]; then
    log "[obs] 경고: Ubuntu가 아닙니다(ID=${ID:-unknown}). Ubuntu 22.04/24.04에서 검증되었습니다."
    return 0
  fi

  case "${ubuntu_version}" in
    22.04|24.04) log "[obs] Ubuntu ${ubuntu_version} 감지" ;;
    *) log "[obs] 경고: Ubuntu ${ubuntu_version}. 22.04/24.04에서 검증되었습니다." ;;
  esac
}

obs_apt_install_contract_validate_obs_runtime_policy_or_throw() {
  if obs_apt_install_adapter_is_flatpak_obs_installed; then
    err "Flatpak OBS 감지: ${OBS_FLATPAK_APP_ID}. 정책상 미지원입니다. 제거 후 재실행하세요."
  fi
}

obs_apt_install_contract_prime_sudo_session_or_throw() {
  sudo -v >/dev/null
}

obs_apt_install_contract_require_tty_for_confirmation_or_throw() {
  if [[ ! -t 0 ]]; then
    err "재설치 확인 입력이 필요한데 TTY가 아닙니다. --yes 또는 GUI 사용자 터미널에서 다시 실행하세요."
  fi
}

# ─────────────────────────────────────────────────────────────
# Low-level adapters
# ─────────────────────────────────────────────────────────────
obs_apt_install_adapter_is_dpkg_package_installed() {
  local package_name="${1:?package_name required}"
  dpkg-query -W -f='${Status}\n' "${package_name}" 2>/dev/null | grep -q "install ok installed"
}

obs_apt_install_adapter_is_flatpak_obs_installed() {
  command -v flatpak >/dev/null 2>&1 && flatpak info "${OBS_FLATPAK_APP_ID}" >/dev/null 2>&1
}

obs_apt_install_adapter_is_assume_yes_enabled() {
  [[ "${LEGION_ASSUME_YES:-0}" -eq 1 ]]
}

obs_apt_install_adapter_ask_yes_no() {
  local prompt_message="${1:?prompt_message required}"
  local answer
  read -r -p "${prompt_message} [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

obs_apt_install_print_next_steps() {
  printf -- "---------------------------------------------\n"
  printf -- "실행: obs\n"
  if [[ "${OBS_BGREMOVAL_INSTALL_ENABLED}" -eq 1 ]]; then
    printf -- "플러그인: obs-backgroundremoval (설치 대상)\n"
  else
    printf -- "플러그인: 설치 생략(--no-bgremoval)\n"
  fi
  printf -- "---------------------------------------------\n"
}

# ─────────────────────────────────────────────────────────────
# Options / constants
# ─────────────────────────────────────────────────────────────
OBS_FLATPAK_APP_ID="com.obsproject.Studio"
OBS_APT_PPA="ppa:obsproject/obs-studio"

OBS_BGREMOVAL_PLUGIN_OWNER="${PLUGIN_OWNER:-royshil}"
OBS_BGREMOVAL_PLUGIN_REPO="${PLUGIN_REPO:-obs-backgroundremoval}"
OBS_BGREMOVAL_PLUGIN_TAG="${PLUGIN_TAG:-latest}"

obs_apt_install_main "$@"

# [ReleaseNote] breaking: Flatpak OBS 발견 시 즉시 중단(apt-only SSOT), --yes로 비대화형 재설치 허용
