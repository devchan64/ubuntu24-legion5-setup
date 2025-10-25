#!/usr/bin/env bash
# Ubuntu 24.04 전용 Docker Engine + Buildx/Compose 설치 (NVIDIA Toolkit 분리)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# 공용 유틸 재사용 (ts, log, err, require_cmd, require_ubuntu_2404 등)
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

# 루트가 아니면 sudo로 자기 자신을 재실행 (패스워드 프롬프트 유도)
ensure_root_or_reexec_with_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    require_cmd sudo
    log "root 권한이 필요합니다. sudo 인증을 진행합니다."
    # sudo 인증(프롬프트 표시), 실패 시 즉시 종료
    sudo -v || err "sudo 인증 실패"
    # 필요한 환경변수만 보존하여 자기 자신 재실행
    exec sudo --preserve-env=LEGION_SETUP_ROOT,DEBIAN_FRONTEND,NEEDRESTART_MODE \
      -E bash "$0" "$@"
  fi
}

main() {
  ensure_root_or_reexec_with_sudo "$@"

  require_ubuntu_2404
  require_cmd dpkg
  require_cmd gpg
  require_cmd curl
  require_cmd systemctl
  require_cmd wget

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # APT 충돌 선제 정리 (VSCode repo Signed-By 불일치 방지)
  apt_fix_vscode_repo_singleton

  log "기존 docker 패키지 제거(있는 경우)"
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  log "필수 패키지 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl gnupg

  log "Docker 공식 GPG 키 등록(멱등·비대화형)"
  install -d -m 0755 -o root -g root /etc/apt/keyrings
  if [[ -f /etc/apt/keyrings/docker.gpg ]]; then
    log "기존 /etc/apt/keyrings/docker.gpg 발견 → 삭제 후 재생성"
    rm -f /etc/apt/keyrings/docker.gpg || err "기존 docker.gpg 삭제 실패"
  fi
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor --yes --output /etc/apt/keyrings/docker.gpg
  chmod 0644 /etc/apt/keyrings/docker.gpg

  log "Docker APT 리포지토리 추가(멱등·비대화형)"
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  repo_line="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable"
  printf '%s\n' "$repo_line" > /etc/apt/sources.list.d/docker.list
  chmod 0644 /etc/apt/sources.list.d/docker.list

  log "Docker Engine 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  log "containerd/dockerd 활성화/시작"
  systemctl enable containerd
  systemctl restart containerd
  systemctl is-active --quiet containerd || err "containerd 서비스 활성화 실패"

  systemctl enable docker
  systemctl restart docker
  systemctl is-active --quiet docker || err "docker 서비스 활성화 실패"

  local target_user="${SUDO_USER:-$USER}"
  log "사용자 ${target_user} 를 docker 그룹에 추가"
  getent group docker >/dev/null 2>&1 || groupadd docker
  usermod -aG docker "${target_user}"

  log "Buildx/Compose 플러그인 가용성 확인"
  docker buildx version >/dev/null 2>&1 || err "docker buildx 플러그인이 동작하지 않습니다."
  docker compose version >/dev/null 2>&1 || err "docker compose 플러그인이 동작하지 않습니다."

  log "hello-world 컨테이너 실행 테스트(pull 포함)"
  docker run --rm hello-world >/dev/null 2>&1 || err "hello-world 컨테이너 실행 실패(네트워크/레지스트리 접근 확인 필요)"

  log "Docker 설치 완료. 현재 쉘에서 docker 그룹 적용을 위해 다음 중 하나를 수행하세요:"
  printf -- "  1) newgrp docker\n  2) 로그아웃 후 재로그인\n"
}

main "$@"
