#!/usr/bin/env bash
# OBS Studio 설치(Flatpak) + 기본 권한 검증
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../" >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_xorg_or_die
require_cmd flatpak

# Flatpak remote 확인/추가
if ! flatpak remotes --columns=name | grep -Fxq "flathub"; then
  log "Add flathub remote"
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# OBS 설치
if ! flatpak info com.obsproject.Studio >/dev/null 2>&1; then
  log "Install OBS Studio (Flatpak)"
  flatpak install -y flathub com.obsproject.Studio
else
  log "OBS already installed → updating"
  flatpak update -y com.obsproject.Studio
fi

# 기본 런처 가용성 확인
flatpak info com.obsproject.Studio >/dev/null 2>&1 || err "OBS not found after install."

log "OBS installation verified (Flatpak)."
log "Run: flatpak run com.obsproject.Studio"
