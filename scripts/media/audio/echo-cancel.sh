#!/usr/bin/env bash
# WebRTC 기반 Echo/Noise Cancellation 모듈 활성화
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
require_cmd pactl

ensure_user_systemd_ready
pactl info >/dev/null 2>&1 || err "pactl is not responding. Ensure a user session with PipeWire/Pulse is active."

# 중복 모듈 정리
while pactl list short modules | grep -E "module-echo-cancel" >/dev/null 2>&1; do
  MID="$(pactl list short modules | grep module-echo-cancel | awk '{print $1}' | head -n1 || true)"
  [[ -n "$MID" ]] || break
  log "Unload existing echo-cancel module: id=${MID}"
  pactl unload-module "$MID" || true
done

pactl load-module module-echo-cancel \
  aec_method=webrtc aec_args="analog_gain_control=1 digital_gain_control=1 noise_suppression=1 voice_detection=1" \
  use_master_format=1  >/dev/null \
  || err "Failed to load module-echo-cancel (webrtc)."

sleep 1
pactl list short modules | grep -E "module-echo-cancel" >/dev/null 2>&1 \
  || err "echo-cancel module not active."

log "[OK] WebRTC echo/noise cancellation enabled."
