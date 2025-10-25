#!/usr/bin/env bash
# GNOME on Xorg 보장 스크립트 (비대화형)
# - GDM: Wayland 비활성, 기본 세션 gnome-xorg.desktop (멱등)
# - 기본 동작: x11 세션이 없어도 설정만 적용하고 종료(재부팅은 사용자가 나중에 수행)
# - 옵션:
#     --user <name>   : 세션 점검 대상 사용자(기본: SUDO_USER 또는 USER)
#     --reboot-now    : 설정 적용 직후 즉시 재부팅
#     --strict        : x11 세션이 없으면 실패로 종료
# 정책: 폴백 없음, 실패 즉시 종료
set -Eeuo pipefail

_ts() { date +'%F %T'; }
log()  { printf "[%s] %s\n" "$(_ts)" "$*"; }
warn() { printf "[WARN %s] %s\n" "$(_ts)" "$*" >&2; }
err()  { printf "[ERROR %s] %s\n" "$(_ts)" "$*" >&2; exit 1; }

require_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || err "root 권한이 필요합니다. sudo로 실행하세요."; }

OVERRIDE_USER=""
REBOOT_NOW=0
STRICT_MODE=0
while (( $# )); do
  case "$1" in
    --user) shift; OVERRIDE_USER="${1:-}"; [[ -n "$OVERRIDE_USER" ]] || err "--user 인자가 비었습니다" ;;
    --reboot-now) REBOOT_NOW=1 ;;
    --strict) STRICT_MODE=1 ;;
    *) err "알 수 없는 옵션: $1" ;;
  esac
  shift || true
done

ensure_gdm_xorg() {
  [[ -x /usr/sbin/gdm3 ]] || err "gdm3 미설치"
  local cfg=/etc/gdm3/custom.conf
  [[ -f "$cfg" ]] || err "$cfg 없음 (gdm3 기본 설정 필요)"

  # 최초 1회 백업
  if [[ ! -f "${cfg}.bak" ]]; then
    cp -a "$cfg" "${cfg}.bak" || err "백업 생성 실패: ${cfg}.bak"
  fi

  # WaylandEnable=false 보장
  if grep -Eq '^\s*#?\s*WaylandEnable\s*=' "$cfg"; then
    sed -i 's/^\s*#\?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$cfg"
  else
    printf '\nWaylandEnable=false\n' >> "$cfg"
  fi

  # DefaultSession=gnome-xorg.desktop 보장
  if grep -Eq '^\s*#?\s*DefaultSession\s*=' "$cfg"; then
    sed -i 's/^\s*#\?\s*DefaultSession\s*=.*/DefaultSession=gnome-xorg.desktop/' "$cfg"
  else
    printf 'DefaultSession=gnome-xorg.desktop\n' >> "$cfg"
  fi
}

pick_x11_session_for_user() {
  local user="$1"
  local sid type state remote
  while read -r sid _ uid name; do
    [[ "$name" == "$user" ]] || continue
    type="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
    state="$(loginctl show-session "$sid" -p State --value 2>/dev/null || true)"
    remote="$(loginctl show-session "$sid" -p Remote --value 2>/dev/null || true)"
    if [[ "$type" == "x11" && "$state" == "active" && "$remote" != "yes" ]]; then
      echo "$sid"
      return 0
    fi
  done < <(loginctl list-sessions --no-legend || true)
  return 1
}

assert_or_note_session() {
  local target_user="${OVERRIDE_USER:-${SUDO_USER:-$USER}}"
  if sid="$(pick_x11_session_for_user "$target_user")"; then
    log "x11 세션 확인: user=${target_user}, session=${sid}"
    return 0
  fi
  if (( STRICT_MODE == 1 )); then
    err "x11 GUI 세션을 찾지 못했습니다. (SSH/TTY 또는 Wayland 가능)
- 로그인 화면 톱니 → 'GNOME on Xorg' 선택 후 로그인
- --strict 없이 실행하면 설정만 먼저 적용합니다."
  fi
  warn "x11 GUI 세션이 없어도 계속 진행합니다(설정만 적용). 재부팅 후 'GNOME on Xorg'로 로그인하세요."
}

main() {
  require_root
  log "GDM Xorg 설정 보장(멱등)"
  ensure_gdm_xorg

  log "현재 세션 타입 점검"
  assert_or_note_session

  if (( REBOOT_NOW == 1 )); then
    warn "요청에 따라 즉시 재부팅합니다 (--reboot-now)."
    systemctl reboot
    exit 0
  fi

  log "완료: Wayland 비활성 및 기본 Xorg 세션 설정이 반영되었습니다."
  warn "반영을 위해 재부팅 후 로그인 화면에서 'GNOME on Xorg'를 선택해 로그인하세요."
}

main "$@"
