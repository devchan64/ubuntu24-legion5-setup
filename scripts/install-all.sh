#!/usr/bin/env bash
# file: scripts/install-all.sh
set -Eeuo pipefail
set -o errtrace

# ─────────────────────────────────────────────────────────────
# Business: Root resolve (SSOT)
# ─────────────────────────────────────────────────────────────
resolve_repo_root_or_throw() {
  local script_dir=""
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)" \
    || { echo "[FATAL] failed to resolve script dir" >&2; exit 2; }

  (cd -- "${script_dir}/.." >/dev/null 2>&1 && pwd -P) \
    || { echo "[FATAL] failed to resolve repo root" >&2; exit 2; }
}

ROOT_DIR="$(resolve_repo_root_or_throw)"
export LEGION_SETUP_ROOT="${LEGION_SETUP_ROOT:-${ROOT_DIR}}"

# ─────────────────────────────────────────────────────────────
# Business: Load common utils (Contract)
# ─────────────────────────────────────────────────────────────
COMMON="${ROOT_DIR}/lib/common.sh"
if [[ ! -r "${COMMON}" ]]; then
  echo "[FATAL] lib/common.sh not found at ${COMMON}" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "${COMMON}"

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
  all                 Run dev, sys, net, ops, security, media, ml sequentially
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
# Business: Reboot barrier (SSOT)
# ─────────────────────────────────────────────────────────────
# Domain: Contract: Fail-Fast:
#   - reboot.required가 남아있으면 즉시 실패한다.
#   - boot_id 변경이 감지되면 barrier를 자동 해제한다.
clear_reboot_barrier_if_rebooted
assert_no_reboot_barrier_or_throw

# ─────────────────────────────────────────────────────────────
# IO/Adapter: Global option parsing (flags can appear anywhere)
# ─────────────────────────────────────────────────────────────
GLOBAL_YES=0
DEBUG_MODE=0
RESET_RESUME_STATE=0

CMD_ARGS=()
for arg in "$@"; do
  case "${arg}" in
    --yes)   GLOBAL_YES=1 ;;
    --debug) DEBUG_MODE=1 ;;
    --reset) RESET_RESUME_STATE=1 ;;
    *)       CMD_ARGS+=("${arg}") ;;
  esac
done

export LEGION_ASSUME_YES="${GLOBAL_YES}"

if (( DEBUG_MODE == 1 )); then
  export LEGION_DEBUG=1
  set -x
fi

# ─────────────────────────────────────────────────────────────
# Business: Dispatch (bounded contexts)
# ─────────────────────────────────────────────────────────────
CMD="${CMD_ARGS[0]:-help}"
if [[ "${#CMD_ARGS[@]}" -gt 0 ]]; then
  CMD_ARGS=("${CMD_ARGS[@]:1}")
fi

dispatch_single_cmd_or_throw() {
  local cmd="${1:?cmd required}"
  shift || true

  if (( RESET_RESUME_STATE == 1 )); then
    resume_reset_scope "cmd:${cmd}"
  fi

  must_run_or_throw "scripts/cmd/${cmd}.sh" "$@"
}

dispatch_all_or_throw() {
  if (( RESET_RESUME_STATE == 1 )); then
    resume_reset_scope "cmd:dev"
    resume_reset_scope "cmd:sys"
    resume_reset_scope "cmd:net"
    resume_reset_scope "cmd:ops"
    resume_reset_scope "cmd:security"
    resume_reset_scope "cmd:media"
    resume_reset_scope "cmd:ml"
  fi

  must_run_or_throw "scripts/cmd/dev.sh" "$@"
  must_run_or_throw "scripts/cmd/sys.sh" "$@"
  must_run_or_throw "scripts/cmd/net.sh" "$@"
  must_run_or_throw "scripts/cmd/ops.sh" "$@"
  must_run_or_throw "scripts/cmd/security.sh" "$@"
  must_run_or_throw "scripts/cmd/media.sh" "$@"
  must_run_or_throw "scripts/cmd/ml.sh" "$@"
}

case "${CMD}" in
  help|-h|--help)
    echo "${USAGE_TEXT}"
    exit 0
    ;;
  dev|sys|ml|media|security|net|ops)
    dispatch_single_cmd_or_throw "${CMD}" "${CMD_ARGS[@]}"
    ;;
  all)
    dispatch_all_or_throw "${CMD_ARGS[@]}"
    ;;
  *)
    echo "${USAGE_TEXT}" >&2
    err "unknown command: ${CMD}"
    ;;
esac
