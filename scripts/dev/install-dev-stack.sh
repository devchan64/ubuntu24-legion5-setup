#!/usr/bin/env bash
# Developer stack installer: Python + Node + VS Code (+ Docker if present)
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

_ts(){ date +'%F %T'; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd -P)"

run(){ local rel="$1"; shift || true; bash "${ROOT_DIR}/${rel}" "$@"; }

# Python (root required)
if [[ "$EUID" -ne 0 ]]; then
  err "root 권한이 필요합니다. sudo로 다시 실행하세요: sudo bash scripts/dev/install-dev-stack.sh"
fi

run scripts/dev/python/install.sh

# Node (user env)
su - "${SUDO_USER:-$USER}" -c "bash '${ROOT_DIR}/scripts/dev/node/install.sh'"

# VS Code (root)
run scripts/dev/editors/install-vscode.sh

# Extensions (user)
su - "${SUDO_USER:-$USER}" -c "bash '${ROOT_DIR}/scripts/dev/editors/install-extensions.sh'"

log "[OK] Dev stack installed."
