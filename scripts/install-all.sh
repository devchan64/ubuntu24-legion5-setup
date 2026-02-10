#!/usr/bin/env bash
set -Eeuo pipefail

# ─────────────────────────────────────────────────────────────
# Project root resolve
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
export LEGION_SETUP_ROOT="${LEGION_SETUP_ROOT:-$ROOT_DIR}"

# ─────────────────────────────────────────────────────────────
# Load common utils
# ─────────────────────────────────────────────────────────────
COMMON="${ROOT_DIR}/lib/common.sh"
if [[ ! -r "$COMMON" ]]; then
  echo "[FATAL] lib/common.sh not found at $COMMON" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "$COMMON"

USAGE_TEXT=$'Usage:
  install-all.sh <command> [options]

Commands:
  dev                 Developer toolchain (docker, node, python, etc.)
  sys                 System bootstrap (Xorg ensure, GNOME Nord, Legion HDMI)
  ml                  ML stack (CUDA/TensorRT, etc.)
  media               OBS / video tooling
  security            Security toolchain
  net                 Networking tools
  ops                 Ops / monitors
  all                 Run dev, sys, media, ml, net, ops, security sequentially
  help                Show this help

Global Options:
  --yes               Assume yes to prompts (non-interactive)
  --debug             Verbose logs
  --reset             Reset resume state for the selected command

Examples:
  bash scripts/install-all.sh sys
  bash scripts/install-all.sh all --yes
  bash scripts/install-all.sh all --reset
  bash scripts/install-all.sh media
'

log "${BASH_SOURCE[0]} starting..."

# ─────────────────────────────────────────────────────────────
# Option parsing (global only)
# ─────────────────────────────────────────────────────────────
GLOBAL_YES=0
DEBUG_MODE=0
RESET_RESUME_STATE=0

# Collect global flags that can appear anywhere
CMD_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes)   GLOBAL_YES=1 ;;
    --debug) DEBUG_MODE=1 ;;
    --reset) RESET_RESUME_STATE=1 ;;
    *)       CMD_ARGS+=("$arg") ;;
  esac
done

if (( DEBUG_MODE == 1 )); then
  export LEGION_DEBUG=1
  set -x
fi

export LEGION_ASSUME_YES="$GLOBAL_YES"

# ─────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────
CMD="${CMD_ARGS[0]:-help}"
if [[ "${#CMD_ARGS[@]}" -gt 0 ]]; then
  CMD_ARGS=("${CMD_ARGS[@]:1}")
fi

reset_resume_state_for_command_or_throw() {
  local command_name="${1:-}"
  [[ -n "${command_name}" ]] || err "command name required"

  case "$command_name" in
    dev|sys|ml|media|security|net|ops)
      resume_reset_scope_state_or_throw "cmd:${command_name}"
      ;;
    all)
      resume_reset_scope_state_or_throw "cmd:dev"
      resume_reset_scope_state_or_throw "cmd:sys"
      resume_reset_scope_state_or_throw "cmd:media"
      resume_reset_scope_state_or_throw "cmd:ml"
      resume_reset_scope_state_or_throw "cmd:net"
      resume_reset_scope_state_or_throw "cmd:ops"
      resume_reset_scope_state_or_throw "cmd:security"
      ;;
    help|-h|--help)
      :
      ;;
    *)
      err "unknown command for reset: $command_name"
      ;;
  esac
}

# Helper to exec command module
run_cmd_module_or_throw() {
  local mod="${1:-}"; shift || true
  [[ -n "${mod}" ]] || err "module name required"

  local entry="${ROOT_DIR}/scripts/cmd/${mod}.sh"
  [[ -r "$entry" ]] || err "command module missing: $entry"

  # shellcheck disable=SC1090
  source "$entry"

  export RESUME_SCOPE_KEY="cmd:${mod}"
  "${mod}_main" "$@"
}

if (( RESET_RESUME_STATE == 1 )); then
  reset_resume_state_for_command_or_throw "$CMD"
fi

case "$CMD" in
  help|-h|--help)
    echo "$USAGE_TEXT"
    exit 0
    ;;
  sys)
    run_cmd_module_or_throw "sys" "${CMD_ARGS[@]}"
    ;;
  dev)
    run_cmd_module_or_throw "dev" "${CMD_ARGS[@]}"
    ;;
  ml)
    run_cmd_module_or_throw "ml" "${CMD_ARGS[@]}"
    ;;
  media)
    run_cmd_module_or_throw "media" "${CMD_ARGS[@]}"
    ;;
  security)
    run_cmd_module_or_throw "security" "${CMD_ARGS[@]}"
    ;;
  net)
    run_cmd_module_or_throw "net" "${CMD_ARGS[@]}"
    ;;
  ops)
    run_cmd_module_or_throw "ops" "${CMD_ARGS[@]}"
    ;;
  all)
    run_cmd_module_or_throw "dev"      "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "sys"      "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "net"      "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "ops"      "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "security" "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "media"    "${CMD_ARGS[@]}"
    run_cmd_module_or_throw "ml"       "${CMD_ARGS[@]}"
    ;;
  *)
    echo "[ERROR] Unknown command: $CMD" >&2
    echo
    echo "$USAGE_TEXT"
    exit 2
    ;;
esac

log "done."
