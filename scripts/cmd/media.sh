#!/usr/bin/env bash
# file: scripts/cmd/media.sh
set -Eeuo pipefail
set -o errtrace

MEDIA_SCRIPT_REL_AI_VIRTUAL_CAM_INSTALL="scripts/media/camera/install-ai-virtual-cam.sh"

MEDIA_STEPKEY_AI_VIRTUAL_CAM_INSTALL="media:camera:ai-virtual-cam:install"

media_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  local resume_scope="${RESUME_SCOPE_KEY:-cmd:media}"

  resume_step "${resume_scope}" "${MEDIA_STEPKEY_AI_VIRTUAL_CAM_INSTALL}" \
    -- \
    must_run_or_throw "${MEDIA_SCRIPT_REL_AI_VIRTUAL_CAM_INSTALL}"

  log "[media] done"
}

media_main "$@"
