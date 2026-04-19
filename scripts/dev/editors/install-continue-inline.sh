#!/usr/bin/env bash
# Configure Continue for VS Code inline autocomplete-focused defaults.
# Policy: no fallbacks, exit on error
set -Eeuo pipefail

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 VS Code 확장 설치/설정 불가. sudo 없이 일반 유저로 실행하세요."

  require_cmd code
  require_cmd python3

  local extension_id="Continue.continue"
  local settings_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User"
  local settings_file="${settings_dir}/settings.json"

  if code --list-extensions | grep -Fxq "${extension_id}"; then
    log "[continue] extension already installed: ${extension_id}"
  else
    log "[continue] VS Code extension 설치: ${extension_id}"
    code --install-extension "${extension_id}" --force
  fi

  mkdir -p "${settings_dir}"
  if [[ ! -f "${settings_file}" ]]; then
    printf '{}\n' > "${settings_file}"
  fi

  log "[continue] VS Code 사용자 설정 업데이트"
  python3 - "${settings_file}" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
try:
    raw = settings_path.read_text(encoding="utf-8")
    data = json.loads(raw) if raw.strip() else {}
except FileNotFoundError:
    data = {}

if not isinstance(data, dict):
    raise RuntimeError("settings.json must contain a JSON object")

updates = {
    "editor.inlineSuggest.enabled": True,
    "continue.disableQuickFix": True,
    "continue.enableNextEdit": False,
    "continue.enableQuickActions": False,
    "continue.enableTabAutocomplete": True,
    "continue.pauseCodebaseIndexOnStart": True,
    "continue.showInlineTip": False,
}

data.update(updates)
settings_path.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY

  log "[continue] 완료"
  log "[continue] install-all.sh dev/all 실행 시 Continue 인라인 자동완성 설정이 함께 적용됩니다."
}

main "$@"
