#!/usr/bin/env bash
set -Eeuo pipefail

media_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  local RESUME_SCOPE="${RESUME_SCOPE_KEY:-cmd:media}"

  resume_run_step_or_throw "$RESUME_SCOPE" "media:obs install" -- must_run "scripts/media/video/obs-install.sh"
  resume_run_step_or_throw "$RESUME_SCOPE" "media:virtual audio install" -- must_run "scripts/media/audio/install-virtual-audio.sh"

  log "[media] done"
}
