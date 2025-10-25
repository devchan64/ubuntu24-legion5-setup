#!/usr/bin/env bash
# 보안 스캔 요약 리포터
# - scan.sh 실행(또는 기존 결과) 기반으로 간단 요약(JSON/텍스트) 출력
# - ClamAV / rkhunter / chkrootkit의 핵심 시그널 파싱
# 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail

. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." >/dev/null 2>&1 && pwd -P)/lib/common.sh"

require_cmd jq
require_cmd grep
require_cmd awk
require_cmd date

STATE_DIR="${XDG_STATE_HOME}/ubuntu24-legion5-setup/security/$(date +%Y%m%d)"
mkdir -p "${STATE_DIR}"

RUN_SCAN="${RUN_SCAN:-true}"
TEXT_OUT="${TEXT_OUT:-true}"
JSON_OUT="${JSON_OUT:-true}"

# 1) 스캔 실행(선택)
if [[ "${RUN_SCAN}" == "true" ]]; then
  log "Run security scan (scripts/security/scan.sh)"
  bash "${REPO_ROOT}/scripts/security/scan.sh" | tee "${STATE_DIR}/scan.raw.log"
else
  [[ -f "${STATE_DIR}/scan.raw.log" ]] || err "No existing scan log at ${STATE_DIR}/scan.raw.log; set RUN_SCAN=true"
fi

RAW="${STATE_DIR}/scan.raw.log"

# 2) 간단 파싱 규칙
clam_found=$(grep -E "FOUND$" -c "${RAW}" || true)
rkh_warn=$(grep -E "Warning:" -c "${RAW}" || true)
chk_inf=$(grep -E "INFECTED" -c "${RAW}" || true)

# 3) 요약 JSON 작성
jq -n \
  --arg date "$(date +%F\ %T)" \
  --arg raw "${RAW}" \
  --argjson clam "${clam_found:-0}" \
  --argjson rkh "${rkh_warn:-0}" \
  --argjson chk "${chk_inf:-0}" \
  '{time:$date, raw:$raw, clam_found:$clam, rkhunter_warnings:$rkh, chkrootkit_infected:$chk}' \
  | tee "${STATE_DIR}/summary.json" >/dev/null

# 4) 텍스트 요약
if [[ "${TEXT_OUT}" == "true" ]]; then
  echo "==== Security Scan Summary ($(date +%F\ %T)) ====" | tee "${STATE_DIR}/summary.txt"
  echo "Raw Log: ${RAW}" | tee -a "${STATE_DIR}/summary.txt"
  echo "ClamAV  FOUND: ${clam_found}" | tee -a "${STATE_DIR}/summary.txt"
  echo "rkhunter WARN: ${rkh_warn}"   | tee -a "${STATE_DIR}/summary.txt"
  echo "chkrootkit INF: ${chk_inf}"   | tee -a "${STATE_DIR}/summary.txt"
fi

# 5) JSON 출력
if [[ "${JSON_OUT}" == "true" ]]; then
  cat "${STATE_DIR}/summary.json"
fi

log "[OK] Summary written to: ${STATE_DIR}/summary.{json,txt}"
