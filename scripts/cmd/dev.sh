#!/usr/bin/env bash
set -Eeuo pipefail

dev_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  # Docker / Node / Python 등 개별 install.sh가 존재한다고 가정
  must_run "scripts/dev/docker/install.sh"
  must_run "scripts/dev/node/install.sh"
  must_run "scripts/dev/python/install.sh"

  # 선택적으로 NVIDIA toolkit
  if [[ "${LEGION_NVIDIA_TOOLKIT:-0}" == "1" ]]; then
    must_run "scripts/dev/docker/nvidia-toolkit.sh"
  fi

  log "[dev] done"
}
