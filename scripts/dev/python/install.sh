#!/usr/bin/env bash
# Python toolchain install for Ubuntu 24.04
# - Installs python3, python3-venv, python3-pip
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

_ts(){ date +'%F %T'; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends python3 python3-venv python3-pip

log "Python: $(python3 --version)"
log "Pip: $(python3 -m pip --version)"
