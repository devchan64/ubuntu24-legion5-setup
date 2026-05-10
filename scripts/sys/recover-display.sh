#!/usr/bin/env bash
# file: scripts/sys/recover-display.sh
# Domain: KVM 스위칭 이후 외부 모니터 신호 복구용 수동 실행 스크립트
# Contract: Xorg 사용자 세션에서 실행해야 한다.
set -Eeuo pipefail
set -o errtrace

main() {
  local external="${1:-HDMI-0}"
  local internal="${2:-eDP-1-1}"
  local ext_mode="${3:-3840x2160}"
  local ext_rate="${4:-60}"
  local int_mode="${5:-2560x1600}"
  local int_rate="${6:-165}"

  command -v xrandr >/dev/null 2>&1 || { echo "[ERROR] xrandr not found" >&2; exit 1; }

  # 1) 외부 단독 신호 복구를 먼저 시도
  xrandr --output "${internal}" --off --output "${external}" --mode "${ext_mode}" --rate "${ext_rate}" --primary || true
  sleep 1

  # 2) 외부 기준 듀얼 레이아웃 복구
  xrandr --output "${external}" --mode "${ext_mode}" --rate "${ext_rate}" --pos 0x0 --primary \
         --output "${internal}" --mode "${int_mode}" --rate "${int_rate}" --pos 3840x0
}

main "$@"
