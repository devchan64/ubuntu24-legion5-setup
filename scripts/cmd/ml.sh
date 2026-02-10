#!/usr/bin/env bash
set -Eeuo pipefail

ml_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:ml}"

  resume_run_step_or_throw "$RESUME_SCOPE" "ml:cuda tensorrt setup" -- must_run "scripts/ml/setup-cuda-tensorrt.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "ml:tf verify gpu" -- must_run "scripts/ml/tf/verify-gpu.sh"

  log "[ml] done"
}
