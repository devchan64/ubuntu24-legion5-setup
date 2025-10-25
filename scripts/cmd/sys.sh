#!/usr/bin/env bash
# System bootstrap for Ubuntu 24.04 (Xorg/GNOME tweaks)
# 정책:
#   - 동의는 저장하지 않음. 실행 시마다 "전체 동의" 1회만 질의
#   - --yes 이면 프롬프트 없이 진행
#   - 전제조건 불충족 시 즉시 실패(err), 폴백 없음
set -Eeuo pipefail

sys_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  # -------------------------------
  # Flags
  # -------------------------------
  local AUTO_YES=0
  local OVERRIDE_USER=""
  local argv=("$@")

  local i=0
  while (( i < ${#argv[@]} )); do
    case "${argv[$i]}" in
      --yes) AUTO_YES=1 ;;
      --user) (( i++ )); OVERRIDE_USER="${argv[$i]:-}"; [[ -n "$OVERRIDE_USER" ]] || err "--user 인자가 비었습니다" ;;
      *) ;; # dispatcher 기타 인자 무시
    esac
    (( i++ ))
  done

  # -------------------------------
  # Ask once (non-persistent)
  # -------------------------------
  if (( AUTO_YES != 1 )); then
    if [[ -t 0 || -r /dev/tty ]]; then
      log "[sys] 전체 절차를 실행하기 전에 확인합니다."
      printf "① sys 전체 절차(bootstrap → xorg-ensure → GNOME Nord → Legion HDMI)를 실행하시겠습니까? [y/N] " > /dev/tty
      local ans; read -r ans < /dev/tty || err "입력 실패"
      if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
        warn "[sys] 사용자가 전체 절차를 취소했습니다. 종료합니다."
        return 0
      fi
    else
      err "대화형 입력이 불가합니다. --yes 로 전체 동의를 명시하고 재실행하세요."
    fi
  else
    log "[sys] --yes 지정됨. 프롬프트 없이 진행합니다."
  fi

  # -------------------------------
  # Helpers
  # -------------------------------
  local DESK_USER DESK_UID RUNTIME_DIR BUS_ADDR DISPLAY_VAR XAUTH_FILE
  resolve_user_env() {
    DESK_USER="${OVERRIDE_USER:-${SUDO_USER:-$USER}}"
    DESK_UID="$(id -u "$DESK_USER")" || err "failed to resolve uid for $DESK_USER"
    RUNTIME_DIR="/run/user/${DESK_UID}"
    [[ -d "$RUNTIME_DIR" ]] || err "XDG_RUNTIME_DIR not found: $RUNTIME_DIR (GUI 세션 여부 확인)"
    BUS_ADDR="${RUNTIME_DIR}/bus"
    [[ -S "$BUS_ADDR" || -e "$BUS_ADDR" ]] || err "DBus session bus not found: $BUS_ADDR (로그인된 GNOME 세션 필요)"
    DISPLAY_VAR="${DISPLAY:-}"
    XAUTH_FILE="$(getent passwd "$DESK_USER" | cut -d: -f6)/.Xauthority"
    [[ -n "$DISPLAY_VAR" ]] || err "DISPLAY not set. Xorg GUI 세션에서 실행하세요."
    [[ -r "$XAUTH_FILE" ]] || err "cannot read XAUTHORITY: $XAUTH_FILE"
  }

  local -a USER_ENV
  user_env_export() {
    USER_ENV=( "XDG_RUNTIME_DIR=$RUNTIME_DIR"
               "DBUS_SESSION_BUS_ADDRESS=unix:path=$BUS_ADDR"
               "DISPLAY=$DISPLAY_VAR"
               "XAUTHORITY=$XAUTH_FILE" )
  }

  # -------------------------------
  # ① bootstrap
  # -------------------------------
  log "[sys] bootstrap"
  must_run "scripts/sys/bootstrap.sh" || err "bootstrap 실패"

  # -------------------------------
  # ② xorg-ensure (엄격 모드 아님: x11 없으면 설정만 선적용하고 안내)
  # -------------------------------
  log "[sys] xorg ensure"
  must_run "scripts/sys/xorg-ensure.sh" --user "${OVERRIDE_USER:-${SUDO_USER:-$USER}}" || err "xorg-ensure 실패"

  # -------------------------------
  # ③ GNOME Nord
  # -------------------------------
  require_cmd "python3" || err "python3 not found. 먼저 'dev' 또는 'all'로 python 설치 필요."
  resolve_user_env
  user_env_export
  local nord="${ROOT_DIR}/scripts/sys/gnome-nord-setup.py"
  [[ -f "$nord" ]] || err "gnome-nord-setup.py missing: $nord"

  [[ -d "${ROOT_DIR}/background" ]] || err "background 디렉터리 없음: ${ROOT_DIR}/background"
  pushd "${ROOT_DIR}/background" >/dev/null
  if [[ ! -f "background.jpg" ]]; then
    [[ -f "background1.jpg" ]] || err "background.jpg / background1.jpg 가 모두 없습니다."
    ln -sf background1.jpg background.jpg || err "link background.jpg failed"
  fi
  log "[sys] gnome nord (as ${DESK_USER:-${SUDO_USER:-$USER}})"
  sudo -u "${DESK_USER:-${SUDO_USER:-$USER}}" env "${USER_ENV[@]}" python3 "$nord" || err "gnome nord failed"
  popd >/dev/null

  # -------------------------------
  # ④ Legion HDMI
  # -------------------------------
  resolve_user_env
  user_env_export
  local hdmi="${ROOT_DIR}/scripts/sys/setup-legion-5-hdmi.sh"
  [[ -f "$hdmi" ]] || err "setup-legion-5-hdmi.sh missing: $hdmi"

  local session_id session_type session_state
  # list-sessions 컬럼: 1=SESSION, 2=UID, 3=USER, ...
  session_id="$(loginctl list-sessions --no-legend | awk -v u="$DESK_UID" '$2==u{print $1; exit}')" || true
  [[ -n "${session_id:-}" ]] || err "cannot find systemd session for uid=$DESK_UID (GUI 로그인 상태인지 확인)"
  session_type="$(loginctl show-session "$session_id" -p Type  --value 2>/dev/null || true)"
  session_state="$(loginctl show-session "$session_id" -p State --value 2>/dev/null || true)"
  [[ "$session_type" == "x11" && "$session_state" == "active" ]] || err "Requires active Xorg session. Current: ${session_type:-unknown}/${session_state:-unknown}"

  log "[sys] legion hdmi layout (as ${DESK_USER})"
  sudo -u "$DESK_USER" env "${USER_ENV[@]}" bash "$hdmi" --layout right --rate 165 || {
    local rc=$?
    if [[ $rc -eq 5 ]]; then
      warn "PRIME switched to nvidia. 재부팅 후 다시 실행하세요: scripts/install-all.sh sys"
      exit 5
    fi
    err "setup-legion-5-hdmi.sh failed($rc)"
  }

  log "[sys] done"
}
