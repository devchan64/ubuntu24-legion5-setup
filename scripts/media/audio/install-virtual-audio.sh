#!/usr/bin/env bash
# user systemd 서비스로 로그인 시 자동으로
# 1) OBS_Monitor null-sink 생성
# 2) OBS_VirtualMic 생성
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# 공통 유틸 로드
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

# Xorg 불필요: 오디오 설정은 사용자 세션/버스만 필요
require_cmd systemctl
require_cmd pactl
ensure_user_systemd_ready

# user D-Bus가 실제로 존재해야 함
uid="$(id -u)"
rtd="/run/user/${uid}"
[[ -S "${rtd}/bus" ]] || err "user D-Bus(${rtd}/bus) 미검출. GUI 사용자 세션 터미널에서 실행하세요."

UNIT_DIR="${XDG_CONFIG_HOME}/systemd/user"
mkdir -p "${UNIT_DIR}"

SVC_MON="create-obs-monitor-sink.service"
SVC_MIC="create-obs-virtual-mic.service"

# ── 서비스 유닛 생성(ExecStart는 현재 리포지토리의 생성 스크립트 사용)
cat >"${UNIT_DIR}/${SVC_MON}" <<EOF
[Unit]
Description=Create OBS monitor sink (OBS_Monitor)
After=pipewire.service pipewire-pulse.service wireplumber.service
Wants=pipewire.service pipewire-pulse.service wireplumber.service

[Service]
Type=oneshot
ExecStart=${REPO_ROOT}/scripts/media/audio/create-obs-monitor-sink.sh
WorkingDirectory=${REPO_ROOT}
Environment=XDG_STATE_HOME=${XDG_STATE_HOME}

[Install]
WantedBy=default.target
EOF

cat >"${UNIT_DIR}/${SVC_MIC}" <<EOF
[Unit]
Description=Create OBS virtual mic (OBS_VirtualMic)
After=${SVC_MON}
Wants=${SVC_MON}

[Service]
Type=oneshot
ExecStart=${REPO_ROOT}/scripts/media/audio/create-obs-virtual-mic.sh
WorkingDirectory=${REPO_ROOT}
Environment=XDG_STATE_HOME=${XDG_STATE_HOME}

[Install]
WantedBy=default.target
EOF

# ── user 서비스 등록/실행
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service
# pipewire-pulse는 배포에 따라 없을 수 있으므로 enable만 시도하고 실패하면 경고
if systemctl --user list-unit-files | grep -q '^pipewire-pulse\.service'; then
  systemctl --user enable --now pipewire-pulse.service || warn "pipewire-pulse.service 활성화 실패(배포 구성을 확인하세요)."
fi
systemctl --user enable --now wireplumber.service

systemctl --user enable "${SVC_MON}" "${SVC_MIC}"
systemctl --user restart "${SVC_MON}"
systemctl --user restart "${SVC_MIC}"

systemctl --user is-enabled "${SVC_MON}" >/dev/null || { echo "failed to enable ${SVC_MON}" >&2; exit 1; }
systemctl --user is-enabled "${SVC_MIC}" >/dev/null || { echo "failed to enable ${SVC_MIC}" >&2; exit 1; }

echo "[OK] user services enabled:"
echo " - ${SVC_MON}"
echo " - ${SVC_MIC}"
echo "참고: 문제가 있으면 아래를 확인하세요."
echo " - pactl list short sinks | grep OBS_Monitor"
echo " - pactl list short sources | grep -E 'OBS_Monitor\\.monitor|OBS_VirtualMic|output\\.OBS_VirtualMic'"
