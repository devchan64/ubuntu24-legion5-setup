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
      sed -i "\|$pattern|d" "$f"
    fi
  done
}

# VS Code repo를 단일 keyring(/usr/share/keyrings/microsoft.gpg)으로 통일
apt_fix_vscode_repo_singleton() {
  require_cmd dpkg; require_cmd wget; require_cmd gpg

  install -d -m 0755 -o root -g root /usr/share/keyrings
  rm -f /usr/share/keyrings/microsoft.gpg
  local GNUPGHOME_DIR; GNUPGHOME_DIR="$(mktemp -d /tmp/gnupg-XXXXXX)"; chmod 700 "$GNUPGHOME_DIR"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | GNUPGHOME="$GNUPGHOME_DIR" gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
  chmod 0644 /usr/share/keyrings/microsoft.gpg
  rm -rf "$GNUPGHOME_DIR"

  apt_remove_repo_lines_globally "https://packages.microsoft.com/repos/code"
  local line="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"
  printf '%s\n' "$line" > /etc/apt/sources.list.d/vscode.list
  chmod 0644 /etc/apt/sources.list.d/vscode.list
}

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
  arch="$(dpkg --print-architecture)"
  cat >/etc/apt/sources.list.d/vscode.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
  # Architecture 제한을 Deb822에 추가 (Arch-Only)
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