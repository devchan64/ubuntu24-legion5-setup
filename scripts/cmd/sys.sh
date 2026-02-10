#!/usr/bin/env bash
# System bootstrap for Ubuntu 24.04 (Xorg/GNOME tweaks)
# 정책:
#   - 동의는 저장하지 않음. 실행 시마다 "전체 동의" 1회만 질의
#   - --yes 이면 프롬프트 없이 진행
#   - 전제조건 불충족 시 즉시 실패(err), 폴백 없음
set -Eeuo pipefail
set -o errtrace

sys_main() {
  local ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/lib/common.sh"

  # -------------------------------
  # Root Contract (auto elevate)
  # -------------------------------
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      local dispatcher="${ROOT_DIR}/scripts/install-all.sh"
      [[ -f "$dispatcher" ]] || err "dispatcher not found: $dispatcher"
      log "[sys] root 권한 필요 → sudo 재실행"
      exec sudo -E bash "$dispatcher" sys "$@"
    fi
    err "sys는 root 권한이 필요하지만 sudo가 없습니다."
  fi

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
      --user)
        (( i++ ))
        OVERRIDE_USER="${argv[$i]:-}"
        [[ -n "$OVERRIDE_USER" ]] || err "--user 인자가 비었습니다"
        ;;
      *) ;; # dispatcher 기타 인자 무시
    esac
    (( i++ ))
  done

  # -------------------------------
  # Ask once (non-persistent)
  # -------------------------------
  if (( AUTO_YES != 1 )); then
    if [[ -r /dev/tty ]]; then
      log "[sys] 전체 절차를 실행하기 전에 확인합니다."
      printf "① sys 전체 절차(bootstrap → xorg-ensure → GNOME Nord → Legion HDMI)를 실행하시겠습니까? [y/N] " > /dev/tty
      local ans
      read -r ans < /dev/tty || err "입력 실패"
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
  # Helpers (SSOT: desktop user + active X11 session)
  # -------------------------------
  local DESK_USER DESK_UID DESK_HOME
  local SESSION_ID SESSION_TYPE SESSION_STATE
  local SESSION_DISPLAY
  local RUNTIME_DIR BUS_ADDR XAUTH_FILE
  local -a USER_ENV

  resolve_desktop_user_or_throw() {
    local u="${OVERRIDE_USER:-${SUDO_USER:-}}"
    if [[ -z "${u:-}" ]]; then
      err "desktop user를 알 수 없습니다. sudo로 실행 중이면 --user <계정> 을 지정하세요."
    fi
    id -u "$u" >/dev/null 2>&1 || err "사용자를 찾을 수 없습니다: $u"

    DESK_USER="$u"
    DESK_UID="$(id -u "$DESK_USER")" || err "failed to resolve uid for $DESK_USER"
    DESK_HOME="$(getent passwd "$DESK_USER" | cut -d: -f6)"
    [[ -n "${DESK_HOME:-}" && -d "$DESK_HOME" ]] || err "HOME 디렉터리를 찾을 수 없습니다: user=$DESK_USER home=${DESK_HOME:-unset}"
  }

  resolve_active_x11_session_or_throw() {
    local sid="" type="" state=""
    # list-sessions 컬럼: 1=SESSION, 2=UID, 3=USER, ...
    while read -r s u user _; do
      [[ "${u:-}" == "$DESK_UID" ]] || continue
      [[ "${user:-}" == "$DESK_USER" ]] || continue

      type="$(loginctl show-session "$s" -p Type --value 2>/dev/null || true)"
      state="$(loginctl show-session "$s" -p State --value 2>/dev/null || true)"

      if [[ "$type" == "x11" && "$state" == "active" ]]; then
        sid="$s"
        SESSION_TYPE="$type"
        SESSION_STATE="$state"
        break
      fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null || true)

    [[ -n "${sid:-}" ]] || err "active Xorg(x11) 세션을 찾지 못했습니다. 로그인 화면 톱니 → 'GNOME on Xorg'로 로그인 후 재실행하세요."
    SESSION_ID="$sid"
  }

  resolve_display_from_user_process_env_or_throw() {
    # Domain: DISPLAY는 systemd session metadata가 아니라, 실제 GUI 프로세스 환경변수에 존재한다.
    local pid=""
    pid="$(pgrep -u "$DESK_USER" -n gnome-shell 2>/dev/null || true)"
    if [[ -z "${pid:-}" ]]; then
      pid="$(pgrep -u "$DESK_USER" -n Xorg 2>/dev/null || true)"
    fi
    [[ -n "${pid:-}" ]] || err "DISPLAY 추출용 GUI 프로세스를 찾지 못했습니다: user=$DESK_USER (gnome-shell/Xorg 프로세스 확인 필요)"

    local env_file="/proc/${pid}/environ"
    [[ -r "$env_file" ]] || err "cannot read process environ: $env_file (pid=$pid user=$DESK_USER)"

    local d=""
    d="$(tr '\0' '\n' < "$env_file" | awk -F= '$1=="DISPLAY"{print $2; exit}')" || true
    if [[ -z "${d:-}" ]]; then
      err "DISPLAY를 확인할 수 없습니다: user=$DESK_USER pid=$pid
- hint: echo \$DISPLAY (현재 쉘=${DISPLAY:-unset})
- hint: sudo -u $DESK_USER env | grep ^DISPLAY=
- hint: tr \"\\0\" \"\\n\" < /proc/$pid/environ | grep ^DISPLAY="
    fi

    SESSION_DISPLAY="$d"
  }

  resolve_xauthority_from_user_process_env_or_throw() {
    # Domain: XAUTHORITY는 systemd session metadata가 아니라, 실제 GUI 프로세스 환경변수에 존재한다.
    local pid=""
    pid="$(pgrep -u "$DESK_USER" -n gnome-shell 2>/dev/null || true)"
    if [[ -z "${pid:-}" ]]; then
      pid="$(pgrep -u "$DESK_USER" -n Xorg 2>/dev/null || true)"
    fi
    [[ -n "${pid:-}" ]] || err "XAUTHORITY 추출용 GUI 프로세스를 찾지 못했습니다: user=$DESK_USER"

    local env_file="/proc/${pid}/environ"
    [[ -r "$env_file" ]] || err "cannot read process environ: $env_file (pid=$pid user=$DESK_USER)"

    local xa=""
    xa="$(tr '\0' '\n' < "$env_file" | awk -F= '$1=="XAUTHORITY"{print $2; exit}')" || true

    if [[ -n "${xa:-}" && -e "$xa" ]]; then
      XAUTH_FILE="$xa"
      return 0
    fi

    local cand1="/run/user/${DESK_UID}/gdm/Xauthority"
    if [[ -e "$cand1" ]]; then
      XAUTH_FILE="$cand1"
      return 0
    fi

    err "XAUTHORITY를 확인할 수 없습니다: user=$DESK_USER pid=$pid
- hint: sudo -u $DESK_USER env | grep ^XAUTHORITY=
- hint: tr \"\\0\" \"\\n\" < /proc/$pid/environ | grep ^XAUTHORITY=
- hint: ls -al /run/user/${DESK_UID}/gdm/ /home/${DESK_USER}/"
  }

  resolve_user_env_or_throw() {
    RUNTIME_DIR="/run/user/${DESK_UID}"
    [[ -d "$RUNTIME_DIR" ]] || err "XDG_RUNTIME_DIR not found: $RUNTIME_DIR (GUI 세션 여부 확인)"

    BUS_ADDR="${RUNTIME_DIR}/bus"
    [[ -S "$BUS_ADDR" || -e "$BUS_ADDR" ]] || err "DBus session bus not found: $BUS_ADDR (로그인된 GNOME 세션 필요)"

    resolve_xauthority_from_user_process_env_or_throw

    USER_ENV=(
      "XDG_RUNTIME_DIR=$RUNTIME_DIR"
      "DBUS_SESSION_BUS_ADDRESS=unix:path=$BUS_ADDR"
      "DISPLAY=$SESSION_DISPLAY"
      "XAUTHORITY=$XAUTH_FILE"
    )
  }

  ensure_nvidia_stack_installed_or_throw() {
    # Domain: Legion HDMI는 NVIDIA stack prerequisite.
    # SideEffect: missing이면 설치 시도 후 reboot 요구.
    require_cmd "xrandr" || err "xrandr not found"

    if command -v nvidia-smi >/dev/null 2>&1; then
      return 0
    fi

    log "[sys] NVIDIA 스택 미설치 감지(nvidia-smi 없음) → 설치 시도"
    if ! command -v ubuntu-drivers >/dev/null 2>&1; then
      log "[sys] ubuntu-drivers 없음 → ubuntu-drivers-common 설치"
      apt-get update -y || err "apt-get update failed"
      apt-get install -y ubuntu-drivers-common || err "install ubuntu-drivers-common failed"
    fi

    ubuntu-drivers devices >/dev/null 2>&1 || err "ubuntu-drivers devices failed"
    ubuntu-drivers autoinstall || err "ubuntu-drivers autoinstall failed"

    warn "[sys] NVIDIA 드라이버 설치 완료. 재부팅 후 다시 실행하세요: ./scripts/install-all.sh sys"
    exit 5
  }

  assert_nvidia_kernel_loaded_or_throw() {
    # Domain: 커널 드라이버 활성 여부는 userspace(nvidia-smi) 또는 lspci가 SSOT.
    if command -v nvidia-smi >/dev/null 2>&1; then
      nvidia-smi >/dev/null 2>&1 && return 0
    fi

    if lspci -k 2>/dev/null | grep -A3 -E 'NVIDIA' | grep -q 'Kernel driver in use: nvidia'; then
      return 0
    fi

    err "NVIDIA 커널 드라이버가 활성화되지 않았습니다.
- 확인: lspci -k | grep -A3 NVIDIA
- 권장: sudo reboot
- 그래도 실패 시: sudo ubuntu-drivers autoinstall"
  }

  assert_nvidia_runtime_ready_or_throw() {
    # Contract: HDMI 절차는 NVIDIA userspace + PRIME 도구가 준비되어야 한다.
    if ! command -v nvidia-smi >/dev/null 2>&1; then
      err "NVIDIA 스택이 설치되지 않았습니다(nvidia-smi 없음).
- 권장: sudo ubuntu-drivers autoinstall && sudo reboot
- 확인: ubuntu-drivers devices"
    fi

    assert_nvidia_kernel_loaded_or_throw

    if ! command -v prime-select >/dev/null 2>&1; then
      err "NVIDIA PRIME 도구가 없습니다(prime-select 없음).
- 권장: sudo apt install -y ubuntu-drivers-common
- 또는: sudo ubuntu-drivers autoinstall && sudo reboot"
    fi
  }

  resolve_desktop_user_or_throw
  resolve_active_x11_session_or_throw
  resolve_display_from_user_process_env_or_throw
  resolve_user_env_or_throw

  # -------------------------------
  # ① bootstrap
  # -------------------------------
  log "[sys] bootstrap"
  must_run "scripts/sys/bootstrap.sh" || err "bootstrap 실패"

  # -------------------------------
  # ② xorg-ensure
  # -------------------------------
  log "[sys] xorg ensure"
  must_run "scripts/sys/xorg-ensure.sh" --user "$DESK_USER" || err "xorg-ensure 실패"

  # -------------------------------
  # ③ GNOME Nord
  # -------------------------------
  require_cmd "python3" || err "python3 not found. 먼저 'dev' 또는 'all'로 python 설치 필요."
  local nord="${ROOT_DIR}/scripts/sys/gnome-nord-setup.py"
  [[ -f "$nord" ]] || err "gnome-nord-setup.py missing: $nord"

  [[ -d "${ROOT_DIR}/background" ]] || err "background 디렉터리 없음: ${ROOT_DIR}/background"
  pushd "${ROOT_DIR}/background" >/dev/null
  if [[ ! -f "background.jpg" ]]; then
    [[ -f "background1.jpg" ]] || err "background.jpg / background1.jpg 가 모두 없습니다."
    ln -sf background1.jpg background.jpg || err "link background.jpg failed"
  fi

  log "[sys] gnome nord (as ${DESK_USER})"
  sudo -u "$DESK_USER" env "${USER_ENV[@]}" python3 "$nord" || err "gnome nord failed"
  popd >/dev/null

  # -------------------------------
  # ④ Legion HDMI
  # -------------------------------
  local hdmi="${ROOT_DIR}/scripts/sys/setup-legion-5-hdmi.sh"
  [[ -f "$hdmi" ]] || err "setup-legion-5-hdmi.sh missing: $hdmi"

  [[ "$SESSION_TYPE" == "x11" && "$SESSION_STATE" == "active" ]] || err "Requires active Xorg session. Current: ${SESSION_TYPE:-unknown}/${SESSION_STATE:-unknown}"

  ensure_nvidia_stack_installed_or_throw
  assert_nvidia_runtime_ready_or_throw

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

# [ReleaseNote] sys: auto-sudo via dispatcher(sys token preserved); DISPLAY/XAUTHORITY from gnome-shell/Xorg environ; NVIDIA auto-install then reboot; fix kernel loaded detection

sys_main "$@"
