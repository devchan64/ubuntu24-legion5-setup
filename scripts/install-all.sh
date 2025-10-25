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
  all                 Run sys, dev, ml, media, security, net, ops sequentially
  help                Show this help

Global Options:
  --yes               Assume yes to prompts (non-interactive)
  --debug             Verbose logs

Examples:
  sudo bash scripts/install-all.sh sys
  sudo bash scripts/install-all.sh all --yes
  bash scripts/install-all.sh media
'

# ─────────────────────────────────────────────────────────────
# Logging (uses common.sh if provided)
# ─────────────────────────────────────────────────────────────
log "${BASH_SOURCE[0]} starting..."

# ─────────────────────────────────────────────────────────────
# Option parsing (global only)
# ─────────────────────────────────────────────────────────────
GLOBAL_YES=0
DEBUG_MODE=0

maybe_shift_flag() {
  local flag="$1"
  if [[ "${2:-}" == "$flag" ]]; then
    echo 1
  else
    echo 0
  fi
}

# Collect global flags that can appear anywhere
GLOBAL_ARGS=()
CMD_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes)   GLOBAL_YES=1 ;;
    --debug) DEBUG_MODE=1 ;;
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
shift_count=0
if [[ "${#CMD_ARGS[@]}" -gt 0 ]]; then shift_count=1; fi
# Shift away the command token
if (( shift_count == 1 )); then
  CMD_ARGS=("${CMD_ARGS[@]:1}")
fi

# Helper to exec command module
run_cmd_module() {
  local mod="$1"; shift
  local entry="${ROOT_DIR}/scripts/cmd/${mod}.sh"
  if [[ ! -x "$entry" ]]; then
    err "command module not found or not executable: $entry"
  fi
  # shellcheck disable=SC1090
  source "$entry"
  "${mod}_main" "$@"
}

case "$CMD" in
  help|-h|--help)
    echo "$USAGE_TEXT"
    exit 0
    ;;
  sys)
    run_cmd_module "sys" "${CMD_ARGS[@]}"
    ;;
  dev)
    run_cmd_module "dev" "${CMD_ARGS[@]}"
    ;;
  ml)
    run_cmd_module "ml" "${CMD_ARGS[@]}"
    ;;
  media)
    run_cmd_module "media" "${CMD_ARGS[@]}"
    ;;
  security)
    run_cmd_module "security" "${CMD_ARGS[@]}"
    ;;
  net)
    run_cmd_module "net" "${CMD_ARGS[@]}"
    ;;
  ops)
    run_cmd_module "ops" "${CMD_ARGS[@]}"
    ;;
  all)
    run_cmd_module "dev"          "${CMD_ARGS[@]}"
    run_cmd_module "sys"          "${CMD_ARGS[@]}"
    run_cmd_module "media는"      "${CMD_ARGS[@]}"
    run_cmd_module "ml"           "${CMD_ARGS[@]}"    
    run_cmd_module "net"          "${CMD_ARGS[@]}"
    run_cmd_module "ops"          "${CMD_ARGS[@]}"
    run_cmd_module "security"     "${CMD_ARGS[@]}"
    ;;
  *)
    echo "[ERROR] Unknown command: $CMD" >&2
    echo
    echo "$USAGE_TEXT"
    exit 2
    ;;
esac

log "done."
