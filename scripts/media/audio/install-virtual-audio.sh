#!/usr/bin/env bash
set -Eeuo pipefail

# Domain: Media/Audio virtual routing for OBS (monitor sink + virtual mic)
# Contract: pactl must exist and must be able to connect to the user audio server
# Fail-Fast: no fallback; if PipeWire/Pulse session isn't ready -> throw
# SideEffect: installs pulseaudio-utils (pactl), installs/enables user systemd units, loads pactl modules

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

install_obs_virtual_audio_main() {
  install_obs_virtual_audio_contract_validate_entry_or_throw
  install_obs_virtual_audio_execute_or_throw
  log "[audio] done"
}

# ─────────────────────────────────────────────────────────────
# Top: business logic
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_contract_validate_entry_or_throw() {
  install_obs_virtual_audio_contract_reject_root_or_throw
  install_obs_virtual_audio_ensure_pactl_or_throw
  install_obs_virtual_audio_contract_validate_pactl_can_connect_or_throw
}

install_obs_virtual_audio_execute_or_throw() {
  install_obs_virtual_audio_install_user_units_or_throw
  install_obs_virtual_audio_enable_user_units_or_throw
  install_obs_virtual_audio_validate_devices_or_throw
}

# ─────────────────────────────────────────────────────────────
# Middle: adapters / IO
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_ensure_pactl_or_throw() {
  if command -v pactl >/dev/null 2>&1; then
    log "[audio] pactl OK"
    return 0
  fi

  require_cmd sudo
  sudo -v >/dev/null

  log "[audio] pactl not found. Installing pulseaudio-utils..."
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends pulseaudio-utils

  command -v pactl >/dev/null 2>&1 || err "pactl 설치 실패: pulseaudio-utils"
  log "[audio] pactl installed"
}

install_obs_virtual_audio_contract_validate_pactl_can_connect_or_throw() {
  # Contract: user session audio server reachable
  if pactl info >/dev/null 2>&1; then
    return 0
  fi

  # PipeWire 기반일 가능성이 높으므로 상태 힌트 제공(하지만 폴백 없음)
  log "[audio] pactl exists but cannot connect to audio server"
  log "[audio] hint: systemctl --user status pipewire pipewire-pulse wireplumber"
  err "pactl 연결 실패: 사용자 오디오 세션(PipeWire/Pulse)이 준비되지 않음"
}

install_obs_virtual_audio_install_user_units_or_throw() {
  local unit_dir="${HOME}/.config/systemd/user"
  mkdir -p "${unit_dir}"

  cat > "${unit_dir}/create-obs-monitor-sink.service" <<'EOF'
[Unit]
Description=Create OBS monitor null sink (OBS_Monitor)
After=pipewire.service pipewire-pulse.service wireplumber.service pulseaudio.service
Wants=pipewire.service pipewire-pulse.service wireplumber.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/env bash -Eeuo pipefail -c '\
  if ! command -v pactl >/dev/null 2>&1; then echo "pactl not found" >&2; exit 1; fi; \
  pactl info >/dev/null; \
  pactl list short sinks | grep -q "^.*[[:space:]]OBS_Monitor[[:space:]]" && exit 0; \
  pactl load-module module-null-sink sink_name=OBS_Monitor sink_properties=device.description=OBS_Monitor >/dev/null; \
  for i in $(seq 1 40); do \
    pactl list short sources | grep -q "^.*[[:space:]]OBS_Monitor\\.monitor[[:space:]]" && exit 0; \
    sleep 0.25; \
  done; \
  echo "OBS_Monitor.monitor not found" >&2; exit 1; \
'

[Install]
WantedBy=default.target
EOF

  cat > "${unit_dir}/create-obs-virtual-mic.service" <<'EOF'
[Unit]
Description=Create OBS virtual mic source (OBS_VirtualMic)
After=create-obs-monitor-sink.service
Requires=create-obs-monitor-sink.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/env bash -Eeuo pipefail -c '\
  if ! command -v pactl >/dev/null 2>&1; then echo "pactl not found" >&2; exit 1; fi; \
  pactl info >/dev/null; \
  pactl list short sources | awk '"'"'$2=="OBS_VirtualMic" || $2=="output.OBS_VirtualMic"{found=1} END{exit found?0:1}'"'"' && exit 0; \
  pactl load-module module-virtual-source source_name=OBS_VirtualMic master=OBS_Monitor.monitor source_properties=device.description=OBS_VirtualMic >/dev/null; \
  for i in $(seq 1 40); do \
    pactl list short sources | awk '"'"'$2=="OBS_VirtualMic" || $2=="output.OBS_VirtualMic"{found=1} END{exit found?0:1}'"'"' && exit 0; \
    sleep 0.25; \
  done; \
  echo "OBS_VirtualMic not found" >&2; exit 1; \
'

[Install]
WantedBy=default.target
EOF
}

install_obs_virtual_audio_enable_user_units_or_throw() {
  require_cmd systemctl

  systemctl --user daemon-reload
  systemctl --user enable --now create-obs-monitor-sink.service
  systemctl --user enable --now create-obs-virtual-mic.service
}

install_obs_virtual_audio_validate_devices_or_throw() {
  pactl list short sinks | grep -q "[[:space:]]OBS_Monitor[[:space:]]" \
    || err "OBS_Monitor sink 생성 실패"

  pactl list short sources | grep -q "[[:space:]]OBS_Monitor\\.monitor[[:space:]]" \
    || err "OBS_Monitor.monitor source 생성 실패"

  pactl list short sources | awk '$2=="OBS_VirtualMic" || $2=="output.OBS_VirtualMic"{found=1} END{exit found?0:1}' \
    || err "OBS_VirtualMic source 생성 실패"

  log "[audio] devices ready: OBS_Monitor / OBS_VirtualMic"
}

# ─────────────────────────────────────────────────────────────
# Contract validation (near entry)
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_contract_reject_root_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "root로 직접 실행하지 마세요. 일반 사용자로 실행하세요(내부에서 sudo를 사용합니다)."
  fi
}

install_obs_virtual_audio_main "$@"

# [ReleaseNote] breaking: pactl 자동 설치(pulseaudio-utils) + OBS_VirtualMic name(output.*) 허용
