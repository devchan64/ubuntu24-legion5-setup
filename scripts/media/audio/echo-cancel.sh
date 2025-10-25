#!/usr/bin/env bash
# WebRTC 기반 Echo/Noise Cancellation 모듈 활성화
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# 공통 유틸 로드
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

# Xorg 불필요. 사용자 세션/버스만 보장되면 동작.
require_cmd pactl
ensure_user_systemd_ready

# PipeWire/Pulse 사용자 세션이 살아있는지 엄격 체크
pactl info >/dev/null 2>&1 \
  || err "pactl 응답 없음. PipeWire/Pulse 사용자 세션이 활성화된 그래픽/로그인 세션에서 실행하세요."

# (선택) 사용자 오디오 서비스 상태 점검: 비활성 시 즉시 중단
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet pipewire.service \
    || err "pipewire.service (user) 비활성. 사용자 세션에서 pipewire가 떠 있어야 합니다."
  # 일부 배포판은 pipewire-pulse 대신 pulseaudio를 사용하지 않음
  if systemctl --user list-unit-files | grep -q '^pipewire-pulse\.service'; then
    systemctl --user is-active --quiet pipewire-pulse.service \
      || err "pipewire-pulse.service (user) 비활성. Pulse 호환 레이어가 필요합니다."
  fi
fi

# 중복 모듈 정리
while pactl list short modules | grep -E "module-echo-cancel" >/dev/null 2>&1; do
  MID="$(pactl list short modules | awk '/module-echo-cancel/ {print $1; exit}' || true)"
  [[ -n "$MID" ]] || break
  log "Unload existing echo-cancel module: id=${MID}"
  pactl unload-module "$MID" || true
done

# WebRTC AEC 모듈 로드 (엄격 모드)
pactl load-module module-echo-cancel \
  aec_method=webrtc \
  aec_args="analog_gain_control=1 digital_gain_control=1 noise_suppression=1 voice_detection=1" \
  use_master_format=1 >/dev/null \
  || err "Failed to load module-echo-cancel (webrtc)."

# 활성화 검증
sleep 1
pactl list short modules | grep -E "module-echo-cancel" >/dev/null 2>&1 \
  || err "echo-cancel module not active."

log "[OK] WebRTC echo/noise cancellation enabled."
