#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo -e "[$(basename "$0")] $*"; }
err(){ echo -e "[$(basename "$0")][ERROR] $*" 1>&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || err "Missing: $1"; }

as_root(){
  if (( EUID != 0 )); then
    command -v sudo >/dev/null 2>&1 || err "sudo is required"
    exec sudo -E bash "$0" "$@"
  fi
}

acquire_lock(){
  local lock="${1:?lockfile path required}"
  exec 9>"$lock"
  flock -n 9 || err "Another process is running (lock: $lock)"
}

assert_ubuntu(){
  [[ -f /etc/os-release ]] || err "Not an Ubuntu-like system"
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || err "This script targets Ubuntu (found: ${ID:-unknown})"
}

print_x_session_type(){ echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"; }
