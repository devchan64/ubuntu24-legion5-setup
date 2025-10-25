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

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."
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

# 설치 단계(그래픽 환경이면 OK): Wayland 또는 Xorg 모두 허용
require_graphical_or_die() {
  local t; t="$(detect_session_type)"
  [[ "$t" == "x11" || "$t" == "wayland" ]] \
    || err "그래픽 세션이 아닙니다. 현재: '${t:-unknown}'. 데스크톱 세션에서 재시도하세요."
}

# 런타임 등 Xorg 전제 기능에만 사용
require_xorg_or_die() {
  local t; t="$(detect_session_type)"
  [[ "$t" == "x11" ]] \
    || err "Xorg(X11) 세션이 아닙니다. 현재: '${t:-unknown}'. Xorg로 로그인 후 재시도하세요."
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
  local u="${SUDO_USER:-$USER}"
  command -v loginctl >/dev/null 2>&1 || err "loginctl 명령을 찾을 수 없습니다."
  loginctl show-user "$u" >/dev/null 2>&1 || err "loginctl show-user 실패(user=${u})"

  if loginctl show-user "$u" 2>/dev/null | grep -q "^Linger=no"; then
    require_root
    log "enabling linger for ${u}"
    loginctl enable-linger "$u"
  fi
}

# 원샷 자동화를 위한 user D-Bus 보장(루트에서 호출)
ensure_user_bus_ready() {
  local u="${SUDO_USER:-$USER}"; local uid; uid="$(id -u "$u")"
  local rtd="/run/user/${uid}"

  ensure_user_systemd_ready
  # user@UID 기동 시도
  systemctl start "user@${uid}.service" >/dev/null 2>&1 || true

  # /run/user/UID 및 bus 대기(최대 ~5초)
  for _ in {1..20}; do
    [[ -S "${rtd}/bus" ]] && break
    sleep 0.25
  done
  [[ -S "${rtd}/bus" ]] || err "user D-Bus(${rtd}/bus) 미준비: 데스크톱 세션 또는 PAM/systemd 설정 확인 필요"

  # 오디오 사용자 서비스 가동 (있으면)
  XDG_RUNTIME_DIR="${rtd}" DBUS_SESSION_BUS_ADDRESS="unix:path=${rtd}/bus" \
    sudo -H -u "$u" systemctl --user import-environment XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS || true
  sudo -H -u "$u" systemctl --user enable --now pipewire.service wireplumber.service >/dev/null 2>&1 || true
  if sudo -H -u "$u" systemctl --user list-unit-files | grep -q '^pipewire-pulse\.service'; then
    sudo -H -u "$u" systemctl --user enable --now pipewire-pulse.service >/dev/null 2>&1 || true
  fi
}



# ─────────────────────────────────────────────────────────────
# JSON logging helper (선택적으로 jq 필요)
# ─────────────────────────────────────────────────────────────
log_json_result() {
  require_cmd jq
  local key="$1"; shift
  jq -n --arg key "$key" --arg time "$(ts)" --arg data "$*" \
    '{time:$time, key:$key, data:$data}'
}
