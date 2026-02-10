#!/usr/bin/env bash
# Install VS Code extensions from extensions.txt
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

_ts(){ date +'%F %T'; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || err "root로 VS Code 확장 설치 불가. sudo 없이 일반 유저로 실행하세요."

EXT_FILE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)/extensions.txt"

command -v code >/dev/null 2>&1 || err "\`code\` 명령이 없습니다. 먼저 install-vscode.sh 를 실행하세요."
[[ -f "${EXT_FILE}" ]] || err "extensions.txt 가 없습니다: ${EXT_FILE}"

while IFS= read -r ext; do
  ext="${ext%%$'\r'}"
  [[ -z "$ext" ]] && continue
  [[ "$ext" =~ ^# ]] && continue
  log "Installing extension: $ext"
  code --install-extension "$ext" --force
done < "${EXT_FILE}"

log "[OK] Extensions installed."
