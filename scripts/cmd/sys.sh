#!/usr/bin/env bash
set -Eeuo pipefail

sys_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  log "[sys] bootstrap"
  must_run "scripts/sys/bootstrap.sh"

  log "[sys] xorg ensure"
  must_run "scripts/sys/xorg-ensure.sh"

  # GNOME Nord: user session에서 실행 권장
  if [[ -f "${ROOT_DIR}/scripts/sys/gnome-nord-setup.py" ]]; then
    log "[sys] gnome nord"
    pushd "${ROOT_DIR}/background" >/dev/null
    if [[ ! -f "background.jpg" ]]; then
      warn "background.jpg not found; linking background1.jpg -> background.jpg"
      ln -sf background1.jpg background.jpg || err "link background.jpg failed"
    fi
    python3 "${ROOT_DIR}/scripts/sys/gnome-nord-setup.py" || err "gnome nord failed"
    popd >/dev/null
  else
    err "gnome-nord-setup.py missing"
  fi

  # Legion HDMI
  if [[ -f "${ROOT_DIR}/scripts/sys/setup-legion-5-hdmi.sh" ]]; then
    log "[sys] legion hdmi layout"
    bash "${ROOT_DIR}/scripts/sys/setup-legion-5-hdmi.sh" --layout right --rate 165 || {
      rc=$?
      if [[ $rc -eq 5 ]]; then
        warn "PRIME switched to nvidia. Reboot then re-run: scripts/install-all.sh sys"
        exit 5
      fi
      err "setup-legion-5-hdmi.sh failed($rc)"
    }
  else
    err "setup-legion-5-hdmi.sh missing"
  fi

  log "[sys] done"
}
