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

require_xorg_or_die() {
  local t; t="$(detect_session_type)"
  [[ "$t" == "x11" ]] || err "Xorg(X11) 세션이 아닙니다. 현재: '${t:-unknown}'. Xorg로 로그인 후 다시 실행하세요."
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

run_media() {
  require_xorg_or_die
  must_run "scripts/media/video/obs-install.sh"
  must_run "scripts/media/audio/install-virtual-audio.sh"
  must_run "scripts/media/audio/echo-cancel.sh"
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
  bash scripts/install-all.sh [--all] [--sys] [--dev] [--ml] [--media] [--security] [--net] [--ops] [--auto-docker] [--nvidia-toolkit] [--skip-media-if-not-xorg]
  LEGION_SETUP_ROOT=/abs/path bash scripts/install-all.sh [opts]   # 루트 강제(고급)

옵션:
  --all                 모든 도메인을 순서대로 실행(기본값)
  --sys                 시스템 부트스트랩 및 Xorg 보정
  --dev                 개발 도구 (Python/Node/Docker)
  --ml                  TensorFlow Jupyter 컨테이너 초기화 (docker + nvidia-smi 필요)
  --media               오디오/비디오 (OBS, 가상마이크, 에코캔슬) — Xorg 필수
  --security            보안 도구 설치/스캔/스케줄
  --net                 네트워크 도구 설치
  --ops                 운영 모니터링 도구 설치
  --auto-docker         docker 미설치 시 dev/docker/install.sh 를 자동 실행(루트 필요)
  --nvidia-toolkit      NVIDIA Container Toolkit 설치(드라이버 필요, docker 선행)
  --skip-media-if-not-xorg  현재 세션이 Xorg가 아닐 경우 MEDIA만 건너뜀(명시적 허용)
EOF
}

main() {
  require_cmd bash
  local run_all=true
  local want_sys=false want_dev=false want_ml=false want_media=false want_sec=false want_net=false want_ops=false
  AUTO_DOCKER=0
  WITH_NVIDIA_TOOLKIT=0
  SKIP_MEDIA_IF_NOT_XORG=0

  if [[ $# -gt 0 ]]; then
    run_all=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --all) run_all=true ;;
        --sys) want_sys=true ;;
        --dev) want_dev=true ;;
        --ml)  want_ml=true ;;
        --media) want_media=true ;;
        --security) want_sec=true ;;
        --net) want_net=true ;;
        --ops) want_ops=true ;;
        --auto-docker) AUTO_DOCKER=1 ;;
        --nvidia-toolkit) WITH_NVIDIA_TOOLKIT=1 ;;
        --skip-media-if-not-xorg) SKIP_MEDIA_IF_NOT_XORG=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown option: $1" ;;
      esac
      shift
    done
  fi

  if $run_all; then
    want_sys=true; want_dev=true; want_ml=true; want_media=true; want_sec=true; want_net=true; want_ops=true
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

  # MEDIA 사전 점검: sudo에서도 실제 세션 타입을 정밀 감지
  if $want_media; then
    local t
    t="$(detect_session_type)"
    if [[ "${t}" != "x11" ]]; then
      if [[ "${SKIP_MEDIA_IF_NOT_XORG}" -eq 1 ]]; then
        warn "non-Xorg session detected (${t:-unknown}); skipping MEDIA per --skip-media-if-not-xorg"
        want_media=false
      else
        err "MEDIA 실행에는 Xorg(X11)가 필요합니다. 현재: '${t:-unknown}'
해결:
  - Xorg 세션으로 로그인 후 재실행: bash scripts/install-all.sh --media
  - 이번엔 MEDIA 제외: bash scripts/install-all.sh --sys --dev --ml --security --net --ops
  - 또는 명시적 스킵: bash scripts/install-all.sh --all --skip-media-if-not-xorg"
      fi
    fi
  fi

  # 실행 순서: SYS → DEV → ML → MEDIA → SECURITY → NET → OPS
  $want_sys    && run_sys
  $want_dev    && run_dev
  $want_ml     && run_ml
  $want_media  && run_media
  $want_sec    && run_security
  $want_net    && run_net
  $want_ops    && run_ops

  log "DONE."
}

main "$@"
