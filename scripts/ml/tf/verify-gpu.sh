#!/usr/bin/env bash
# GPU/컨테이너 호환 스모크 테스트
# - NVIDIA 드라이버 (nvidia-smi)
# - Docker 런타임
# - CUDA 베이스 컨테이너에서 nvidia-smi
# - TensorFlow GPU 컨테이너에서 Python GPU 가용성 체크
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_cmd docker
command -v nvidia-smi >/dev/null 2>&1 || err "nvidia-smi not found. NVIDIA 드라이버가 필요합니다."

CUDA_IMAGE="${CUDA_IMAGE:-nvidia/cuda:12.4.1-base-ubuntu22.04}"
TF_IMAGE="${TF_IMAGE:-tensorflow/tensorflow:latest-gpu-jupyter}"

log "⛏  Host NVIDIA driver:"
nvidia-smi || err "nvidia-smi failed"

log "⛏  Docker version:"
docker --version || err "docker not working"

log "🐳 Pull CUDA image: ${CUDA_IMAGE}"
docker pull "${CUDA_IMAGE}"

log "▶  Run nvidia-smi inside CUDA image"
docker run --rm --gpus all "${CUDA_IMAGE}" nvidia-smi >/dev/null \
  || err "CUDA container failed to access GPU"

log "🐳 Pull TF image: ${TF_IMAGE}"
docker pull "${TF_IMAGE}"

log "▶  TensorFlow GPU availability check"
docker run --rm --gpus all "${TF_IMAGE}" python - <<'PY'
import sys
try:
    import tensorflow as tf
    gpus = tf.config.list_physical_devices("GPU")
    if not gpus:
        print("[ERROR] No GPU visible to TensorFlow", file=sys.stderr)
        sys.exit(2)
    print("[OK] GPUs:", [d.name for d in gpus])
    sys.exit(0)
except Exception as e:
    print("[ERROR] TF import or check failed:", e, file=sys.stderr)
    sys.exit(3)
PY

log "[OK] GPU/Container smoke test passed."
