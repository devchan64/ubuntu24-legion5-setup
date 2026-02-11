#!/usr/bin/env bash
# file: scripts/dev/editors/install-extensions.sh
#
# /** Domain: Contract: Fail-Fast: SideEffect: */
# - Domain: extensions.txt(SSOT)에 정의된 VS Code 확장을 현재 유저 세션에 설치한다.
# - Contract:
#   - root로 실행 금지(확장은 유저 컨텍스트에 설치)
#   - `code` CLI 가 PATH에 존재해야 함(SSOT: install-vscode.sh / scripts/dev/editors/install-vscode.sh)
#   - extensions.txt 경로는 본 스크립트 디렉토리 기준 고정(cwd 의존 금지)
# - Fail-Fast: 파일/명령 부재, 설치 실패 시 즉시 종료(폴백 없음)
# - SideEffect: `code --install-extension` 실행(유저 프로필 변경)

set -Eeuo pipefail
set -o errtrace

_ts(){ date +'%F %T'; }
log(){ printf "[INFO ][%s] %s\n" "$(_ts)" "$*"; }
err(){ printf "[ERR  ][%s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

# -------------------------------
# Contract: 실행 주체
# -------------------------------
if [[ "${EUID}" -eq 0 ]]; then
  err "root로 VS Code 확장 설치 불가. sudo 없이 일반 유저로 실행하세요."
fi

# -------------------------------
# Contract: 경로(SSOT)
# -------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
EXT_FILE="${SCRIPT_DIR}/extensions.txt"
[[ -f "${EXT_FILE}" ]] || err "extensions.txt not found: ${EXT_FILE}"

# -------------------------------
# Contract: 명령
# -------------------------------
command -v code >/dev/null 2>&1 || err "\`code\` not found. 먼저 VS Code를 설치하고 'code' CLI를 활성화하세요."

# -------------------------------
# Domain: extensions 설치
# -------------------------------
install_extensions_or_throw() {
  local line ext
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Windows CRLF 제거
    ext="${line%%$'\r'}"
    # 공백만 있는 라인 제거
    ext="${ext#"${ext%%[![:space:]]*}"}"
    ext="${ext%"${ext##*[![:space:]]}"}"

    [[ -z "${ext}" ]] && continue
    [[ "${ext}" == \#* ]] && continue

    log "Installing extension: ${ext}"
    code --install-extension "${ext}" --force
  done < "${EXT_FILE}"
}

log "Installing VS Code extensions from: ${EXT_FILE}"
install_extensions_or_throw
log "[OK] Extensions installed."
