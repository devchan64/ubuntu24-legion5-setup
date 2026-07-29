#!/usr/bin/env bash
# file: scripts/codex/remote-control-service.sh
set -Eeuo pipefail
set -o errtrace

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 Codex 사용자 서비스를 설정할 수 없습니다. sudo 없이 일반 유저로 실행하세요."

  must_cmd_or_throw systemctl

  local install_dir="${CODEX_INSTALL_DIR:-${HOME}/.local/bin}"
  local codex_bin="${install_dir}/codex"
  local user_systemd_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
  local service_name="codex-remote-control.service"
  local service_file="${user_systemd_dir}/${service_name}"

  [[ -x "${codex_bin}" ]] || err "Codex 실행 파일이 없거나 실행할 수 없습니다: ${codex_bin}"
  systemctl --user show-environment >/dev/null \
    || err "systemd 사용자 매니저에 연결할 수 없습니다. 로그인 사용자 세션에서 실행하세요."

  log "[codex] 사용자 systemd 유닛 작성: ${service_file}"
  mkdir -p "${user_systemd_dir}"
  cat > "${service_file}" <<EOF
[Unit]
Description=Codex Remote Control

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${codex_bin} remote-control start
ExecStop=${codex_bin} remote-control stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  chmod 0644 "${service_file}"

  log "[codex] systemd 사용자 매니저 재로드"
  systemctl --user daemon-reload

  log "[codex] Codex 원격 제어 서비스 활성화 및 시작"
  systemctl --user enable --now "${service_name}"

  log "[codex] Codex 원격 제어 서비스 상태 확인"
  systemctl --user status "${service_name}" --no-pager --full
}

main "$@"
