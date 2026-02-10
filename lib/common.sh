#!/usr/bin/env bash
# Common utilities for ubuntu24-legion5-setup
# 원칙: 폴백 없음, 에러 즉시 종료
set -Eeuo pipefail

# ─────────────────────────────────────────────────────────────
# Basic logging
# ─────────────────────────────────────────────────────────────
ts() { date +"%Y-%m-%dT%H:%M:%S%z"; }

log()   { echo "[INFO ][$(ts)] $*"; }
warn()  { echo "[WARN ][$(ts)] $*" >&2; }
err()   { echo "[ERROR][$(ts)] $*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────
# Env & path
# ─────────────────────────────────────────────────────────────
# REPO_ROOT: 환경변수 우선(강제), 없으면 자기 파일 기준
if [[ -n "${LEGION_SETUP_ROOT:-}" ]]; then
  [[ -d "${LEGION_SETUP_ROOT}" ]] || err "LEGION_SETUP_ROOT not a directory: ${LEGION_SETUP_ROOT}"
  REPO_ROOT="$(cd -- "${LEGION_SETUP_ROOT}" >/dev/null 2>&1 && pwd -P)"
else
  REPO_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
    pwd -P
  )"
fi

: "${XDG_STATE_HOME:="${HOME}/.local/state"}"
: "${XDG_CONFIG_HOME:="${HOME}/.config"}"
PROJECT_STATE_DIR="${XDG_STATE_HOME}/ubuntu24-legion5-setup"
mkdir -p "${PROJECT_STATE_DIR}"

# ─────────────────────────────────────────────────────────────
# Resume state (fail-fast + rerun-continue)
# ─────────────────────────────────────────────────────────────
# Domain: 실패 시 즉시 종료하되, 재실행하면 '완료된 단계'는 스킵하고 다음 단계부터 이어서 진행
# Contract:
#   - 완료 상태는 PROJECT_STATE_DIR 아래 파일로만 기록한다.
#   - step key는 변경하면 breaking (기존 resume 파일과 호환 안 함).

resume_scope_key_or_throw() {
  local raw="${1:-}"
  [[ -n "${raw}" ]] || err "resume scope key is required"
  # 파일명 안전 문자만 허용 (Fail-Fast)
  if [[ ! "${raw}" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
    err "invalid resume scope key: '${raw}' (allowed: [a-zA-Z0-9._:-])"
  fi
  echo "${raw}"
}

resume_state_file_path_or_throw() {
  local scope; scope="$(resume_scope_key_or_throw "${1:-}")" || exit 1
  echo "${PROJECT_STATE_DIR}/resume.${scope}.done"
}

resume_reset_scope_state_or_throw() {
  local scope; scope="$(resume_scope_key_or_throw "${1:-}")" || exit 1
  local f; f="$(resume_state_file_path_or_throw "$scope")" || exit 1
  rm -f "$f"
  log "[resume] reset: scope=$scope"
}

resume_step_done_or_throw() {
  local scope; scope="$(resume_scope_key_or_throw "${1:-}")" || exit 1
  local step_key="${2:-}"
  [[ -n "${step_key}" ]] || err "resume step key is required"

  local f; f="$(resume_state_file_path_or_throw "$scope")" || exit 1
  touch "$f" || err "cannot touch resume file: $f"

  # 중복 append 방지
  if grep -Fqx "$step_key" "$f" 2>/dev/null; then
    return 0
  fi

  printf '%s\n' "$step_key" >> "$f" || err "cannot write resume file: $f"
}

resume_step_already_done_or_throw() {
  local scope; scope="$(resume_scope_key_or_throw "${1:-}")" || exit 1
  local step_key="${2:-}"
  [[ -n "${step_key}" ]] || err "resume step key is required"

  local f; f="$(resume_state_file_path_or_throw "$scope")" || exit 1
  [[ -f "$f" ]] || return 1
  grep -Fqx "$step_key" "$f" 2>/dev/null
}

resume_run_step_or_throw() {
  # Usage: resume_run_step_or_throw <scope> <stepKey> -- <cmd...>
  local scope="${1:-}" step_key="${2:-}"
  shift 2 || true

  [[ -n "${scope}" ]] || err "resume scope is required"
  [[ -n "${step_key}" ]] || err "resume step key is required"
  [[ "${1:-}" == "--" ]] || err "resume_run_step_or_throw requires '--' before command"
  shift || true
  [[ "$#" -ge 1 ]] || err "resume_run_step_or_throw requires a command"

  if resume_step_already_done_or_throw "$scope" "$step_key"; then
    log "[resume] skip: scope=$scope step=$step_key"
    return 0
  fi

  log "[resume] run : scope=$scope step=$step_key"
  "$@"
  resume_step_done_or_throw "$scope" "$step_key"
  log "[resume] done: scope=$scope step=$step_key"
}

# ─────────────────────────────────────────────────────────────
# Preconditions
# ─────────────────────────────────────────────────────────────
must_run() {
  local rel="$1"; shift || true
  local ROOT="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  local path="${ROOT}/${rel}"
  [[ -x "$path" || -f "$path" ]] || err "script not found: $rel"
  log "run: $rel $*"
  if [[ "$path" == *.sh ]]; then
    bash "$path" "$@"
  elif [[ "$path" == *.py ]]; then
    python3 "$path" "$@"
  else
    bash "$path" "$@"
  fi
}

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || err "command not found: $c"
}

# 루트가 아니면 sudo로 자기 자신을 재실행 (패스워드 프롬프트 유도)
ensure_root_or_reexec_with_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    require_cmd sudo
    log "root 권한이 필요합니다. sudo 인증을 진행합니다."
    sudo -v || err "sudo 인증 실패"
    exec sudo -H --preserve-env=LEGION_SETUP_ROOT,DEBIAN_FRONTEND,NEEDRESTART_MODE \
      -E bash "$0" "$@"
  fi
}

# APT: 특정 URL을 포함하는 라인을 모든 list 파일에서 제거
apt_remove_repo_lines_globally() {
  local pattern="$1"
  local files=(/etc/apt/sources.list /etc/apt/sources.list.d/*.list)
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -Fq "$pattern" "$f"; then
      log "apt repo 정리: $f 의 '$pattern' 라인 제거"
      sed -i "\\|$pattern|d" "$f"
    fi
  done
}

# VS Code repo를 Deb822(.sources) 단일 파일로 통일
apt_fix_vscode_repo_singleton() {
  require_cmd dpkg; require_cmd wget; require_cmd gpg

  # 1) 키링 표준화
  install -d -m 0755 -o root -g root /usr/share/keyrings
  rm -f /usr/share/keyrings/microsoft.gpg
  local GNUPGHOME_DIR; GNUPGHOME_DIR="$(mktemp -d /tmp/gnupg-XXXXXX)"; chmod 700 "$GNUPGHOME_DIR"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | GNUPGHOME="$GNUPGHOME_DIR" gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
  chmod 0644 /usr/share/keyrings/microsoft.gpg
  rm -rf "$GNUPGHOME_DIR"

  # 2) 기존 .list / .sources 모두 제거
  apt_remove_repo_lines_globally "https://packages.microsoft.com/repos/code"
  rm -f /etc/apt/sources.list.d/vscode.list /etc/apt/sources.list.d/vscode.sources

  # 3) Deb822(.sources)로 단일 파일 생성
  local arch; arch="$(dpkg --print-architecture)"
  cat >/etc/apt/sources.list.d/vscode.sources <<'EOT'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/microsoft.gpg
EOT
  sed -i "1iArchitectures: ${arch}" /etc/apt/sources.list.d/vscode.sources
  chmod 0644 /etc/apt/sources.list.d/vscode.sources
}

require_ubuntu_2404() {
  [[ -r /etc/os-release ]] || err "/etc/os-release 를 찾을 수 없습니다."
  # shellcheck disable=SC1091
  . /etc/os-release
  local codename="${VERSION_CODENAME:-}" ver="${VERSION_ID:-}"
  [[ "${ID:-}" == "ubuntu" ]] || err "Ubuntu 환경이 아닙니다. (ID=${ID:-unknown})"
  [[ "${codename}" == "noble" ]] || err "Ubuntu 24.04 (noble) 필요"
  [[ "${ver}" == 24.04* ]] || err "Ubuntu 24.04.x 필요 (VERSION_ID=${ver:-unknown})"
}
