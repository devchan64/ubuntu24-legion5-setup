#!/usr/bin/env bash
# file: scripts/codex/remote-control-linger.sh
set -Eeuo pipefail
set -o errtrace

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 Codex 사용자 linger를 설정할 수 없습니다. sudo 없이 일반 유저로 실행하세요."

  must_cmd_or_throw loginctl

  local user_name="${USER:-}"
  [[ -n "${user_name}" ]] || user_name="$(id -un)"
  [[ -n "${user_name}" ]] || err "현재 사용자 이름을 확인할 수 없습니다."

  log "[codex] 재부팅 후 사용자 systemd 매니저 유지를 설정: ${user_name}"
  loginctl enable-linger "${user_name}"

  local linger=""
  linger="$(loginctl show-user "${user_name}" -p Linger --value)" \
    || err "사용자 linger 상태 확인 실패: ${user_name}"
  [[ "${linger}" == "yes" ]] || err "사용자 linger 활성화 실패: ${user_name} Linger=${linger:-unknown}"

  log "[codex] 사용자 linger 활성화 확인: ${user_name}"
}

main "$@"
