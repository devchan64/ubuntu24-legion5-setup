#!/usr/bin/env bash
# 시스템/자원 모니터링 도구 일괄 설치 (Ubuntu 24.04 전용)
# 정책: 폴백 없음, 실패 즉시 중단
# 사용:
#   sudo bash scripts/ops/monitors-install.sh
set -Eeuo pipefail

# ─────────────────────────────────────────────
# 공통 유틸 로드
# ─────────────────────────────────────────────
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=/dev/null
. "${REPO_ROOT}/lib/common.sh"

# ─────────────────────────────────────────────
# 전제 조건
# ─────────────────────────────────────────────
require_root
require_ubuntu_2404
require_cmd apt-get
require_cmd systemctl

# ─────────────────────────────────────────────
# 설치 패키지
#  - Ubuntu 24.04(Noble) 기준 패키지명
# ─────────────────────────────────────────────
PKGS_COMMON=(
  # CPU/MEM/PROC
  btop            # 현대적 TUI 모니터
  htop            # 고전 TUI 모니터

  # IO/네트워크/디스크
  iotop           # IO top
  iftop           # 인터페이스별 트래픽
  duf             # 디스크 사용량(disk usage/free)
  nmon            # 종합 모니터(TUI)

  # 센서/로그/통계
  lm-sensors      # 온도/팬 센서
  smartmontools   # SMART(disk health)
  sysstat         # sar/iostat/collect
)

PKGS_GPU=(
  nvtop           # GPU TOP (NVIDIA/AMD/Intel)
)

# ─────────────────────────────────────────────
# 설치
# ─────────────────────────────────────────────
log "OPS 모니터링 도구 설치를 시작합니다."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PKGS_COMMON[@]}"

# GPU 유무와 관계없이 nvtop은 유용 → 설치 시도 (GPU 미탑재여도 설치 자체는 가능)
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PKGS_GPU[@]}"

# ─────────────────────────────────────────────
# 서비스/설정
# ─────────────────────────────────────────────

# 1) sysstat 수집 활성화 (sar 등)
if [[ -f /etc/default/sysstat ]]; then
  # ENABLED="true" 로 강제
  sed -Ei 's/^\s*ENABLED\s*=.*/ENABLED="true"/' /etc/default/sysstat
fi
systemctl enable sysstat
systemctl restart sysstat
systemctl is-active --quiet sysstat || err "sysstat 서비스 활성화 실패"

# 2) SMART 데몬 활성화 (기본 설정으로 S.M.A.R.T 모니터링)
# Ubuntu 24.04에서는 smartmontools.service 사용 (smartd는 alias일 수 있음)
if systemctl list-unit-files | grep -q '^smartmontools\.service'; then
  systemctl enable smartmontools.service
  systemctl restart smartmontools.service
  systemctl is-active --quiet smartmontools.service || err "smartmontools.service 활성화 실패"
else
  err "smartmontools.service 유닛을 찾지 못했습니다. smartmontools 패키지 상태를 확인하세요."
fi

# ─────────────────────────────────────────────
# 설치/명령 검증
# ─────────────────────────────────────────────
check_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || err "설치 후 명령을 찾을 수 없습니다: ${c}"
}
check_cmd btop
check_cmd htop
check_cmd iotop
check_cmd iftop
check_cmd duf
check_cmd nmon
check_cmd sensors
check_cmd smartctl
check_cmd sar
check_cmd iostat
check_cmd mpstat
check_cmd nvtop

# ─────────────────────────────────────────────
# 정보 로그 (실패 무시)
# ─────────────────────────────────────────────
{
  log "btop: $(btop --version 2>&1 | head -n1 || true)"
  log "htop: $(htop --version 2>&1 | head -n1 || true)"
  log "iotop: $(iotop --version 2>&1 | head -n1 || true)"
  log "iftop: $(iftop -h 2>&1 | head -n1 || true)"
  log "duf: $(duf --version 2>&1 | head -n1 || true)"
  log "nmon: $(nmon -V 2>&1 | head -n1 || true)"
  log "lm-sensors: $(sensors -v 2>&1 | head -n1 || true)"
  log "smartmontools: $(smartctl -V 2>&1 | head -n1 || true)"
  log "sysstat(sar): $(sar -V 2>&1 | head -n1 || true)"
  if command -v nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA GPU: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true)"
  else
    warn "nvidia-smi 미검출 — NVIDIA GPU가 없거나 드라이버가 설치되지 않았습니다."
  fi
} || true

# ─────────────────────────────────────────────
# 사용 팁
# ─────────────────────────────────────────────
cat <<'TIP'
[바로 사용 예]
  • 종합 모니터(TUI): btop
  • CPU/메모리:       htop
  • GPU:              nvtop
  • 디스크 IO:        iotop
  • 네트워크:         sudo iftop -i <iface>     # 예: iftop -i wlan0
  • 디스크 사용량:    duf
  • SMART 상태:       sudo smartctl -H /dev/nvme0
  • 센서:             sensors
  • 수집 통계(sar):   sar -u 1 5  |  sar -n DEV 1 5  |  iostat -xz 1 3
TIP

log "OPS 모니터링 도구 설치 완료."
