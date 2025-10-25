#!/usr/bin/env bash
# Enable user audio units for OBS (run in GUI user session)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

# root 금지
[[ "${EUID:-$(id -u)}" -ne 0 ]] || err "root로 실행하지 마세요. 일반 사용자 GUI 세션 터미널에서 실행하세요."

# user D-Bus 필수
uid="$(id -u)"
rtd="/run/user/${uid}"
[[ -S "${rtd}/bus" ]] || err "user D-Bus(${rtd}/bus) 미검출. 데스크톱 세션의 사용자 터미널에서 실행하세요."

# pactl/pipewire 검사(명확한 실패)
require_cmd systemctl
require_cmd pactl
pactl info >/dev/null 2>&1 || err "pactl 응답 없음. 사용자 오디오 세션(PipeWire/Pulse) 활성 필요."

# 유닛 생성 및 활성화
bash "${REPO_ROOT}/scripts/media/audio/install-virtual-audio.sh"
bash "${REPO_ROOT}/scripts/media/audio/echo-cancel.sh"

log "[OK] OBS 오디오 유닛/에코캔슬 설정 완료"
