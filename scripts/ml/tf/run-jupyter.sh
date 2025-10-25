#!/usr/bin/env bash
# TensorFlow GPU Jupyter 컨테이너 실행 스크립트
# 옵션:
#   --pull-only   : 이미지 당겨오기만 수행
#   --allow-cpu   : nvidia-smi 미존재 시 CPU 모드로 실행을 명시 허용(기본: GPU 강제)
# 환경변수:
#   IMAGE            (기본: tensorflow/tensorflow:latest-gpu-jupyter)
#   CONTAINER_NAME   (기본: tf-jupyter)
#   HOST_PORT        (기본: 8888)
#   WORK_DIR         (기본: $HOME/tf-notebooks)
#   JUPYTER_TOKEN    (기본: legion)
set -Eeuo pipefail

# 공통 유틸 로드 (repo root 추적)
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

IMAGE="${IMAGE:-tensorflow/tensorflow:latest-gpu-jupyter}"
CONTAINER_NAME="${CONTAINER_NAME:-tf-jupyter}"
HOST_PORT="${HOST_PORT:-8888}"
WORK_DIR="${WORK_DIR:-$HOME/tf-notebooks}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-legion}"

require_cmd docker

# ─────────────────────────────────────────────────────────────
# 옵션 파싱
# ─────────────────────────────────────────────────────────────
PULL_ONLY=false
ALLOW_CPU=false

for a in "$@"; do
  case "$a" in
    --pull-only) PULL_ONLY=true ;;
    --allow-cpu) ALLOW_CPU=true ;;
    *) err "unknown option: $a" ;;
  esac
done

# ─────────────────────────────────────────────────────────────
# GPU 요구 정책(폴백 금지): 기본은 GPU 강제, CPU는 --allow-cpu 로만 허용
# ─────────────────────────────────────────────────────────────
GPU_OPT=""
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_OPT="--gpus all"
else
  if "${ALLOW_CPU}"; then
    GPU_OPT=""
  else
    err "NVIDIA 드라이버(nvidia-smi)가 필요합니다. CPU 모드 실행을 원하면 --allow-cpu 옵션을 명시하세요."
  fi
fi

# ─────────────────────────────────────────────────────────────
# 준비
# ─────────────────────────────────────────────────────────────
mkdir -p "${WORK_DIR}"

log "Docker image: ${IMAGE}"
docker pull "${IMAGE}"

if "${PULL_ONLY}"; then
  log "pull-only 완료"
  exit 0
fi

# 기존 컨테이너 정리
if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  log "컨테이너 존재: ${CONTAINER_NAME} → 제거 후 재생성"
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# ─────────────────────────────────────────────────────────────
# 실행
# ─────────────────────────────────────────────────────────────
log "starting Jupyter: ${IMAGE} on http://localhost:${HOST_PORT} token=${JUPYTER_TOKEN} mode=$([[ -n "${GPU_OPT}" ]] && echo GPU || echo CPU)"

docker run -d \
  --name "${CONTAINER_NAME}" \
  ${GPU_OPT} \
  -p "${HOST_PORT}:8888" \
  -v "${WORK_DIR}:/tf/notebooks" \
  -e JUPYTER_TOKEN="${JUPYTER_TOKEN}" \
  "${IMAGE}" \
  bash -lc "jupyter notebook \
    --NotebookApp.password='' \
    --NotebookApp.token=\${JUPYTER_TOKEN} \
    --ip=0.0.0.0 --no-browser \
    --NotebookApp.allow_origin='*' \
    --notebook-dir=/tf/notebooks"

# 기동 확인
sleep 2
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "^${CONTAINER_NAME}\b" >/dev/null \
  || err "컨테이너 기동 실패"

log "Jupyter ready → http://localhost:${HOST_PORT}  (token: ${JUPYTER_TOKEN})"
