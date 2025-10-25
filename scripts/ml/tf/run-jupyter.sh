#!/usr/bin/env bash
# TensorFlow GPU Jupyter 컨테이너 실행 스크립트
# --pull-only 옵션 지원 (install-all.sh에서 사전 당겨오기용)
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd -P)/lib/common.sh"

IMAGE="${IMAGE:-tensorflow/tensorflow:latest-gpu-jupyter}"
CONTAINER_NAME="${CONTAINER_NAME:-tf-jupyter}"
HOST_PORT="${HOST_PORT:-8888}"
WORK_DIR="${WORK_DIR:-$HOME/tf-notebooks}"

require_cmd docker
command -v nvidia-smi >/dev/null 2>&1 || err "NVIDIA 드라이버(nvidia-smi)가 필요합니다."

pull_only=false
for a in "$@"; do
  case "$a" in
    --pull-only) pull_only=true ;;
    *) err "unknown option: $a" ;;
  esac
done

mkdir -p "$WORK_DIR"

log "Docker image: ${IMAGE}"
docker pull "${IMAGE}"

if $pull_only; then
  log "pull-only 완료"
  exit 0
fi

# 기존 컨테이너 정리
if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  log "컨테이너 존재: ${CONTAINER_NAME} → 제거 후 재생성"
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# GPU 런
docker run -d \
  --gpus all \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:8888" \
  -v "${WORK_DIR}:/tf/notebooks" \
  -e JUPYTER_TOKEN=legion \
  "${IMAGE}" \
  bash -lc "jupyter notebook --NotebookApp.password='' --NotebookApp.token=\${JUPYTER_TOKEN} --ip=0.0.0.0 --no-browser --NotebookApp.allow_origin='*' --notebook-dir=/tf/notebooks"

# 기동 확인
sleep 2
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | (grep -E "^${CONTAINER_NAME}\b" || err "컨테이너 기동 실패")

log "Jupyter ready → http://localhost:${HOST_PORT}  (token: legion)"
