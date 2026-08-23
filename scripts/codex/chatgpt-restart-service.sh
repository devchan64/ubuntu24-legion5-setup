#!/usr/bin/env bash
# file: scripts/codex/chatgpt-restart-service.sh
set -Eeuo pipefail
set -o errtrace

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 ChatGPT 재시작 서비스를 설정할 수 없습니다. sudo 없이 일반 유저로 실행하세요."

  must_cmd_or_throw chatgpt
  must_cmd_or_throw pkill
  must_cmd_or_throw systemctl

  local user_systemd_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
  local service_name="chatgpt-restart.service"
  local service_file="${user_systemd_dir}/${service_name}"

  [[ -x "/usr/bin/chatgpt" ]] || err "ChatGPT 실행 파일을 찾을 수 없습니다: /usr/bin/chatgpt"
  systemctl --user show-environment >/dev/null \
    || err "systemd 사용자 매니저에 연결할 수 없습니다. 로그인한 그래픽 사용자 세션에서 실행하세요."

  log "[codex] ChatGPT 재시작 사용자 systemd 유닛 작성: ${service_file}"
  mkdir -p "${user_systemd_dir}"
  cat > "${service_file}" <<'EOF'
[Unit]
Description=ChatGPT Desktop 자동 재시작
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStartPre=-/usr/bin/pkill -x ChatGPT
ExecStart=/usr/bin/chatgpt
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

  chmod 0644 "${service_file}"

  log "[codex] systemd 사용자 매니저 재로드"
  systemctl --user daemon-reload

  log "[codex] ChatGPT 재시작 서비스 활성화 및 시작"
  systemctl --user enable --now "${service_name}"

  log "[codex] ChatGPT 재시작 서비스 상태 확인"
  systemctl --user status "${service_name}" --no-pager --full
}

main "$@"
