#!/usr/bin/env bash
# file: scripts/codex/install-desktop.sh
set -Eeuo pipefail
set -o errtrace

ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

temporary_dir=""

main() {
  [[ "${EUID}" -ne 0 ]] || err "root로 Codex Desktop을 설치할 수 없습니다. sudo 없이 일반 유저로 실행하세요."

  must_cmd_or_throw curl
  must_cmd_or_throw dpkg
  must_cmd_or_throw dpkg-query
  must_cmd_or_throw mktemp
  must_cmd_or_throw sha256sum
  must_cmd_or_throw apt-get
  must_cmd_or_throw awk

  [[ "$(dpkg --print-architecture)" == "amd64" ]] \
    || err "Codex Desktop은 amd64 환경에서만 설치할 수 있습니다."

  if dpkg-query -W -f='${db:Status-Status}' chatgpt 2>/dev/null | grep -qx 'installed'; then
    log "[codex] Codex Desktop이 이미 설치되어 있습니다: $(dpkg-query -W -f='${Version}' chatgpt)"
    command -v chatgpt >/dev/null || err "Codex Desktop 실행 파일을 찾을 수 없습니다: chatgpt"
    return 0
  fi

  local repository_url="https://persistent.oaistatic.com/codex-app-prod/linux/deb"
  temporary_dir="$(mktemp -d /tmp/legion-codex-desktop-XXXXXX)"
  trap 'rm -rf -- "${temporary_dir}"' EXIT

  local packages_file="${temporary_dir}/Packages"
  local package_file=""
  local package_sha256=""
  local desktop_deb="${temporary_dir}/chatgpt.deb"

  log "[codex] Codex Desktop 패키지 메타데이터 다운로드"
  curl -fsSL "${repository_url}/dists/stable/main/binary-amd64/Packages" -o "${packages_file}"

  package_file="$(awk -F ': ' '/^Filename: / { print $2; exit }' "${packages_file}")"
  package_sha256="$(awk -F ': ' '/^SHA256: / { print $2; exit }' "${packages_file}")"
  [[ -n "${package_file}" ]] || err "Codex Desktop 패키지 경로를 확인할 수 없습니다."
  [[ -n "${package_sha256}" ]] || err "Codex Desktop 패키지 SHA-256을 확인할 수 없습니다."

  log "[codex] Codex Desktop 다운로드"
  curl -fsSL "${repository_url}/${package_file}" -o "${desktop_deb}"
  printf '%s  %s\n' "${package_sha256}" "${desktop_deb}" | sha256sum --check --status \
    || err "Codex Desktop 패키지 SHA-256 검증에 실패했습니다."

  log "[codex] Codex Desktop 설치"
  sudo_run_or_throw apt-get install -y "${desktop_deb}"

  dpkg-query -W -f='${db:Status-Status}' chatgpt 2>/dev/null | grep -qx 'installed' \
    || err "Codex Desktop 설치를 확인할 수 없습니다."
  command -v chatgpt >/dev/null || err "Codex Desktop 실행 파일을 찾을 수 없습니다: chatgpt"

  log "[codex] Codex Desktop 설치 완료: $(dpkg-query -W -f='${Version}' chatgpt)"
}

main "$@"
