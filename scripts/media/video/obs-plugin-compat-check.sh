#!/usr/bin/env bash
# OBS 플러그인 호환성 체크(Flatpak 기준)
# - Flatpak OBS 존재 확인
# - 플러그인 경로 검사(~/.var/app/.../obs-studio/plugins)
# - 시스템(apt) OBS 설치 충돌 가능성 경고
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_cmd flatpak

APP_ID="com.obsproject.Studio"
FLAT_HOME="${HOME}/.var/app/${APP_ID}"
PLUG_DIR="${FLAT_HOME}/config/obs-studio/plugins"

# 1) Flatpak OBS 설치 확인
flatpak info "${APP_ID}" >/dev/null 2>&1 || err "Flatpak OBS(${APP_ID})가 설치되지 않았습니다. 먼저 설치하세요."

# 2) APT OBS 충돌 경고
if dpkg -l | grep -E '^ii\s+obs-studio\b' >/dev/null 2>&1; then
  warn "시스템(apt) OBS가 설치되어 있습니다. Flatpak과 플러그인 경로/권한이 다르므로 혼용 시 호환 문제가 생길 수 있습니다."
fi

# 3) 플러그인 디렉토리 검사
if [[ ! -d "${PLUG_DIR}" ]]; then
  warn "플러그인 디렉토리가 없습니다: ${PLUG_DIR}"
  echo "Flatpak OBS는 샌드박스 내 경로에만 접근합니다. Flatpak용 빌드/설치 방법을 참고하세요."
  exit 0
fi

echo "== OBS Plugin Directory (Flatpak) =="
echo "${PLUG_DIR}"
echo

found_any=0
shopt -s nullglob
for plug in "${PLUG_DIR}"/*; do
  if [[ -d "$plug" ]]; then
    found_any=1
    pname="$(basename "$plug")"
    so_count=$(find "$plug" -maxdepth 2 -type f -name "*.so" | wc -l | tr -d ' ')
    echo "- ${pname}: ${so_count} binaries"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  warn "감지된 플러그인이 없습니다. Flatpak 호환 플러그인을 해당 디렉토리에 설치해야 합니다."
else
  echo
  echo "[OK] 플러그인 디렉토리 스캔 완료."
fi
