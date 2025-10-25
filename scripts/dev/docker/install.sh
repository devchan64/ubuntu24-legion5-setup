#!/usr/bin/env bash
# Ubuntu 24.04 전용 Docker Engine + Buildx/Compose + (선택) NVIDIA Container Toolkit 설치
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# ─────────────────────────────────────────────────────────────
# 공통
# ─────────────────────────────────────────────────────────────
_ts() { date +'%F %T'; }
log()  { printf "[%s] %s\n" "$(_ts)" "$*"; }
err()  { printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "command not found: $1"
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."
}

require_ubuntu_2404() {
  require_cmd lsb_release
  local dist ver
  dist="$(lsb_release -is 2>/dev/null || true)"
  ver="$(lsb_release -rs 2>/dev/null || true)"
  [[ "$dist" == "Ubuntu" && "$ver" == 24.04* ]] || err "Ubuntu 24.04 환경이 아닙니다. (${dist} ${ver})"
}

# ─────────────────────────────────────────────────────────────
# 준비
# ─────────────────────────────────────────────────────────────
main() {
  require_root
  require_ubuntu_2404

  export DEBIAN_FRONTEND=noninteractive

  log "기존 docker 패키지 제거(있는 경우)"
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  log "필수 패키지 설치"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

  log "Docker 공식 GPG 키 등록"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  log "Docker APT 리포지토리 추가"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list

  log "Docker Engine 설치"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  log "Docker 데몬 활성화/시작"
  systemctl enable docker
  systemctl restart docker
  systemctl is-active --quiet docker || err "docker 서비스 활성화 실패"

  # 현재 사용자 docker 그룹 추가
  local target_user="${SUDO_USER:-$USER}"
  log "사용자 ${target_user} 를 docker 그룹에 추가"
  getent group docker >/dev/null 2>&1 || groupadd docker
  usermod -aG docker "${target_user}"

  # 간단 동작 테스트 (root로 실행)
  log "hello-world 컨테이너 실행 테스트"
  docker run --rm hello-world >/dev/null

  # ───── NVIDIA Container Toolkit (선택) ─────
  if command -v nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA 드라이버 감지됨 → NVIDIA Container Toolkit 설치"
    # 리포지토리 설정
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL "https://nvidia.github.io/libnvidia-container/stable/deb/$(dpkg --print-architecture)/" \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -y
    apt-get install -y nvidia-container-toolkit

    log "Docker 런타임에 NVIDIA 설정 적용"
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker

    log "CUDA 컨테이너에서 GPU 확인"
    docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi >/dev/null \
      || err "CUDA 컨테이너에서 GPU 접근 실패"
  else
    log "NVIDIA 드라이버가 없어 Container Toolkit 설치를 건너뜁니다. (필요 시 드라이버 설치 후 재실행)"
  fi

  log "설치 완료. 현재 쉘에서 docker 그룹 적용을 위해 다음 중 하나를 수행하세요:"
  printf -- "  1) newgrp docker\n  2) 로그아웃 후 재로그인\n"
}

main "$@"
