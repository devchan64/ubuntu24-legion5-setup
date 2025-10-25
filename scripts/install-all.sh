#!/usr/bin/env bash
# Ubuntu 24.04 LTS | Legion 5 profile | orchestrator for all setup domains
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# ────────────────────────────────────────────────
# Project root (LEGION_SETUP_ROOT 우선, readlink 보강, Trash 차단)
# ────────────────────────────────────────────────
readonly OVERRIDE_ROOT="${LEGION_SETUP_ROOT:-}"
if [[ -n "${OVERRIDE_ROOT}" ]]; then
  [[ -d "${OVERRIDE_ROOT}" ]] || { printf "[ERROR] LEGION_SETUP_ROOT not a directory: %s\n" "${OVERRIDE_ROOT}" >&2; exit 1; }
  ROOT_DIR="$(cd -- "${OVERRIDE_ROOT}" >/dev/null 2>&1 && pwd -P)"
else
  command -v readlink >/dev/null 2>&1 || { printf "[ERROR] readlink command required.\n" >&2; exit 1; }
  readonly SELF_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
  readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${SELF_PATH}")" >/dev/null 2>&1 && pwd -P)"
  ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
fi

log()  { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }
warn() { printf "[WARN ] %s\n" "$*" >&2; }
err()  { printf "[ERROR] %s\n" "$*" >&2; exit 1; }

diagnose_and_fail() {
  warn "SELF_PATH=${SELF_PATH:-<override>}"
  warn "PWD=$(pwd -P)"
  warn "ROOT_DIR=${ROOT_DIR}"
  warn "Hint:"
  warn "  - realpath scripts/install-all.sh 로 실제 경로 확인"
  warn "  - LEGION_SETUP_ROOT=/abs/path 로 루트 강제 가능"
  err  "project root detection failed."
}

if [[ ! -f "${ROOT_DIR}/scripts/install-all.sh" ]] || [[ ! -d "${ROOT_DIR}/scripts" ]] || [[ ! -f "${ROOT_DIR}/lib/common.sh" ]]; then
  diagnose_and_fail
fi

case "${ROOT_DIR}" in
  */.local/share/Trash/*|*"/Trash/"* ) warn "Trash-like path detected"; diagnose_and_fail ;;
esac

# ────────────────────────────────────────────────
# Mini guards (공통 모듈에 의존하지 않음)
# ────────────────────────────────────────────────
require_cmd() { command -v "$1" >/dev/null 2>&1 || err "command not found: $1"; }
require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."; }

# sudo 상황에서도 실제 로그인 세션 타입을 판단
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

# ────────────────────────────────────────────────
# User-context helpers (MEDIA/오디오는 사용자 컨텍스트에서만 실행)
# ────────────────────────────────────────────────
target_user() { printf "%s" "${SUDO_USER:-$USER}"; }
target_uid()  { id -u "$(target_user)"; }

# GUI 사용자 세션의 user-bus가 준비될 때까지 대기하고 환경을 주입해 실행
user_exec() {
  local u; u="$(target_user)"
  local uid; uid="$(target_uid)"
  local rtd="/run/user/${uid}"

  # root에서만 user@UID 기동 시도
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    systemctl start "user@${uid}.service" >/dev/null 2>&1 || true
  fi

  [[ -d "${rtd}" ]] || err "XDG_RUNTIME_DIR(${rtd})가 없습니다. 대상 사용자 그래픽/로그인 세션이 필요합니다."

  for _ in {1..20}; do
    [[ -S "${rtd}/bus" ]] && break
    sleep 0.25
  done
  [[ -S "${rtd}/bus" ]] || err "user D-Bus(${rtd}/bus)가 준비되지 않았습니다. 데스크톱 세션에서 다시 실행하세요."

  if [[ "${EUID:-$(id -u)}" -ne "${uid}" ]]; then
    XDG_RUNTIME_DIR="${rtd}" DBUS_SESSION_BUS_ADDRESS="unix:path=${rtd}/bus" \
      sudo -H -u "${u}" bash -lc "$*"
  else
    XDG_RUNTIME_DIR="${rtd}" DBUS_SESSION_BUS_ADDRESS="unix:path=${rtd}/bus" \
      bash -lc "$*"
  fi
}

# ────────────────────────────────────────────────
# Runner helpers
# ────────────────────────────────────────────────
must_run() {
  local rel="$1"; shift || true
  local path="${ROOT_DIR}/${rel}"
  [[ -f "$path" ]] || err "script not found: ${rel}"
  log "RUN: ${rel} $*"
  bash "$path" "$@"
}

run_sys() {
  [[ -f "${ROOT_DIR}/scripts/sys/bootstrap.sh"   ]] && must_run "scripts/sys/bootstrap.sh"   || true
  [[ -f "${ROOT_DIR}/scripts/sys/xorg-ensure.sh" ]] && must_run "scripts/sys/xorg-ensure.sh" || true
}

run_dev() {
  [[ -f "${ROOT_DIR}/scripts/dev/python/install.sh" ]] && must_run "scripts/dev/python/install.sh" || true
  [[ -f "${ROOT_DIR}/scripts/dev/node/install.sh"   ]] && must_run "scripts/dev/node/install.sh"   || true

  if [[ -f "${ROOT_DIR}/scripts/dev/docker/install.sh" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      if [[ "${AUTO_DOCKER}" -eq 1 ]]; then
        log "docker not found. installing docker stack (--auto-docker)"
        require_root
        bash "${ROOT_DIR}/scripts/dev/docker/install.sh"
        require_cmd docker
      else
        err "command not found: docker
해결: 1) sudo bash scripts/install-all.sh --dev --auto-docker
     2) 또는 sudo bash scripts/dev/docker/install.sh 실행 후 재시도"
      fi
    else
      log "docker already installed. skipping docker/install.sh"
    fi
  fi

  if [[ "${WITH_NVIDIA_TOOLKIT}" -eq 1 ]]; then
    command -v nvidia-smi >/dev/null 2>&1 || err "--nvidia-toolkit 지정 시 NVIDIA 드라이버(nvidia-smi)가 필요합니다."
    must_run "scripts/dev/docker/install-nvidia-toolkit.sh"
  fi
}

run_ml() {
  if ! command -v docker >/dev/null 2>&1; then
    if [[ "${AUTO_DOCKER}" -eq 1 ]]; then
      log "docker not found. installing via dev/docker/install.sh (--auto-docker)"
      require_root
      bash "${ROOT_DIR}/scripts/dev/docker/install.sh"
      require_cmd docker
    else
      err "command not found: docker
--ml 실행에는 docker가 필요합니다.
해결: sudo bash scripts/install-all.sh --ml --auto-docker"
    fi
  fi
  command -v nvidia-smi >/dev/null 2>&1 || err "NVIDIA 드라이버가 필요합니다. nvidia-smi 가 동작해야 합니다."
  [[ -f "${ROOT_DIR}/scripts/ml/tf/run-jupyter.sh" ]] \
    && must_run "scripts/ml/tf/run-jupyter.sh" --pull-only \
    || err "scripts/ml/tf/run-jupyter.sh not found."

  if [[ "${WITH_NVIDIA_TOOLKIT}" -eq 1 ]]; then
    must_run "scripts/dev/docker/install-nvidia-toolkit.sh"
  fi
}

# ── 비디오(Media): OBS 설치만 수행 (D-Bus 불필요)
run_media_video() {
  user_exec "${ROOT_DIR}/scripts/media/video/obs-install.sh"
}

# ── 오디오: 가상 모니터/마이크 + 에코캔슬 (GUI 사용자 세션에서만)
run_virtual_audio() {
  # 현재 사용자 컨텍스트에서 바로 실행 (sudo 금지)
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "--virtual-audio 는 root로 실행할 수 없습니다. GUI 사용자 세션의 터미널에서 실행하세요."
  fi

  # D-Bus/오디오 세션 사전 확인
  [[ -S "/run/user/$(id -u)/bus" ]] \
    || err "user D-Bus(/run/user/$(id -u)/bus) 미검출. GUI 사용자 세션에서 실행하세요."
  command -v pactl >/dev/null 2>&1 \
    || err "pactl 명령을 찾을 수 없습니다. PipeWire/Pulse 구성 확인 필요."

  bash "${ROOT_DIR}/scripts/media/audio/install-virtual-audio.sh"
  bash "${ROOT_DIR}/scripts/media/audio/echo-cancel.sh"
}


run_security() {
  [[ -f "${ROOT_DIR}/scripts/security/install.sh"   ]] && must_run "scripts/security/install.sh"   || true
  [[ -f "${ROOT_DIR}/scripts/security/scan.sh"      ]] && must_run "scripts/security/scan.sh"      || true
  [[ -f "${ROOT_DIR}/scripts/security/schedule.sh"  ]] && must_run "scripts/security/schedule.sh" --enable-weekly || true
}

run_net() {
  [[ -f "${ROOT_DIR}/scripts/net/tools-install.sh" ]] \
    && must_run "scripts/net/tools-install.sh" \
    || err "scripts/net/tools-install.sh not found."
}

run_ops() {
  [[ -f "${ROOT_DIR}/scripts/ops/monitors-install.sh" ]] \
    && must_run "scripts/ops/monitors-install.sh" \
    || err "scripts/ops/monitors-install.sh not found."
}

# ────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage:
  bash scripts/install-all.sh [--all] [--sys] [--dev] [--ml] [--media-video] [--virtual-audio] [--security] [--net] [--ops] [--auto-docker] [--nvidia-toolkit]
  LEGION_SETUP_ROOT=/abs/path bash scripts/install-all.sh [opts]   # 루트 강제(고급)

옵션:
  --all                 모든 도메인을 순서대로 실행(오디오는 제외)
  --sys                 시스템 부트스트랩 및 Xorg 보정
  --dev                 개발 도구 (Python/Node/Docker)
  --ml                  TensorFlow Jupyter 컨테이너 초기화 (docker + nvidia-smi 필요)
  --media-video         비디오 구성(OBS APT 설치/업데이트) — D-Bus 불필요
  --virtual-audio       오디오 구성(가상모니터/가상마이크 + 에코캔슬) — **GUI 사용자 세션에서 실행**
  --security            보안 도구 설치/스캔/스케줄
  --net                 네트워크 도구 설치
  --ops                 운영 모니터링 도구 설치
  --auto-docker         docker 미설치 시 dev/docker/install.sh 를 자동 실행(루트 필요)
  --nvidia-toolkit      NVIDIA Container Toolkit 설치(드라이버 필요, docker 선행)

예시:
  sudo bash scripts/install-all.sh --all
  # 설치 완료 후, GUI 사용자 터미널에서:
  bash scripts/install-all.sh --virtual-audio
EOF
}

main() {
  require_cmd bash
  local run_all=true
  local want_sys=false want_dev=false want_ml=false want_media_video=false want_virtual_audio=false want_sec=false want_net=false want_ops=false
  AUTO_DOCKER=0
  WITH_NVIDIA_TOOLKIT=0

  if [[ $# -gt 0 ]]; then
    run_all=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --all) run_all=true ;;
        --sys) want_sys=true ;;
        --dev) want_dev=true ;;
        --ml)  want_ml=true ;;
        --media-video) want_media_video=true ;;
        --virtual-audio) want_virtual_audio=true ;;
        --security) want_sec=true ;;
        --net) want_net=true ;;
        --ops) want_ops=true ;;
        --auto-docker) AUTO_DOCKER=1 ;;
        --nvidia-toolkit) WITH_NVIDIA_TOOLKIT=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown option: $1" ;;
      esac
      shift
    done
  fi

  if $run_all; then
    # D-Bus 의존 작업(오디오)은 제외
    want_sys=true; want_dev=true; want_ml=true; want_media_video=true; want_sec=true; want_net=true; want_ops=true
  fi

  log "project root: ${ROOT_DIR}"

  # docker 자동 보완: root로 실행 중이며 docker 없고, dev 또는 ml 수행 예정이면 --auto-docker 강제
  if { $want_dev || $want_ml || $run_all; } && [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      if [[ "${AUTO_DOCKER}" -eq 0 ]]; then
        warn "docker not found. enabling --auto-docker automatically (running as root)"
        AUTO_DOCKER=1
      fi
    fi
  fi

  # 실행 순서: SYS → DEV → ML → MEDIA(비디오만) → SECURITY → NET → OPS
  $want_sys          && run_sys
  $want_dev          && run_dev
  $want_ml           && run_ml
  $want_media_video  && run_media_video
  $want_sec          && run_security
  $want_net          && run_net
  $want_ops          && run_ops

  # 오디오는 별도 옵션으로만 실행
  if $want_virtual_audio; then
    # 일반 사용자 GUI 터미널에서 실행해야 함
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      err "--virtual-audio 는 root로 실행할 수 없습니다. GUI 사용자 세션의 터미널에서 다음을 실행하세요:
  bash scripts/install-all.sh --virtual-audio"
    fi
    run_virtual_audio
  fi

  log "DONE."
  if $run_all; then
    printf -- "\n---------------------------------------------\n"
    printf -- "OBS 설치가 완료되었습니다. 실행: obs\n"
    printf -- "오디오(가상모니터/가상마이크 + 에코캔슬) 설정은 GUI 사용자 세션에서 다음을 실행하세요:\n"
    printf -- "  bash scripts/install-all.sh --virtual-audio\n"
    printf -- "---------------------------------------------\n"
  fi
}

main "$@"
