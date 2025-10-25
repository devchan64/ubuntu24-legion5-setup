#!/usr/bin/env bash
# Ubuntu 24.04 LTS | Legion 5 profile | orchestrator for all setup domains
set -Eeuo pipefail

readonly ROOT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
  pwd -P
)"

log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }
err() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || err "command not found: ${cmd}"
}

require_xorg_or_die() {
  local t="${XDG_SESSION_TYPE:-}"
  [[ "$t" == "x11" ]] || err "Xorg(X11) 세션이 아닙니다. 현재: '${t:-unknown}'. Xorg로 로그인 후 다시 실행하세요."
}

must_run() {
  local rel="$1"; shift || true
  local path="${ROOT_DIR}/${rel}"
  [[ -f "$path" ]] || err "script not found: ${rel}"
  log "RUN: ${rel} $*"
  bash "$path" "$@"
}

run_sys() {
  [[ -f "${ROOT_DIR}/scripts/sys/bootstrap.sh" ]] && must_run "scripts/sys/bootstrap.sh" || true
  [[ -f "${ROOT_DIR}/scripts/sys/xorg-ensure.sh" ]] && must_run "scripts/sys/xorg-ensure.sh" || true
}

run_dev() {
  [[ -f "${ROOT_DIR}/scripts/dev/python/setup.sh" ]] && must_run "scripts/dev/python/setup.sh" || true
  [[ -f "${ROOT_DIR}/scripts/dev/node/setup.sh"   ]] && must_run "scripts/dev/node/setup.sh"   || true
  [[ -f "${ROOT_DIR}/scripts/dev/docker/install.sh" ]] && must_run "scripts/dev/docker/install.sh" || true
}

run_ml() {
  require_cmd docker
  command -v nvidia-smi >/dev/null 2>&1 || err "NVIDIA 드라이버가 필요합니다."
  [[ -f "${ROOT_DIR}/scripts/ml/tf/run-jupyter.sh" ]] \
    && must_run "scripts/ml/tf/run-jupyter.sh" --pull-only \
    || err "scripts/ml/tf/run-jupyter.sh not found."
}

run_media() {
  require_xorg_or_die
  must_run "scripts/media/video/obs-install.sh"
  must_run "scripts/media/audio/create-obs-monitor-sink.sh"
  must_run "scripts/media/audio/install-virtual-audio.sh"
  must_run "scripts/media/audio/create-obs-virtual-mic.sh"
  must_run "scripts/media/audio/echo-cancel.sh"
}

run_security() {
  [[ -f "${ROOT_DIR}/scripts/security/install.sh" ]] && must_run "scripts/security/install.sh" || true
  [[ -f "${ROOT_DIR}/scripts/security/scan.sh" ]] && must_run "scripts/security/scan.sh" || true
  [[ -f "${ROOT_DIR}/scripts/security/schedule.sh" ]] && must_run "scripts/security/schedule.sh" --enable-weekly || true
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

usage() {
  cat <<'EOF'
Usage: bash scripts/install-all.sh [--all] [--sys] [--dev] [--ml] [--media] [--security] [--net] [--ops]

옵션:
  --all        모든 도메인을 순서대로 실행(기본값)
  --sys        시스템 부트스트랩 및 Xorg 보정
  --dev        개발 도구 (Python/Node/Docker)
  --ml         TensorFlow Jupyter 컨테이너 초기화
  --media      오디오/비디오 (OBS, 가상마이크, 에코캔슬) — Xorg 필수
  --security   보안 도구 설치/스캔/스케줄
  --net        네트워크 도구 설치
  --ops        운영 모니터링 도구 설치
EOF
}

main() {
  require_cmd bash
  local run_all=true
  local want_sys=false want_dev=false want_ml=false want_media=false want_sec=false want_net=false want_ops=false

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
  $want_sys && run_sys
  $want_dev && run_dev
  $want_ml && run_ml
  $want_media && run_media
  $want_sec && run_security
  $want_net && run_net
  $want_ops && run_ops
  log "DONE."
}

main "$@"
