#!/usr/bin/env bash
# Common utilities for ubuntu24-legion5-setup
# 원칙: 폴백 없음, 에러 즉시 종료
set -Eeuo pipefail

# ─────────────────────────────────────────────────────────────
# Basic logging
# ─────────────────────────────────────────────────────────────
_ts() { date +'%F %T'; }
log()  { printf "[%s] %s\n" "$(_ts)" "$*"; }
warn() { printf "[WARN %s] %s\n" "$(_ts)" "$*" >&2; }
err()  { printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

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
require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || err "command not found: ${cmd}"
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."
}

# sudo 환경에서도 실제 로그인 세션 타입을 탐지
detect_session_type() {
  local t="${XDG_SESSION_TYPE:-}"
  if [[ -n "$t" ]]; then printf "%s" "$t"; return 0; fi
  local u="${SUDO_USER:-$USER}"
  if command -v loginctl >/dev/null 2>&1; then
    local sid
    sid="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v uu="$u" '$3==uu {print $1; exit}')"
    if [[ -n "$sid" ]]; then
      loginctl show-session "$sid" -p Type --value 2>/dev/null | tr -d '\n'
      return 0
    fi
  fi
  printf "unknown"
}

require_xorg_or_die() {
  local t; t="$(detect_session_type)"
  [[ "$t" == "x11" ]] || err "Xorg(X11) 세션이 아닙니다. 현재: '${t:-unknown}'. Xorg로 로그인 후 재시도하세요."
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

# ─────────────────────────────────────────────────────────────
# Packages / services
# ─────────────────────────────────────────────────────────────
has_pkg() {
  local name="$1"
  dpkg-query -W -f='${Status}\n' "$name" 2>/dev/null | grep -q "install ok installed"
}

apt_install() {
  require_root
  [[ $# -gt 0 ]] || err "apt_install: 패키지 이름이 필요합니다."
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

service_is_active() {
  local unit="$1"
  systemctl is-active --quiet "$unit"
}

ensure_service_enabled_and_started() {
  # 사용자/시스템 유닛 모두 지원. 호출자가 적절한 namespace(system/user)를 결정해야 함.
  local unit="$1"
  if systemctl list-unit-files | grep -q "^${unit}\b"; then
    sudo systemctl enable "$unit"
    sudo systemctl restart "$unit"
    systemctl is-active --quiet "$unit" || err "service not active: ${unit}"
  elif systemctl --user list-unit-files | grep -q "^${unit}\b"; then
    systemctl --user enable "$unit"
    systemctl --user restart "$unit"
    systemctl --user is-active --quiet "$unit" || err "user service not active: ${unit}"
  else
    err "unit not found: ${unit}"
  fi
}

# ─────────────────────────────────────────────────────────────
# Files / edits (idempotent)
# ─────────────────────────────────────────────────────────────
ensure_line() {
  # 파일에 특정 라인이 없으면 추가 (정확히 동일한 라인 기준)
  local line="$1" file="$2"
  [[ -f "$file" ]] || touch "$file"
  grep -Fxq "$line" "$file" || printf "%s\n" "$line" >>"$file"
}

acquire_lock() {
  # 간단한 파일 락. 락 파일이 있으면 실패.
  local name="$1"
  local lock="${PROJECT_STATE_DIR}/${name}.lock"
  [[ -e "$lock" ]] && err "lock exists: ${lock}"
  touch "$lock"
  printf "%s\n" "$lock"
}

release_lock() {
  local path="$1"
  [[ -z "$path" ]] && err "release_lock: path required"
  rm -f -- "$path"
}

# ─────────────────────────────────────────────────────────────
# User systemd (linger)
# ─────────────────────────────────────────────────────────────
ensure_user_systemd_ready() {
  # user lingering이 꺼져 있으면 root 권한으로 활성화 필요
  local u="${SUDO_USER:-$USER}"

  # loginctl 가용성/사용자 존재 확인
  command -v loginctl >/dev/null 2>&1 || err "loginctl 명령을 찾을 수 없습니다."
  loginctl show-user "$u" >/dev/null 2>&1 || err "loginctl show-user 실패(user=${u})"

  if loginctl show-user "$u" 2>/dev/null | grep -q "^Linger=no"; then
    require_root
    log "enabling linger for ${u}"
    loginctl enable-linger "$u"
  fi

  # user-bus / systemd --user 간단 상태 점검
  if ! sudo -u "$u" systemctl --user is-active default.target >/dev/null 2>&1; then
    warn "systemd --user 세션이 활성화되어 있지 않을 수 있습니다. (로그인 세션 필요)"
  fi
}

# ─────────────────────────────────────────────────────────────
# JSON logging helper (선택적으로 jq 필요)
# ─────────────────────────────────────────────────────────────
log_json_result() {
  require_cmd jq
  local key="$1"; shift
  jq -n --arg key "$key" --arg time "$(_ts)" --arg data "$*" \
    '{time:$time, key:$key, data:$data}'
}
