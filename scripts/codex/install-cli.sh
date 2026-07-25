#!/usr/bin/env bash
# file: scripts/codex/install-cli.sh
set -Eeuo pipefail
set -o errtrace

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 Codex CLI를 설치할 수 없습니다. sudo 없이 일반 유저로 실행하세요."

  must_cmd_or_throw curl
  must_cmd_or_throw sh

  local install_dir="${CODEX_INSTALL_DIR:-${HOME}/.local/bin}"
  local codex_bin="${install_dir}/codex"

  if [[ -x "${codex_bin}" ]]; then
    log "[codex] Codex CLI가 이미 설치되어 있습니다: ${codex_bin}"
    "${codex_bin}" --version
    return 0
  fi

  log "[codex] Codex CLI 설치: ${codex_bin}"
  mkdir -p "${install_dir}"
  curl -fsSL https://chatgpt.com/codex/install.sh \
    | CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR="${install_dir}" sh

  [[ -x "${codex_bin}" ]] || err "Codex CLI 설치 후 실행 파일을 찾을 수 없습니다: ${codex_bin}"

  log "[codex] Codex CLI 설치 완료"
  "${codex_bin}" --version
}

main "$@"
