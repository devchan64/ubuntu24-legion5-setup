#!/usr/bin/env bash
# NVIDIA Container Toolkit for Docker (Ubuntu 24.04)
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
  require_cmd docker
  require_cmd nvidia-smi

  export DEBIAN_FRONTEND=noninteractive

  log "NVIDIA Container Toolkit APT 리포지토리 등록(최신 공식)"
  rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list || true

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  log "패키지 설치"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    nvidia-container-toolkit nvidia-container-toolkit-base \
    libnvidia-container-tools libnvidia-container1

  require_cmd nvidia-ctk

  log "Docker 런타임 구성"
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker

  log "CUDA 컨테이너에서 GPU 확인(ubuntu24.04 이미지)"
  docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi >/dev/null \
    || err "CUDA 컨테이너에서 GPU 접근 실패"

  log "NVIDIA Container Toolkit 설치 완료"
}

main "$@"
