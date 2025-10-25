#!/usr/bin/env bash
set -Eeuo pipefail

ml_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  must_run "scripts/ml/setup-cuda-tensorrt.sh"
  # 필요 시 TF/PyTorch 서브 스크립트 추가
  # must_run "scripts/ml/tf/install.sh"

  log "[ml] done"
}
