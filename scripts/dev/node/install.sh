#!/usr/bin/env bash
# Node.js toolchain via NVM
# - Installs NVM if absent
# - Installs Node (default 22) and enables corepack (pnpm/yarn)
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

_ts(){ date +'%F %T'; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

NODE_VERSION="${NODE_VERSION:-22}"

# Ensure curl, ca-certificates
if ! command -v curl >/dev/null 2>&1; then
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || err "curl 설치를 위해 root 권한이 필요합니다."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends curl ca-certificates
fi

# Install NVM if needed
if [[ ! -d "${HOME}/.nvm" ]]; then
  log "Installing NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Load NVM
export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1090
. "${NVM_DIR}/nvm.sh"

# Install Node
log "Installing Node v${NODE_VERSION}"
nvm install "${NODE_VERSION}"
nvm alias default "${NODE_VERSION}"
nvm use default

# Enable corepack (pnpm/yarn)
log "Enable corepack"
corepack enable

node -v
npm -v
