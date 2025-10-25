#!/usr/bin/env bash
# PipeWire/PulseAudio 가상 마이크(OBS_Monitor.monitor → OBS_VirtualMic) 생성
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
require_cmd pactl

# user-bus가 필요한 작업이므로 가용성 점검
ensure_user_systemd_ready

VIRT_SOURCE_NAME="OBS_VirtualMic"
MASTER_MONITOR="OBS_Monitor.monitor"

# pactl 동작 확인
pactl info >/dev/null 2>&1 || err "pactl is not responding. Ensure a user session with PipeWire/Pulse is active."

# 이미 존재하면 성공 종료
if pactl list short sources | awk '{print $2}' | grep -Fxq "${VIRT_SOURCE_NAME}"; then
  log "[OK] Virtual mic already exists: ${VIRT_SOURCE_NAME}"
  exit 0
fi

# 마스터 모니터(OBS_Monitor.monitor) 대기 (최대 ~10s)
for i in {1..20}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "${MASTER_MONITOR}"; then
    break
  fi
  sleep 0.5
done
pactl list short sources | awk '{print $2}' | grep -Fxq "${MASTER_MONITOR}" \
  || err "Master monitor not found: ${MASTER_MONITOR}. OBS 모니터 싱크를 먼저 생성하세요."

# 동일 이름의 가상 소스가 남아있다면 정리
while pactl list short modules | awk '{print $2" "$1}' | grep -E "module-virtual-source" | grep -E "${VIRT_SOURCE_NAME}" >/dev/null 2>&1; do
  MID="$(pactl list short modules | grep module-virtual-source | grep -F "source_name=${VIRT_SOURCE_NAME}" | awk '{print $1}' | head -n1 || true)"
  [[ -n "$MID" ]] || break
  log "Unload existing virtual-source module: id=${MID}"
  pactl unload-module "$MID" || true
done

# 가상 마이크 생성
pactl load-module module-virtual-source source_name="${VIRT_SOURCE_NAME}" master="${MASTER_MONITOR}" >/dev/null \
  || err "Failed to load module-virtual-source"

# 생성 확인(최대 ~10s)
for i in {1..20}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "${VIRT_SOURCE_NAME}"; then
    log "[OK] Created virtual mic: ${VIRT_SOURCE_NAME} (master=${MASTER_MONITOR})"
    exit 0
  fi
  sleep 0.5
done

err "Virtual mic creation timed out."
