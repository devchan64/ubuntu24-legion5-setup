#!/usr/bin/env bash
# Visual Studio Code install via Microsoft repository
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

_ts(){ date +'%F %T'; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -eq 0 ]] || err "root 권한이 필요합니다. sudo로 다시 실행하세요."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends wget gpg apt-transport-https ca-certificates

install -m 0755 -d /etc/apt/keyrings
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
chmod a+r /etc/apt/keyrings/packages.microsoft.gpg

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
  > /etc/apt/sources.list.d/vscode.list

apt-get update -y
apt-get install -y code

log "Installed VS Code: $(code --version | head -n1)"
