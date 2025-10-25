#!/usr/bin/env bash
set -Eeuo pipefail

media-video_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  must_run "scripts/media/video/obs-install.sh"
  log "[media-video] done"
}
