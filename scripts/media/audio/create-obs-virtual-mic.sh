#!/usr/bin/env bash
# PipeWire/Pulse: "OBS_VirtualMic" 가상 마이크 생성 (master=OBS_Monitor.monitor)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
require_cmd pactl
ensure_user_systemd_ready
pactl info >/dev/null 2>&1 || err "pactl not responding; ensure user PipeWire/Pulse session."

VIRT_SOURCE_NAME="OBS_VirtualMic"
MASTER_MONITOR="OBS_Monitor.monitor"

pactl list short sources | awk '{print $2}' | grep -Fxq "${MASTER_MONITOR}" \
  || err "Master monitor not found: ${MASTER_MONITOR}. 먼저 create-obs-monitor-sink.sh 를 실행하세요."

if pactl list short sources | awk '{print $2}' | grep -Fxq "${VIRT_SOURCE_NAME}"; then
  log "[OK] Virtual mic already exists: ${VIRT_SOURCE_NAME}"
  exit 0
fi

while true; do
  MID="$(pactl list short modules | grep -E 'module-virtual-source' | grep -F "source_name=${VIRT_SOURCE_NAME}" | awk '{print $1}' | head -n1 || true)"
  [[ -z "$MID" ]] && break
  log "Unload existing virtual-source module: id=${MID}"
  pactl unload-module "$MID" || true
done

pactl load-module module-virtual-source source_name="${VIRT_SOURCE_NAME}" master="${MASTER_MONITOR}" >/dev/null \
  || err "Failed to load module-virtual-source"

for i in {1..20}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "${VIRT_SOURCE_NAME}"; then
    log "[OK] Created virtual mic: ${VIRT_SOURCE_NAME} (master=${MASTER_MONITOR})"
    exit 0
  fi
  sleep 0.5
done

err "Virtual mic creation timed out: ${VIRT_SOURCE_NAME}"
