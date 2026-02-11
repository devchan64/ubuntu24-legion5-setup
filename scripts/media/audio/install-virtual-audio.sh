#!/usr/bin/env bash
# file: scripts/media/audio/install-virtual-audio.sh
set -Eeuo pipefail
set -o errtrace

# Domain: Media/Audio virtual routing for OBS (monitor sink + virtual mic)
# Contract: pactl must exist and must be able to connect to the user audio server
# Fail-Fast: no fallback; if PipeWire/Pulse session isn't ready -> throw
# SideEffect: installs pulseaudio-utils (pactl), installs/enables user systemd units, loads pactl modules

install_obs_virtual_audio_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  install_obs_virtual_audio_contract_validate_entry_or_throw
  install_obs_virtual_audio_execute_or_throw

  log "[audio] done"
}

# ─────────────────────────────────────────────────────────────
# Top: Business
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_contract_validate_entry_or_throw() {
  install_obs_virtual_audio_contract_reject_root_or_throw
  install_obs_virtual_audio_ensure_pactl_or_throw
  install_obs_virtual_audio_contract_validate_pactl_can_connect_or_throw
  install_obs_virtual_audio_contract_validate_user_systemd_or_throw
}

install_obs_virtual_audio_execute_or_throw() {
  install_obs_virtual_audio_install_user_units_or_throw
  install_obs_virtual_audio_enable_user_units_or_throw
  install_obs_virtual_audio_validate_devices_or_throw
}

# ─────────────────────────────────────────────────────────────
# Middle: IO / Adapters
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_ensure_pactl_or_throw() {
  if command -v pactl >/dev/null 2>&1; then
    log "[audio] pactl OK"
    return 0
  fi

  must_cmd_or_throw sudo
  sudo -v >/dev/null

  log "[audio] pactl not found → install: pulseaudio-utils"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends pulseaudio-utils

  command -v pactl >/dev/null 2>&1 || err "pactl install failed: pulseaudio-utils"
  log "[audio] pactl installed"
}

install_obs_virtual_audio_contract_validate_pactl_can_connect_or_throw() {
  # Contract: user session audio server reachable
  if pactl info >/dev/null 2>&1; then
    return 0
  fi

  log "[audio] pactl exists but cannot connect to audio server"
  log "[audio] hint: systemctl --user status pipewire pipewire-pulse wireplumber"
  err "pactl connect failed: user audio session (PipeWire/Pulse) not ready"
}

install_obs_virtual_audio_contract_validate_user_systemd_or_throw() {
  must_cmd_or_throw systemctl
  # Contract: user systemd reachable (GUI session / lingering / proper DBUS)
  if systemctl --user is-system-running >/dev/null 2>&1; then
    return 0
  fi

  log "[audio] systemctl --user is not available"
  log "[audio] hint: loginctl show-user $USER -p Linger; echo $XDG_RUNTIME_DIR"
  err "user systemd unavailable: cannot install/enable user units"
}

install_obs_virtual_audio_install_user_units_or_throw() {
  local unit_dir="${HOME}/.config/systemd/user"
  mkdir -p "${unit_dir}"

  install_obs_virtual_audio_write_unit_create_monitor_sink_or_throw "${unit_dir}"
  install_obs_virtual_audio_write_unit_create_virtual_mic_or_throw "${unit_dir}"
}

install_obs_virtual_audio_enable_user_units_or_throw() {
  systemctl --user daemon-reload
  systemctl --user enable --now create-obs-monitor-sink.service
  systemctl --user enable --now create-obs-virtual-mic.service
}

install_obs_virtual_audio_validate_devices_or_throw() {
  pactl list short sinks | grep -q "[[:space:]]OBS_Monitor[[:space:]]" \
    || err "OBS_Monitor sink not found"

  pactl list short sources | grep -q "[[:space:]]OBS_Monitor\\.monitor[[:space:]]" \
    || err "OBS_Monitor.monitor source not found"

  pactl list short sources \
    | awk '$2=="OBS_VirtualMic" || $2=="output.OBS_VirtualMic"{found=1} END{exit found?0:1}' \
    || err "OBS_VirtualMic source not found"

  log "[audio] devices ready: OBS_Monitor / OBS_VirtualMic"
}

# ─────────────────────────────────────────────────────────────
# Bottom: Unit templates (Config)
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_write_unit_create_monitor_sink_or_throw() {
  local unit_dir="${1:?unit_dir required}"

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
}

install_obs_virtual_audio_write_unit_create_virtual_mic_or_throw() {
  local unit_dir="${1:?unit_dir required}"

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

# ─────────────────────────────────────────────────────────────
# Contract validation (near entry)
# ─────────────────────────────────────────────────────────────
install_obs_virtual_audio_contract_reject_root_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "do not run as root. run as a normal user (this script uses sudo internally)."
  fi
}

install_obs_virtual_audio_main "$@"

# [ReleaseNote] breaking: repo-root self-resolve → LEGION_SETUP_ROOT SSOT, user-systemd contract added
