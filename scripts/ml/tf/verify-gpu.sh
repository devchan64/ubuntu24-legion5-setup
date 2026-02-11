#!/usr/bin/env bash
# file: scripts/ml/verify-gpu.sh
# GPU/Container compatibility smoke test
# - Host NVIDIA driver (nvidia-smi)
# - Docker runtime
# - nvidia-smi inside CUDA base container
# - TensorFlow GPU container: Python GPU visibility check
# Policy: no fallbacks, fail-fast
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  must_cmd_or_throw docker
  command -v nvidia-smi >/dev/null 2>&1 || err "nvidia-smi not found. NVIDIA driver required."

  local cuda_image="${CUDA_IMAGE:-nvidia/cuda:12.4.1-base-ubuntu22.04}"
  local tf_image="${TF_IMAGE:-tensorflow/tensorflow:latest-gpu-jupyter}"

  log "[smoke] host NVIDIA driver"
  nvidia-smi >/dev/null 2>&1 || err "host nvidia-smi failed"

  log "[smoke] docker version"
  docker --version >/dev/null 2>&1 || err "docker not working"

  log "[smoke] pull CUDA image: ${cuda_image}"
  docker pull "${cuda_image}"

  log "[smoke] run nvidia-smi inside CUDA image"
  docker run --rm --gpus all "${cuda_image}" nvidia-smi >/dev/null \
    || err "CUDA container cannot access GPU"

  log "[smoke] pull TF image: ${tf_image}"
  docker pull "${tf_image}"

  log "[smoke] TensorFlow GPU visibility check"
  docker run --rm --gpus all "${tf_image}" python - <<'PY'
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

  log "[smoke] OK: GPU/container smoke test passed"
}

main "$@"
