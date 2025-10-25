#!/usr/bin/env bash
# Ubuntu 24.04 전용 Docker Engine + Buildx/Compose 설치 (NVIDIA Toolkit 분리)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

_ts() { date +'%F %T'; }
log()  { printf "[%s] %s\n" "$(_ts)" "$*"; }
err()  { printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || err "command not found: $1"; }
require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."; }

require_ubuntu_2404() {
  [[ -r /etc/os-release ]] || err "/etc/os-release 를 찾을 수 없습니다."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || err "Ubuntu 환경이 아닙니다. (ID=${ID:-unknown})"
  [[ "${VERSION_CODENAME:-}" == "noble" ]] || err "Ubuntu 24.04(noble) 가 필요합니다. (codename=${VERSION_CODENAME:-unknown})"
  [[ "${VERSION_ID:-}" == 24.04* ]] || err "Ubuntu 24.04.x 가 필요합니다. (VERSION_ID=${VERSION_ID:-unknown})"
}

main() {
  require_root
  require_ubuntu_2404
  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  log "기존 docker 패키지 제거(있는 경우)"
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  log "필수 패키지 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg apt-transport-https

  log "Docker 공식 GPG 키 등록(멱등·비대화형)"
  install -m 0755 -d /etc/apt/keyrings
  # 기존 키가 있으면 프롬프트 없이 제거 후 재생성
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
  # 항상 동일 내용으로 교체(프롬프트/중복 방지)
  printf '%s\n' "$repo_line" > /etc/apt/sources.list.d/docker.list


  log "Docker Engine 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  log "Docker 데몬 활성화/시작"
  systemctl enable docker
  systemctl restart docker
  systemctl is-active --quiet docker || err "docker 서비스 활성화 실패"

  local target_user="${SUDO_USER:-$USER}"
  log "사용자 ${target_user} 를 docker 그룹에 추가"
  getent group docker >/dev/null 2>&1 || groupadd docker
  usermod -aG docker "${target_user}"

  log "hello-world 컨테이너 실행 테스트(pull 포함)"
  docker run --rm hello-world >/dev/null 2>&1 || err "hello-world 컨테이너 실행 실패(네트워크/레지스트리 접근 확인 필요)"

  log "Docker 설치 완료. 현재 쉘에서 docker 그룹 적용을 위해 다음 중 하나를 수행하세요:"
  printf -- "  1) newgrp docker\n  2) 로그아웃 후 재로그인\n"
}

main "$@"
