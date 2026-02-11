#!/usr/bin/env bash
# file: scripts/security/install.sh
# Security toolchain install (Ubuntu 24.04)
# - clamav / clamav-freshclam: daemon-based updates (no manual freshclam)
# - rkhunter, lynis
# Policy: no fallbacks, fail-fast
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  ensure_root_or_reexec_with_sudo_or_throw "$@"

  require_ubuntu_2404
  must_cmd_or_throw apt-get
  must_cmd_or_throw systemctl

  local sec_state_dir="${PROJECT_STATE_DIR}/security"
  mkdir -p "${sec_state_dir}"

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # SideEffect: apt sources may be rewritten (repo/keyring singleton)
  apt_fix_vscode_repo_singleton

  log "[sec] install packages"
  apt-get update -y
  apt-get install -y --no-install-recommends \
    clamav clamav-freshclam rkhunter lynis

  sec_ensure_clamav_dirs_or_throw
  sec_enable_freshclam_daemon_or_throw
  sec_prime_rkhunter_db_or_throw

  must_cmd_or_throw lynis
  log "[sec] done: clamav(freshclam daemon), rkhunter, lynis"
}

# ─────────────────────────────────────────────────────────────
# Business: ClamAV dirs
# SideEffect: mkdir/chown
# ─────────────────────────────────────────────────────────────
sec_ensure_clamav_dirs_or_throw() {
  install -d -o clamav -g clamav -m 0755 /var/log/clamav
  install -d -o clamav -g clamav -m 0755 /var/lib/clamav
}

# ─────────────────────────────────────────────────────────────
# Business: freshclam daemon (SSOT)
# Contract: manual freshclam is forbidden (lock/log conflicts)
# SideEffect: systemctl enable/restart, journalctl read(best-effort)
# ─────────────────────────────────────────────────────────────
sec_enable_freshclam_daemon_or_throw() {
  log "[sec] enable/restart clamav-freshclam.service"
  systemctl enable clamav-freshclam.service
  systemctl restart clamav-freshclam.service
  systemctl is-active --quiet clamav-freshclam.service || err "clamav-freshclam.service not active"

  # best-effort: show recent update logs
  journalctl -u clamav-freshclam -n 50 --no-pager || true
}

# ─────────────────────────────────────────────────────────────
# Business: rkhunter DB
# SideEffect: writes rkhunter prop DB
# ─────────────────────────────────────────────────────────────
sec_prime_rkhunter_db_or_throw() {
  must_cmd_or_throw rkhunter
  log "[sec] rkhunter prop DB init (rkhunter --propupd)"
  rkhunter --propupd -q || err "rkhunter --propupd failed"
}

main "$@"
