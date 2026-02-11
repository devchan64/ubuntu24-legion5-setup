#!/usr/bin/env bash
# file: scripts/media/video/obs-install.sh
set -Eeuo pipefail
set -o errtrace

# Domain: Media/OBS install (apt SSOT)
# Contract: Flatpak OBS detected -> throw (apt-only). Reinstall confirmation requires TTY unless --yes.
# Fail-Fast: no fallback. Mixed install state/unknown option/unsupported arch -> throw.
# SideEffect: apt repo add, packages install, GitHub API call, local .deb install

# ─────────────────────────────────────────────────────────────
# Config / Const (SSOT)
# ─────────────────────────────────────────────────────────────
OBS_FLATPAK_APP_ID="com.obsproject.Studio"
OBS_APT_PPA="ppa:obsproject/obs-studio"

OBS_BGREMOVAL_PLUGIN_OWNER_DEFAULT="royshil"
OBS_BGREMOVAL_PLUGIN_REPO_DEFAULT="obs-backgroundremoval"
OBS_BGREMOVAL_PLUGIN_TAG_DEFAULT="latest"

# CLI parsed (derived; never input except via args)
OBS_BGREMOVAL_INSTALL_ENABLED=1

obs_apt_install_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  obs_apt_install_contract_validate_entry_or_throw "$@"
  obs_apt_install_execute_or_throw
  obs_apt_install_print_next_steps
}

# ─────────────────────────────────────────────────────────────
# Top: business logic
# ─────────────────────────────────────────────────────────────
obs_apt_install_contract_validate_entry_or_throw() {
  obs_apt_install_contract_reject_root_or_throw
  obs_apt_install_contract_parse_cli_options_or_throw "$@"

  # NOTE: 레포 전체 정책이 "Ubuntu 24.04"라면 require_ubuntu_2404()로 강제하는 편이 SSOT에 맞음.
  # 기존 스크립트는 22.04/24.04 경고 허용이었는데, 여기서는 레포 철학에 맞춰 24.04로 강제.
  require_ubuntu_2404

  must_cmd_or_throw dpkg
  must_cmd_or_throw curl
  must_cmd_or_throw sudo

  obs_apt_install_contract_validate_obs_runtime_policy_or_throw
  obs_apt_install_contract_prime_sudo_session_or_throw
}

obs_apt_install_execute_or_throw() {
  local should_reinstall_obs=1
  local should_reinstall_plugin=0

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
    log "[obs] plugin: skip (disabled or user chose skip)"
  fi

  obs_apt_install_post_gpu_and_wayland_tips_log
  log "[obs] done"
}

obs_apt_install_decide_obs_reinstall_or_throw() {
  local obs_installed_apt=0

  if obs_apt_install_adapter_is_dpkg_package_installed "obs-studio"; then
    obs_installed_apt=1
  fi

  # Flatpak은 entry에서 policy로 이미 차단되지만, 실행 흐름 보호를 위해 한 번 더 assert
  if obs_apt_install_adapter_is_flatpak_obs_installed; then
    err "Flatpak OBS detected (policy violation). remove first: ${OBS_FLATPAK_APP_ID}"
  fi

  if [[ "${obs_installed_apt}" -eq 0 ]]; then
    echo 1
    return 0
  fi

  log "[obs] already installed: obs-studio (dpkg)"
  if obs_apt_install_adapter_is_assume_yes_enabled; then
    log "[obs] --yes: reinstall/update"
    echo 1
    return 0
  fi

  obs_apt_install_contract_require_tty_for_confirmation_or_throw
  if obs_apt_install_adapter_ask_yes_no "Reinstall/update OBS?"; then
    echo 1
  else
    log "[obs] user chose: skip reinstall/update"
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

  log "[obs] already installed: obs-backgroundremoval"
  if obs_apt_install_adapter_is_assume_yes_enabled; then
    log "[obs] --yes: reinstall/update plugin"
    echo 1
    return 0
  fi

  obs_apt_install_contract_require_tty_for_confirmation_or_throw
  if obs_apt_install_adapter_ask_yes_no "Reinstall/update obs-backgroundremoval plugin?"; then
    echo 1
  else
    log "[obs] user chose: skip plugin reinstall/update"
    echo 0
  fi
}

# ─────────────────────────────────────────────────────────────
# Middle: adapters / IO
# ─────────────────────────────────────────────────────────────
obs_apt_install_install_obs_via_apt_or_throw() {
  log "[obs] install prerequisites"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends software-properties-common curl ca-certificates

  log "[obs] add PPA: ${OBS_APT_PPA}"
  sudo add-apt-repository -y "${OBS_APT_PPA}"

  log "[obs] install packages"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends \
    obs-studio qtwayland5 v4l2loopback-dkms ffmpeg

  command -v obs >/dev/null 2>&1 || err "obs binary not found after install"
  log "[obs] installed: $(obs --version | head -n 1)"
}

obs_apt_install_install_bgremoval_deb_or_throw() {
  command -v obs >/dev/null 2>&1 || err "OBS not installed (apt OBS required)"

  obs_apt_install_adapter_ensure_jq_installed_or_throw

  local deb_url=""
  deb_url="$(obs_apt_install_adapter_resolve_bgremoval_deb_url_or_throw)"

  local tmp_dir=""
  tmp_dir="$(mktemp -d -p /var/tmp obsbgremoval.XXXXXX)"
  chmod 0755 "${tmp_dir}"
  trap 'rm -rf "${tmp_dir}"' RETURN

  log "[obs] download plugin: ${deb_url}"
  curl -fL "${deb_url}" -o "${tmp_dir}/obs-backgroundremoval.deb"

  local deb_file_path="${tmp_dir}/obs-backgroundremoval.deb"
  [[ -f "${deb_file_path}" ]] || err "plugin deb not found after download"

  log "[obs] install plugin deb (apt local file)"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${deb_file_path}"

  obs_apt_install_adapter_validate_bgremoval_dpkg_payload_or_throw
  log "[obs] plugin installed: obs-backgroundremoval"
}

obs_apt_install_adapter_resolve_bgremoval_deb_url_or_throw() {
  local owner="${PLUGIN_OWNER:-${OBS_BGREMOVAL_PLUGIN_OWNER_DEFAULT}}"
  local repo="${PLUGIN_REPO:-${OBS_BGREMOVAL_PLUGIN_REPO_DEFAULT}}"
  local tag="${PLUGIN_TAG:-${OBS_BGREMOVAL_PLUGIN_TAG_DEFAULT}}"

  local arch=""
  arch="$(dpkg --print-architecture)"
  [[ "${arch}" =~ ^(amd64|arm64)$ ]] || err "unsupported arch: ${arch}"

  local api_url=""
  if [[ "${tag}" == "latest" ]]; then
    api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
  else
    api_url="https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}"
  fi

  local release_json=""
  release_json="$(curl -fsSL "${api_url}")" || err "GitHub API failed: ${api_url}"

  local arch_token=""
  case "${arch}" in
    amd64) arch_token="x86_64" ;;
    arm64) arch_token="aarch64" ;;
    *) err "unsupported arch token: ${arch}" ;;
  esac

  local url=""
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

  [[ -n "${url}" && "${url}" != "null" ]] || err "plugin deb asset not found in release"
  echo "${url}"
}

obs_apt_install_adapter_ensure_jq_installed_or_throw() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi

  log "[obs] install jq"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends jq
  command -v jq >/dev/null 2>&1 || err "jq install failed"
}

obs_apt_install_adapter_validate_bgremoval_dpkg_payload_or_throw() {
  obs_apt_install_adapter_is_dpkg_package_installed "obs-backgroundremoval" \
    || err "plugin validate failed: dpkg missing obs-backgroundremoval"

  local so_list=""
  so_list="$(dpkg -L obs-backgroundremoval 2>/dev/null | grep -E '\.so$' || true)"
  [[ -n "${so_list}" ]] || err "plugin validate failed: no .so in payload"

  local so_in_obs_path=""
  so_in_obs_path="$(echo "${so_list}" | grep -E '/(usr/lib|usr/share)/.*/obs-plugins/64bit/.*\.so$' || true)"
  if [[ -z "${so_in_obs_path}" ]]; then
    log "[obs] warning: .so exists but not found under obs-plugins/64bit path"
    echo "${so_list}" | while IFS= read -r line; do log " - ${line}"; done
  fi
}

obs_apt_install_validate_obs_binary_presence_or_log() {
  if command -v obs >/dev/null 2>&1; then
    return 0
  fi
  log "[obs] warning: obs not in PATH (skipped install or broken env)"
}

obs_apt_install_post_gpu_and_wayland_tips_log() {
  log "[obs] GPU/Wayland notes"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
    log "[obs] NVENC availability depends on ffmpeg/OBS build options"
  fi

  if command -v lspci >/dev/null 2>&1 && lspci | grep -E 'VGA|3D' | grep -iq 'AMD'; then
    log "[obs] AMD GPU detected: consider VAAPI packages (mesa-va-drivers, etc.)"
  fi

  log "[obs] Wayland: keep xdg-desktop-portal(+gnome/gtk), pipewire, wireplumber up to date"
  log "[obs] screen capture: prefer 'PipeWire (Wayland)' source"
}

obs_apt_install_print_next_steps() {
  printf -- "---------------------------------------------\n"
  printf -- "run: obs\n"
  if [[ "${OBS_BGREMOVAL_INSTALL_ENABLED}" -eq 1 ]]; then
    printf -- "plugin: obs-backgroundremoval (enabled)\n"
  else
    printf -- "plugin: skipped (--no-bgremoval)\n"
  fi
  printf -- "---------------------------------------------\n"
}

# ─────────────────────────────────────────────────────────────
# Contract validation (near entry)
# ─────────────────────────────────────────────────────────────
obs_apt_install_contract_reject_root_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "do not run as root. run as a normal user (script uses sudo internally)."
  fi
}

obs_apt_install_contract_parse_cli_options_or_throw() {
  OBS_BGREMOVAL_INSTALL_ENABLED=1
  for arg in "$@"; do
    case "${arg}" in
      --no-bgremoval) OBS_BGREMOVAL_INSTALL_ENABLED=0 ;;
      *) err "unknown option: ${arg} (allowed: --no-bgremoval)" ;;
    esac
  done
}

obs_apt_install_contract_validate_obs_runtime_policy_or_throw() {
  if obs_apt_install_adapter_is_flatpak_obs_installed; then
    err "Flatpak OBS detected: ${OBS_FLATPAK_APP_ID}. policy: apt-only. remove and rerun."
  fi
}

obs_apt_install_contract_prime_sudo_session_or_throw() {
  sudo -v >/dev/null
}

obs_apt_install_contract_require_tty_for_confirmation_or_throw() {
  if [[ ! -t 0 ]]; then
    err "confirmation requires TTY. rerun with --yes or run from an interactive terminal"
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
  local answer=""
  read -r -p "${prompt_message} [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

obs_apt_install_main "$@"

# [ReleaseNote] breaking: repo-root self-resolve → LEGION_SETUP_ROOT SSOT, Ubuntu 24.04 contract enforced
