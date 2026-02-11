#!/usr/bin/env bash
# file: scripts/dev/docker/install.sh
# Ubuntu 24.04 전용 Docker Engine + Buildx/Compose 설치 (NVIDIA Toolkit 분리)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  ensure_root_or_reexec_with_sudo_or_throw "$@"

  require_ubuntu_2404
  must_cmd_or_throw dpkg
  must_cmd_or_throw gpg
  must_cmd_or_throw curl
  must_cmd_or_throw systemctl

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # SideEffect: apt sources/keyrings 수정 가능
  apt_fix_vscode_repo_singleton

  log "[docker] remove legacy packages (best-effort)"
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  log "[docker] install prerequisites"
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl gnupg

  docker_configure_official_apt_repo_or_throw

  log "[docker] install engine + plugins"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  docker_enable_and_verify_services_or_throw

  docker_add_user_to_group_or_throw

  docker_verify_plugins_or_throw
  docker_smoke_test_or_throw

  log "[docker] installed. apply docker group by one of:"
  printf -- "  1) newgrp docker\n  2) logout/login\n"
}

# ─────────────────────────────────────────────────────────────
# Business: Root elevation
# Domain: Contract: Fail-Fast:
#   - root가 아니면 sudo로 자기 자신 재실행 (환경변수 최소 보존)
# SideEffect: sudo 인증 프롬프트, exec
# ─────────────────────────────────────────────────────────────
ensure_root_or_reexec_with_sudo_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  must_cmd_or_throw sudo
  log "[docker] root required → sudo auth"
  sudo -v >/dev/null || err "sudo authentication failed"

  exec sudo --preserve-env=LEGION_SETUP_ROOT,DEBIAN_FRONTEND,NEEDRESTART_MODE \
    -E bash "$0" "$@"
}

# ─────────────────────────────────────────────────────────────
# Business: Docker apt repo (SSOT)
# SideEffect: /etc/apt/keyrings, /etc/apt/sources.list.d write
# ─────────────────────────────────────────────────────────────
docker_configure_official_apt_repo_or_throw() {
  local keyring_dir="/etc/apt/keyrings"
  local gpg_path="${keyring_dir}/docker.gpg"
  local list_path="/etc/apt/sources.list.d/docker.list"

  install -d -m 0755 -o root -g root "${keyring_dir}"

  if [[ -f "${gpg_path}" ]]; then
    log "[docker] existing keyring found → recreate: ${gpg_path}"
    rm -f "${gpg_path}" || err "failed to remove existing docker.gpg: ${gpg_path}"
  fi

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor --yes --output "${gpg_path}"
  chmod 0644 "${gpg_path}"

  local codename=""
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  [[ -n "${codename}" ]] || err "failed to resolve ubuntu codename from /etc/os-release"

  local repo_line=""
  repo_line="deb [arch=$(dpkg --print-architecture) signed-by=${gpg_path}] https://download.docker.com/linux/ubuntu ${codename} stable"
  printf '%s\n' "${repo_line}" > "${list_path}"
  chmod 0644 "${list_path}"
}

# ─────────────────────────────────────────────────────────────
# Business: Services
# SideEffect: systemctl enable/restart
# ─────────────────────────────────────────────────────────────
docker_enable_and_verify_services_or_throw() {
  log "[docker] enable/restart containerd"
  systemctl enable containerd
  systemctl restart containerd
  systemctl is-active --quiet containerd || err "containerd not active"

  log "[docker] enable/restart docker"
  systemctl enable docker
  systemctl restart docker
  systemctl is-active --quiet docker || err "docker not active"
}

# ─────────────────────────────────────────────────────────────
# IO: User/group membership
# SideEffect: groupadd/usermod
# ─────────────────────────────────────────────────────────────
docker_add_user_to_group_or_throw() {
  must_cmd_or_throw getent
  must_cmd_or_throw groupadd
  must_cmd_or_throw usermod

  local target_user="${SUDO_USER:-${USER}}"
  [[ -n "${target_user}" ]] || err "failed to resolve target user (SUDO_USER/USER empty)"

  log "[docker] add user to docker group: ${target_user}"
  getent group docker >/dev/null 2>&1 || groupadd docker
  usermod -aG docker "${target_user}"
}

# ─────────────────────────────────────────────────────────────
# Business: Verification
# ─────────────────────────────────────────────────────────────
docker_verify_plugins_or_throw() {
  docker buildx version >/dev/null 2>&1 || err "docker buildx plugin not working"
  docker compose version >/dev/null 2>&1 || err "docker compose plugin not working"
}

docker_smoke_test_or_throw() {
  log "[docker] smoke test: hello-world"
  docker run --rm hello-world >/dev/null 2>&1 || err "hello-world failed (network/registry access?)"
}

main "$@"
