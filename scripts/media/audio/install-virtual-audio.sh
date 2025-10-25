#!/usr/bin/env bash
# user systemd 서비스로 로그인 시 자동으로
# 1) OBS_Monitor null-sink 생성
# 2) OBS_VirtualMic 생성
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
ensure_user_systemd_ready

UNIT_DIR="${XDG_CONFIG_HOME}/systemd/user"
mkdir -p "${UNIT_DIR}"

SVC_MON="create-obs-monitor-sink.service"
SVC_MIC="create-obs-virtual-mic.service"

cat >"${UNIT_DIR}/${SVC_MON}" <<EOF
[Unit]
Description=Create OBS monitor sink (OBS_Monitor)

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

systemctl --user daemon-reload
systemctl --user enable "${SVC_MON}" "${SVC_MIC}"
systemctl --user restart "${SVC_MON}"
systemctl --user restart "${SVC_MIC}"

systemctl --user is-enabled "${SVC_MON}" >/dev/null || { echo "failed to enable ${SVC_MON}" >&2; exit 1; }
systemctl --user is-enabled "${SVC_MIC}" >/dev/null || { echo "failed to enable ${SVC_MIC}" >&2; exit 1; }

echo "[OK] user services enabled:"
echo " - ${SVC_MON}"
echo " - ${SVC_MIC}"
