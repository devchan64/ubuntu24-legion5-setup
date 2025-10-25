#!/usr/bin/env bash
# OBS_VirtualMic 생성 (module-virtual-source) + 존재/대기/검증
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh}"

err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*"; exit 1; }
info(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
ok(){ printf "[%s] %s\n" "$(_ts)" "$*"; }

require_cmd pactl
pactl info >/dev/null 2>&1 || err "pactl info 실패: user-bus 또는 PipeWire 계열 데몬 미준비"

SOURCE_BARE="OBS_VirtualMic"
MONITOR="OBS_Monitor.monitor"

# PipeWire 노출 이름 특이 케이스 허용: OBS_VirtualMic, output.OBS_VirtualMic, input.OBS_VirtualMic 등
has_source() {
  pactl list short sources | awk '{print $2}' | grep -E -qx '(^|.*\.)OBS_VirtualMic$'
}

monitor_ready() {
  pactl list short sources | awk '{print $2}' | grep -Fxq "$MONITOR"
}

# 이미 존재하면 성공
if has_source; then
  info "${SOURCE_BARE} 이미 존재"
  exit 0
fi

# 선행 모니터 준비 대기(최대 30초)
ready=0
for _ in {1..150}; do
  if monitor_ready; then ready=1; break; fi
  sleep 0.2
done
[[ "$ready" -eq 1 ]] || err "선행 없음/지연: ${MONITOR}"

# 동일 이름 충돌 모듈만 언로드
while read -r mid rest; do
  if [[ "$rest" == *"module-virtual-source"* && "$rest" == *"source_name=${SOURCE_BARE}"* ]]; then
    pactl unload-module "$mid" || err "충돌 모듈 언로드 실패: $mid"
  fi
done < <(pactl list short modules)

# 생성
mid="$(pactl load-module module-virtual-source \
  source_name="${SOURCE_BARE}" \
  source_properties=device.description="${SOURCE_BARE}" \
  master="${MONITOR}")" || err "${SOURCE_BARE} 생성 실패"

# 생성 확인(최대 30초) — 접두사 유무/변형 모두 허용
okflag=0
for _ in {1..150}; do
  if has_source; then okflag=1; break; fi
  sleep 0.2
done
[[ "$okflag" -eq 1 ]] || {
  echo "[ERROR] ${SOURCE_BARE} 확인 실패 (module ${mid}) — 진단 덤프 시작" >&2
  echo "---- pactl list short sources ----" >&2
  pactl list short sources >&2 || true
  echo "---- pactl list short modules (grep virtual/null) ----" >&2
  pactl list short modules | grep -E 'module-(virtual-source|null-sink)' >&2 || true
  err "${SOURCE_BARE} 소스가 보이지 않습니다"
}

ok "Created: ${SOURCE_BARE}"
