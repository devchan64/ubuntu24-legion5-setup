#!/usr/bin/env bash
# file: lib/common.sh
# Common utilities for ubuntu24-legion5-setup
# 원칙: 폴백 없음, 에러 즉시 종료
set -Eeuo pipefail
set -o errtrace

# ─────────────────────────────────────────────────────────────
# Business: logging / fail-fast
# ─────────────────────────────────────────────────────────────
ts() { date +"%Y-%m-%dT%H:%M:%S%z"; }

log()  { echo "[INFO ][$(ts)] $*"; }
warn() { echo "[WARN ][$(ts)] $*" >&2; }
err()  { echo "[ERROR][$(ts)] $*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Business: Repo root + state directory (SSOT)
# SideEffect: mkdir -p
# ─────────────────────────────────────────────────────────────
resolve_repo_root_or_throw() {
  if [[ -n "${LEGION_SETUP_ROOT:-}" ]]; then
    [[ -d "${LEGION_SETUP_ROOT}" ]] || err "LEGION_SETUP_ROOT not a directory: ${LEGION_SETUP_ROOT}"
    (cd -- "${LEGION_SETUP_ROOT}" >/dev/null 2>&1 && pwd -P) || err "failed to resolve LEGION_SETUP_ROOT"
    return 0
  fi

  (cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P) \
    || err "failed to resolve repo root from BASH_SOURCE"
}

init_project_state_dir_or_throw() {
  local xdg_state_home="${XDG_STATE_HOME:-${HOME}/.local/state}"
  [[ -n "${xdg_state_home}" ]] || err "XDG_STATE_HOME resolved empty"
  PROJECT_STATE_DIR="${xdg_state_home}/ubuntu24-legion5-setup"
  mkdir -p "${PROJECT_STATE_DIR}"
}

REPO_ROOT="$(resolve_repo_root_or_throw)"
PROJECT_STATE_DIR="" # set by init_project_state_dir_or_throw
init_project_state_dir_or_throw

# ─────────────────────────────────────────────────────────────
# Business: Reboot barrier (SSOT)
# Domain: Contract: Fail-Fast: SideEffect:
#   - 재부팅이 필요한 step은 require_reboot_or_throw(reason) 호출로 barrier를 세우고 즉시 실패한다.
#   - 다음 실행에서 boot_id 변경이 감지되면 barrier를 자동 해제한다.
# SideEffect: barrier file read/write/remove
# ─────────────────────────────────────────────────────────────
REBOOT_REQUIRED_FILE="${PROJECT_STATE_DIR}/reboot.required"

get_linux_boot_id_or_throw() {
  [[ -r /proc/sys/kernel/random/boot_id ]] || err "boot_id not readable: /proc/sys/kernel/random/boot_id"
  cat /proc/sys/kernel/random/boot_id
}

clear_reboot_barrier_if_rebooted() {
  [[ -f "${REBOOT_REQUIRED_FILE}" ]] || return 0

  local prev_boot_id=""
  prev_boot_id="$(grep -E '^boot_id=' "${REBOOT_REQUIRED_FILE}" | head -n1 | cut -d'=' -f2- || true)"
  local cur_boot_id=""
  cur_boot_id="$(get_linux_boot_id_or_throw)"

  # Contract: boot_id가 바뀌면 재부팅이 수행된 것으로 간주하고 barrier를 해제한다.
  if [[ -n "${prev_boot_id}" && "${cur_boot_id}" != "${prev_boot_id}" ]]; then
    log "[reboot] boot_id changed → clear reboot barrier"
    rm -f "${REBOOT_REQUIRED_FILE}"
  fi
}

assert_no_reboot_barrier_or_throw() {
  [[ -f "${REBOOT_REQUIRED_FILE}" ]] || return 0
  local reason=""
  reason="$(grep -E '^reason=' "${REBOOT_REQUIRED_FILE}" | head -n1 | cut -d'=' -f2- || true)"
  err "[reboot] pending reboot barrier detected. reboot required. reason=${reason:-unknown}"
}

require_reboot_or_throw() {
  local reason="${1:-unknown}"

  # SideEffect: barrier file write
  {
    echo "created_at=$(ts)"
    echo "boot_id=$(get_linux_boot_id_or_throw)"
    echo "reason=${reason}"
  } > "${REBOOT_REQUIRED_FILE}"

  err "[reboot] reboot required. reason=${reason}"
}

# ─────────────────────────────────────────────────────────────
# Business: Resume state (SSOT)
# Domain: Contract: Fail-Fast: SideEffect:
#   - resume key는 scope(커맨드) 단위로 관리한다.
#   - 완료 상태는 PROJECT_STATE_DIR 아래 파일로만 기록한다.
#   - 동의는 저장하지 않는다.
# SideEffect: resume file read/write/remove
# ─────────────────────────────────────────────────────────────
resume_file_for_scope_or_throw() {
  local scope="${1:?scope required}"
  echo "${PROJECT_STATE_DIR}/resume.${scope}.done"
}

resume_reset_scope() {
  local scope="${1:?scope required}"
  local resume_file=""
  resume_file="$(resume_file_for_scope_or_throw "${scope}")"
  rm -f "${resume_file}"
  log "[resume] reset: scope=${scope}"
}

resume_has_step() {
  local scope="${1:?scope required}"
  local step="${2:?step required}"
  local resume_file=""
  resume_file="$(resume_file_for_scope_or_throw "${scope}")"
  [[ -f "${resume_file}" ]] || return 1
  grep -qxF "${step}" "${resume_file}"
}

resume_mark_step_done_or_throw() {
  local scope="${1:?scope required}"
  local step="${2:?step required}"
  local resume_file=""
  resume_file="$(resume_file_for_scope_or_throw "${scope}")"

  touch "${resume_file}"
  if ! grep -qxF "${step}" "${resume_file}"; then
    echo "${step}" >> "${resume_file}"
  fi
}

resume_step() {
  local scope="${1:?scope required}"
  local step="${2:?step required}"
  shift 2 || err "resume_step requires: scope step -- cmd..."

  # Contract: require "--" delimiter (CONTEXT.md)
  if [[ "${1:-}" != "--" ]]; then
    err "[resume] Contract violation: missing '--' delimiter"
  fi
  shift

  if resume_has_step "${scope}" "${step}"; then
    log "[resume] skip: scope=${scope} step=${step}"
    return 0
  fi

  log "[resume] run : scope=${scope} step=${step}"
  "$@"
  resume_mark_step_done_or_throw "${scope}" "${step}"
}

# ─────────────────────────────────────────────────────────────
# IO/Adapter: Prompt helpers
# Domain: Contract: Fail-Fast:
# ─────────────────────────────────────────────────────────────
assume_yes() {
  [[ "${LEGION_ASSUME_YES:-0}" -eq 1 ]]
}

confirm_or_throw() {
  local msg="${1:?msg required}"
  if assume_yes; then
    log "[prompt] --yes: auto-accept: ${msg}"
    return 0
  fi

  local ans=""
  read -r -p "${msg} [y/N] " ans
  case "${ans}" in
    y|Y) return 0 ;;
    *) err "user declined: ${msg}" ;;
  esac
}

# ─────────────────────────────────────────────────────────────
# IO/Adapter: Command helpers
# Domain: Contract: Fail-Fast:
# ─────────────────────────────────────────────────────────────
must_cmd_or_throw() {
  local cmd="${1:?cmd required}"
  command -v "${cmd}" >/dev/null 2>&1 || err "required command not found: ${cmd}"
}

must_run_or_throw() {
  local rel="${1:?script required}"
  shift || true
  local script="${REPO_ROOT}/${rel}"

  [[ -x "${script}" ]] || err "script not executable: ${script}"
  log "run: ${rel} $*"
  bash "${script}" "$@"
}
