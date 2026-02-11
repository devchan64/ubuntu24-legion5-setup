#!/usr/bin/env bash
# file: scripts/cmd/ml.sh
set -Eeuo pipefail
set -o errtrace

ml_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:ml}"

  resume_step "${resume_scope}" "ml:cuda:tensorrt:setup" \
    must_run_or_throw "scripts/ml/setup-cuda-tensorrt.sh"

  resume_step "${resume_scope}" "ml:tf:verify:gpu" \
    must_run_or_throw "scripts/ml/tf/verify-gpu.sh"

  log "[ml] done"
}

ml_main "$@"
