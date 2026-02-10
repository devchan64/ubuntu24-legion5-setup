#!/usr/bin/env bash
# Legion 5 HDMI setup for Ubuntu 24.04 (Xorg + NVIDIA open kernel driver)
# - PRIME auto-switch to nvidia (reboot required → exit 5)
# - External (HDMI/DP) primary, prefer REQ_RATE if available
# - Robust xrandr parsing (no silent fallbacks)
# - Layout uses explicit pos (stable). DO NOT re-apply --scale (GNOME/Mutter owns Transform)

set -Eeuo pipefail
set -o errtrace
trap 'echo "[ERR] line:${LINENO} cmd:${BASH_COMMAND:-}" >&2; exit 1' ERR

usage() {
  cat <<'USAGE'
Usage:
  setup-legion-5-hdmi.sh
    [--layout right|left|mirror|external-only]
    [--rate 165]
    [--dpms-off]
    [--no-switch-prime]
    [--enable-prime-sync]
    [--verbose]

Layout semantics (SSOT):
  - right:  External on LEFT (pos 0), Internal on RIGHT (pos external_logical_width)
  - left:   Internal on LEFT (pos 0), External on RIGHT (pos internal_logical_width)

Notes:
  - GNOME/Mutter owns Transform(scale). This script does NOT set --scale.
USAGE
}

# ----- Legion 5 defaults -----
LAYOUT="${LAYOUT_OVERRIDE:-right}"             # right|left|mirror|external-only
REQ_RATE="${RATE_OVERRIDE:-165}"               # prefer 165Hz; if unsupported, use preferred(+)
DPMS_OFF="${DPMS_OFF_OVERRIDE:-1}"             # 1 = disable DPMS/screensaver
SWITCH_PRIME="${SWITCH_PRIME_OVERRIDE:-1}"     # 1 = auto switch to nvidia
ENABLE_PRIME_SYNC="${PRIME_SYNC_OVERRIDE:-1}"  # 1 = try enabling PRIME Sync
VERBOSE="${VERBOSE_OVERRIDE:-0}"

# ----- CLI overrides -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --layout)            LAYOUT="${2:?}"; shift 2;;
    --rate)              REQ_RATE="${2:?}"; shift 2;;
    --dpms-off)          DPMS_OFF="1"; shift;;
    --no-switch-prime)   SWITCH_PRIME="0"; shift;;
    --enable-prime-sync) ENABLE_PRIME_SYNC="1"; shift;;
    --verbose)           VERBOSE="1"; shift;;
    -h|--help)           usage; exit 0;;
    *) echo "[ERR] Unknown arg: $1"; usage; exit 1;;
  esac
done

log()  { if [[ "${VERBOSE:-0}" == "1" ]]; then echo "[INFO]" "$@"; fi; }
warn() { echo "[WARN]" "$@" >&2; }
err()  { echo "[ERR]" "$@" >&2; exit 1; }

# ----- Preconditions -----
if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
  err "Requires Xorg (x11). Current: ${XDG_SESSION_TYPE:-unknown}"
fi

for c in xrandr prime-select awk grep sed tr pgrep; do
  command -v "$c" >/dev/null 2>&1 || err "'$c' not found"
done

export __GLX_VENDOR_LIBRARY_NAME="nvidia"

# PRIME must be nvidia
CURRENT_PRIME="$(prime-select query 2>/dev/null || true)"
if [[ "${CURRENT_PRIME:-}" != "nvidia" ]]; then
  if [[ "${SWITCH_PRIME:-1}" == "1" ]]; then
    echo "[ACT] Switching PRIME to 'nvidia' (sudo prime-select nvidia)"
    if sudo prime-select nvidia; then
      echo "[NEED REBOOT] PRIME switched to 'nvidia'. Reboot, then rerun this script."
      exit 5
    fi
    err "'prime-select nvidia' failed. Check driver installation and secure boot status."
  fi
  err "PRIME is '${CURRENT_PRIME:-unset}'. Re-run without --no-switch-prime or set manually."
fi

# NVIDIA provider present?
if ! xrandr --listproviders | grep -qi 'NVIDIA'; then
  err "NVIDIA provider not detected. Ensure NVIDIA driver is installed/loaded."
fi

# ----- Detect outputs -----
XR="$(xrandr --query)"
INTERNAL="$(printf '%s\n' "$XR" | awk '/^eDP[-0-9]*[[:space:]]+connected/{print $1; exit}')"
[[ -n "${INTERNAL:-}" ]] || err "Internal (eDP) output not found or disconnected."

declare -a EXTS=()
mapfile -t EXTS < <(printf '%s\n' "$XR" | awk '/^(HDMI|DP)(-[0-9]+)?[[:space:]]+connected/ {print $1}')
EXTS=($(printf "%s\n" "${EXTS[@]}" | grep -v "^${INTERNAL}\$" || true))
[[ ${#EXTS[@]} -gt 0 ]] || err "No external HDMI/DP connected."
EXT="${EXTS[0]}"
log "Internal: $INTERNAL, External: $EXT"

# ----- Robust external block extraction -----
EXT_BLOCK="$(printf '%s\n' "$XR" | awk -v ext="$EXT" '
  $1==ext && $2=="connected" {blk=1; next}
  blk && $0 !~ /^[[:space:]]/ {exit}
  blk {print}
')"
[[ -n "${EXT_BLOCK:-}" ]] || err "Cannot read mode list for $EXT"

mapfile -t EXT_MODES < <(printf '%s\n' "$EXT_BLOCK" | awk '/^[[:space:]]+[0-9]+x[0-9]+/ {print $1}')
[[ ${#EXT_MODES[@]} -gt 0 ]] || { echo "[ERR] No numeric modes found for $EXT" >&2; printf '%s\n' "$EXT_BLOCK" >&2; exit 1; }

if [[ "${VERBOSE:-0}" == "1" ]]; then
  echo "[INFO] $EXT available modes:"; printf '  %s\n' "${EXT_MODES[@]}"
fi

PREFERRED_MODE="$(printf '%s\n' "$EXT_BLOCK" | awk '/^[[:space:]]+[0-9]+x[0-9]+/ && /\+/{print $1; exit}')"
if [[ -z "${PREFERRED_MODE:-}" ]]; then
  PREFERRED_MODE="${EXT_MODES[0]}"
  log "No (+) preferred mark; using first mode: $PREFERRED_MODE"
else
  log "Preferred(+) mode: $PREFERRED_MODE"
fi

SELECTED_MODE="$PREFERRED_MODE"
SELECTED_RATE=""

if [[ -n "${REQ_RATE:-}" ]]; then
  RATE_RE="$(printf ' %s\\.00| %s( |$)' "$REQ_RATE" "$REQ_RATE")"
  ML="$(printf '%s\n' "$EXT_BLOCK" | grep -E "$RATE_RE" | awk '/^[[:space:]]+[0-9]+x[0-9]+/ {print $1; exit}' || true)"
  if [[ -n "${ML:-}" ]]; then
    SELECTED_MODE="$ML"
    SELECTED_RATE="$REQ_RATE"
    log "Found ${REQ_RATE}Hz: mode=$SELECTED_MODE"
  else
    log "Requested ${REQ_RATE}Hz not found; using preferred: $PREFERRED_MODE"
  fi
fi

if ! printf '%s\n' "${EXT_MODES[@]}" | grep -qx "$SELECTED_MODE"; then
  echo "[ERR] Mode '$SELECTED_MODE' not available on $EXT" >&2
  echo "[HINT] Available modes on $EXT:" >&2
  printf '  %s\n' "${EXT_MODES[@]}" >&2
  exit 1
fi

# ----- Layout helpers (SSOT: xrandr --listmonitors geometry) -----
read_monitor_logical_width_or_throw() {
  # Contract: xrandr --listmonitors line contains geometry token like:
  #   6144/600x3456/340+0+0
  # We do NOT assume fixed field index.
  local out="$1"
  local line geo w

  line="$(xrandr --listmonitors | awk -v o="$out" '$0 ~ ("[[:space:]]" o "$") {print; exit}')" \
    || err "xrandr --listmonitors failed"
  [[ -n "${line:-}" ]] || err "cannot find monitor in xrandr --listmonitors: $out"

  geo="$(printf '%s\n' "$line" | awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9]+\/[0-9]+x[0-9]+\/[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
      }
    }
  ')" || true

  [[ -n "${geo:-}" ]] || err "cannot parse geometry token from xrandr --listmonitors line: $line"

  w="$(printf '%s' "$geo" | awk -F'/' '{print $1}')"
  [[ "$w" =~ ^[0-9]+$ ]] || err "invalid logical width from geometry: out=$out geo=$geo line=$line"
  printf '%s' "$w"
}

apply_layout_external_left_internal_right_or_throw() {
  local ext="$1" int="$2" mode="$3" rate="${4:-}"
  local ex_w
  # Apply mode first, then read logical width (GNOME may re-assert Transform)
  xrandr --output "$ext" --mode "$mode" ${rate:+--rate "$rate"} --primary
  xrandr --output "$int" --auto

  ex_w="$(read_monitor_logical_width_or_throw "$ext")"
  xrandr --output "$ext" --pos 0x0 --primary
  xrandr --output "$int" --pos "${ex_w}x0"
}

apply_layout_internal_left_external_right_or_throw() {
  local ext="$1" int="$2" mode="$3" rate="${4:-}"
  local ix_w
  xrandr --output "$int" --auto
  xrandr --output "$ext" --mode "$mode" ${rate:+--rate "$rate"} --primary

  ix_w="$(read_monitor_logical_width_or_throw "$int")"
  xrandr --output "$int" --pos 0x0
  xrandr --output "$ext" --pos "${ix_w}x0" --primary
}

apply_mirror_or_throw() {
  local ext="$1" int="$2" mode="$3" rate="${4:-}"
  xrandr --output "$int" --mode "$mode" || err "Cannot mirror: $mode unsupported on $int"
  xrandr --output "$ext" --mode "$mode" ${rate:+--rate "$rate"} --primary
  xrandr --output "$int" --same-as "$ext"
}

apply_external_only_or_throw() {
  local ext="$1" int="$2" mode="$3" rate="${4:-}"
  xrandr --output "$int" --off
  xrandr --output "$ext" --mode "$mode" ${rate:+--rate "$rate"} --pos 0x0 --primary
}

# ----- Apply layout -----
case "$LAYOUT" in
  right)
    # SSOT: external LEFT, internal RIGHT
    apply_layout_external_left_internal_right_or_throw "$EXT" "$INTERNAL" "$SELECTED_MODE" "$SELECTED_RATE"
    ;;
  left)
    # SSOT: internal LEFT, external RIGHT
    apply_layout_internal_left_external_right_or_throw "$EXT" "$INTERNAL" "$SELECTED_MODE" "$SELECTED_RATE"
    ;;
  mirror)
    apply_mirror_or_throw "$EXT" "$INTERNAL" "$SELECTED_MODE" "$SELECTED_RATE"
    ;;
  external-only)
    apply_external_only_or_throw "$EXT" "$INTERNAL" "$SELECTED_MODE" "$SELECTED_RATE"
    ;;
  *)
    err "Unknown --layout value: $LAYOUT"
    ;;
esac

# ----- PRIME Sync -----
if [[ "${ENABLE_PRIME_SYNC:-0}" == "1" ]]; then
  if xrandr --prop | grep -q "PRIME Synchronization"; then
    xrandr --output "$INTERNAL" --set "PRIME Synchronization" 1 2>/dev/null || warn "PRIME Sync on $INTERNAL failed"
    xrandr --output "$EXT"      --set "PRIME Synchronization" 1 2>/dev/null || warn "PRIME Sync on $EXT failed"
  else
    warn "'PRIME Synchronization' not exposed; consider kernel param: nvidia-drm.modeset=1"
  fi
fi

# ----- DPMS -----
if [[ "${DPMS_OFF:-0}" == "1" ]]; then
  command -v xset >/dev/null 2>&1 || err "xset not found for --dpms-off"
  xset -dpms
  xset s off
fi

echo "[OK] layout=${LAYOUT}, ext=${EXT}, mode=${SELECTED_MODE}${SELECTED_RATE:+ @${SELECTED_RATE}Hz}, dpms_off=${DPMS_OFF}, prime_sync=${ENABLE_PRIME_SYNC}"
xrandr --listmonitors
