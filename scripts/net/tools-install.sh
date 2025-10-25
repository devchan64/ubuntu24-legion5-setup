#!/usr/bin/env bash
# 네트워크 진단/테스트 도구 일괄 설치 (Ubuntu 24.04 전용)
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

# ─────────────────────────────────────────────
# 공통 유틸 로드
# ─────────────────────────────────────────────
ROOT_DIR="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
# shellcheck disable=SC1090
source "${ROOT_DIR}/lib/common.sh"

main() {
  # 권한/OS 가드
  ensure_root_or_reexec_with_sudo "$@"
  require_ubuntu_2404
  require_cmd apt-get

  export DEBIAN_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a

  # APT VSCode repo 충돌(Deb822/.list 혼재, Signed-By 상이) 사전 정리
  apt_fix_vscode_repo_singleton

  # ─────────────────────────────────────────────
  # 설치 패키지 정의
  # ─────────────────────────────────────────────
  local -a PKGS=(
    # 기본 네트워킹/전송
    curl
    wget
    iproute2          # ip, ss 등
    iputils-ping      # ping
    net-tools         # ifconfig, netstat(구버전; 참고용)
    ethtool
    whois
    traceroute
    mtr-tiny          # mtr 경량 패키지
    tcpdump
    nmap

    # DNS/이름해결
    bind9-dnsutils    # dig, nslookup

    # 성능/부하 테스트
    iperf3

    # HTTP 클라이언트
    httpie

    # 무선(노트북 환경 보조)
    wireless-tools    # iwconfig 등(구식이지만 보조용)
  )

  # ─────────────────────────────────────────────
  # 설치
  # ─────────────────────────────────────────────
  log "[net] 네트워크 도구 설치를 시작합니다."
  apt-get update -y
  apt-get install -y --no-install-recommends "${PKGS[@]}"

  # ─────────────────────────────────────────────
  # 설치 검증(주요 명령어 버전/존재 확인)
  # ─────────────────────────────────────────────
  check_cmd() { command -v "$1" >/dev/null 2>&1 || err "설치 후 명령을 찾을 수 없습니다: $1"; }

  # 핵심 바이너리 존재 확인
  check_cmd ip
  check_cmd ss
  check_cmd ping
  check_cmd dig
  check_cmd traceroute
  check_cmd mtr
  check_cmd tcpdump
  check_cmd nmap
  check_cmd iperf3
  check_cmd curl
  check_cmd http

  # 버전/상태 로깅(실패해도 중단 X)
  {
    log "[net] iproute2: $(ip -V || true)"
    log "[net] ping: $(ping -V 2>&1 | head -n1 || true)"
    log "[net] dig: $(dig +short -v 2>&1 | head -n1 || true)"
    log "[net] traceroute: $(traceroute --version 2>&1 | head -n1 || true)"
    log "[net] mtr: $(mtr --version 2>&1 | head -n1 || true)"
    log "[net] tcpdump: $(tcpdump --version 2>&1 | head -n1 || true)"
    log "[net] nmap: $(nmap --version 2>&1 | head -n1 || true)"
    log "[net] iperf3: $(iperf3 --version 2>&1 | head -n1 || true)"
    log "[net] curl: $(curl --version 2>/dev/null | head -n1 || true)"
    log "[net] httpie: $(http --version 2>&1 | head -n1 || true)"
  } || true

  # ─────────────────────────────────────────────
  # 마무리 안내
  # ─────────────────────────────────────────────
  log "[net] 네트워크 도구 설치 완료."
  cat <<'TIP'
[바로 사용 예]
  • IP/라우팅:    ip a    | ip r
  • 포트 소켓:    ss -tulpn
  • DNS 질의:     dig example.com +trace
  • 경로 추적:    traceroute 8.8.8.8
  • 왕복 지연:    mtr -rw 1.1.1.1
  • 패킷 캡처:    sudo tcpdump -i any -nn port 443
  • 포트 스캔:    nmap -sV -Pn example.com
  • 대역폭 테스트: iperf3 -s   (서버) / iperf3 -c <서버IP> (클라이언트)
  • HTTP 테스트:  http GET https://example.com
TIP
}

main "$@"
