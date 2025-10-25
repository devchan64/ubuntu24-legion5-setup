#!/usr/bin/env bash
# PipeWire/Pulse: "OBS_Monitor" null-sink 생성
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
require_cmd pactl
ensure_user_systemd_ready

SINK_NAME="OBS_Monitor"

pactl info >/dev/null 2>&1 || err "pactl not responding; ensure user PipeWire/Pulse session."

if pactl list short sinks | awk '{print $2}' | grep -Fxq "${SINK_NAME}"; then
  log "[OK] Monitor sink already exists: ${SINK_NAME}"
  exit 0
fi

while true; do
  MID="$(pactl list short modules | grep -E 'module-null-sink' | grep -F "sink_name=${SINK_NAME}" | awk '{print $1}' | head -n1 || true)"
  [[ -z "$MID" ]] && break
  log "Unload existing null-sink module: id=${MID}"
  pactl unload-module "$MID" || true
done

pactl load-module module-null-sink sink_name="${SINK_NAME}" sink_properties=device.description="${SINK_NAME}" >/dev/null \
  || err "Failed to load module-null-sink (${SINK_NAME})"

for i in {1..20}; do
  if pactl list short sinks | awk '{print $2}' | grep -Fxq "${SINK_NAME}"; then
    log "[OK] Created monitor sink: ${SINK_NAME}"
    exit 0
  fi
  sleep 0.5
done

err "Monitor sink creation timed out: ${SINK_NAME}"
