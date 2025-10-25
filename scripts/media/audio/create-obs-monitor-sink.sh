#!/usr/bin/env bash
# OBS_Monitor null-sink 생성 + 모니터 소스 준비 확인
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }
info(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
ok(){ printf "[%s] %s\n" "$(_ts)" "$*"; }

require_cmd pactl
# 사용자 오디오 세션/버스 확인
pactl info >/dev/null 2>&1 || err "pactl info 실패: user-bus 또는 PipeWire 계열 데몬 미준비"

# 이미 존재하면 성공 종료
if pactl list short sinks | awk '{print $2}' | grep -Fxq "OBS_Monitor"; then
  info "OBS_Monitor 이미 존재"
  exit 0
fi

# 생성
mid="$(pactl load-module module-null-sink \
  sink_name=OBS_Monitor \
  sink_properties=device.description=OBS_Monitor)" \
  || err "OBS_Monitor 생성 실패"

# 모니터 소스 준비 대기 (최대 10초)
ready=0
for _ in {1..50}; do
  pactl list short sources | awk '{print $2}' | grep -Fxq "OBS_Monitor.monitor" && { ready=1; break; } || sleep 0.2
done
[[ "$ready" -eq 1 ]] || err "OBS_Monitor.monitor 확인 실패 (module $mid)"

ok "Created: OBS_Monitor + OBS_Monitor.monitor"
