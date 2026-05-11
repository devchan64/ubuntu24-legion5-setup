#!/usr/bin/env bash
# file: scripts/media/camera/install-ai-virtual-cam.sh
set -Eeuo pipefail
set -o errtrace

# Domain: Media/Linux 카메라 처리 도구(ai-virtual-cam) 설치
# Contract: 공식 저장소를 기준으로 설치하며, 공식 진입점(bin/avc setup) 검증 실패 시 즉시 중단

AI_VIRTUAL_CAM_REPO_URL="https://github.com/devchan64/ai-virtual-cam.git"
AI_VIRTUAL_CAM_INSTALL_DIR="${HOME}/.local/src/ai-virtual-cam"

install_ai_virtual_cam_main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  install_ai_virtual_cam_contract_validate_entry_or_throw
  install_ai_virtual_cam_execute_or_throw

  log "[media/camera] ai-virtual-cam 설치 완료"
}

install_ai_virtual_cam_contract_validate_entry_or_throw() {
  install_ai_virtual_cam_contract_reject_root_or_throw
  must_cmd_or_throw sudo
  must_cmd_or_throw git
  must_cmd_or_throw bash
}

install_ai_virtual_cam_execute_or_throw() {
  sudo -v >/dev/null

  if [[ -d "${AI_VIRTUAL_CAM_INSTALL_DIR}/.git" ]]; then
    log "[media/camera] 기존 저장소 업데이트: ${AI_VIRTUAL_CAM_INSTALL_DIR}"
    git -C "${AI_VIRTUAL_CAM_INSTALL_DIR}" fetch --tags --prune
    git -C "${AI_VIRTUAL_CAM_INSTALL_DIR}" pull --ff-only
  else
    log "[media/camera] 저장소 클론: ${AI_VIRTUAL_CAM_REPO_URL}"
    mkdir -p "$(dirname "${AI_VIRTUAL_CAM_INSTALL_DIR}")"
    git clone --depth=1 "${AI_VIRTUAL_CAM_REPO_URL}" "${AI_VIRTUAL_CAM_INSTALL_DIR}"
  fi

  [[ -x "${AI_VIRTUAL_CAM_INSTALL_DIR}/bin/avc" ]] \
    || err "설치 경로 검증 실패: ${AI_VIRTUAL_CAM_INSTALL_DIR}/bin/avc 실행 파일이 없습니다."

  log "[media/camera] Linux 경로 사용(v4l2loopback): ai-virtual-cam은 OBS 실행/연동을 수행하지 않습니다."
  log "[media/camera] 의존성 설치 실행: ./bin/avc setup"
  (cd "${AI_VIRTUAL_CAM_INSTALL_DIR}" && ./bin/avc setup)
}

install_ai_virtual_cam_contract_reject_root_or_throw() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    err "root로 실행할 수 없습니다. 일반 사용자로 실행하세요."
  fi
}

install_ai_virtual_cam_main "$@"
