#!/usr/bin/env bash
# file: scripts/security/summarize-last-scan.sh
# 보안 스캔 요약 리포터
# - scan.sh가 생성한 최신 로그(clamav_*.log, rkhunter_*.log) 기반 요약(JSON/텍스트) 출력
# - 정책: 폴백 없음, 실패 즉시 중단
set -Eeuo pipefail
set -o errtrace

main() {
  local root_dir="${LEGION_SETUP_ROOT:?LEGION_SETUP_ROOT required}"
  # shellcheck disable=SC1090
  source "${root_dir}/lib/common.sh"

  must_cmd_or_throw jq
  must_cmd_or_throw grep
  must_cmd_or_throw awk
  must_cmd_or_throw date

  local sec_state_dir="${PROJECT_STATE_DIR:?PROJECT_STATE_DIR required}/security"
  [[ -d "${sec_state_dir}" ]] || err "security state dir not found: ${sec_state_dir}"

  local text_out="${TEXT_OUT:-true}"
  local json_out="${JSON_OUT:-true}"

  local clam_log=""
  local rkh_log=""
  clam_log="$(find_latest_log_or_throw "${sec_state_dir}" 'clamav_*.log')"
  rkh_log="$(find_latest_log_or_throw "${sec_state_dir}" 'rkhunter_*.log')"

  # 핵심 카운트(SSOT: “signal”만 요약)
  local clam_found=0
  clam_found="$(count_clamav_found_best_effort "${clam_log}")"

  local rkh_warn=0
  rkh_warn="$(count_rkhunter_warnings_best_effort "${rkh_log}")"

  # Lynis는 파일을 만들지만, scan.sh에서 경고/오류를 별도 로그로 표준화하지 않으므로
  # 여기서는 “경로 안내”만 포함(폴백 파싱 금지)
  local lynis_report="/var/log/lynis/report.dat"
  local lynis_log="/var/log/lynis/lynis.log"

  local now=""
  now="$(date +'%F %T')"

  local out_dir="${sec_state_dir}/summary"
  mkdir -p "${out_dir}"

  local out_json="${out_dir}/summary_${now//[: ]/_}.json"
  local out_txt="${out_dir}/summary_${now//[: ]/_}.txt"

  write_summary_json_or_throw "${out_json}" "${now}" "${clam_log}" "${rkh_log}" "${clam_found}" "${rkh_warn}" "${lynis_report}" "${lynis_log}"

  if [[ "${text_out}" == "true" ]]; then
    write_summary_text_or_throw "${out_txt}" "${now}" "${clam_log}" "${rkh_log}" "${clam_found}" "${rkh_warn}" "${lynis_report}" "${lynis_log}"
  fi

  if [[ "${json_out}" == "true" ]]; then
    cat "${out_json}"
  fi

  log "[sec/summary] written:"
  log " - ${out_json}"
  if [[ "${text_out}" == "true" ]]; then
    log " - ${out_txt}"
  fi
}

# ─────────────────────────────────────────────────────────────
# Top: Business
# ─────────────────────────────────────────────────────────────
find_latest_log_or_throw() {
  local dir="${1:?dir required}"
  local pattern="${2:?pattern required}"

  local latest=""
  latest="$(ls -1t "${dir}"/${pattern} 2>/dev/null | head -n1 || true)"
  [[ -n "${latest}" && -f "${latest}" ]] || err "no log found: dir=${dir} pattern=${pattern}"
  echo "${latest}"
}

count_clamav_found_best_effort() {
  local clam_log="${1:?clam_log required}"
  # clamscan --infected 출력 포맷 기반: "...: <SIGNATURE> FOUND"
  grep -E " FOUND$" -c "${clam_log}" 2>/dev/null || echo 0
}

count_rkhunter_warnings_best_effort() {
  local rkh_log="${1:?rkh_log required}"
  # rkhunter 출력에 "Warning:" 라인이 포함되는 경우 카운트
  grep -E "^Warning:" -c "${rkh_log}" 2>/dev/null || echo 0
}

write_summary_json_or_throw() {
  local out_json="${1:?out_json required}"
  local now="${2:?now required}"
  local clam_log="${3:?clam_log required}"
  local rkh_log="${4:?rkh_log required}"
  local clam_found="${5:?clam_found required}"
  local rkh_warn="${6:?rkh_warn required}"
  local lynis_report="${7:?lynis_report required}"
  local lynis_log="${8:?lynis_log required}"

  jq -n \
    --arg time "${now}" \
    --arg clam_log "${clam_log}" \
    --arg rkh_log "${rkh_log}" \
    --arg lynis_report "${lynis_report}" \
    --arg lynis_log "${lynis_log}" \
    --argjson clam_found "${clam_found}" \
    --argjson rkhunter_warnings "${rkh_warn}" \
    '{
      time: $time,
      logs: {
        clamav: $clam_log,
        rkhunter: $rkh_log,
        lynis_report: $lynis_report,
        lynis_log: $lynis_log
      },
      signals: {
        clamav_found: $clam_found,
        rkhunter_warnings: $rkhunter_warnings
      }
    }' > "${out_json}"
}

write_summary_text_or_throw() {
  local out_txt="${1:?out_txt required}"
  local now="${2:?now required}"
  local clam_log="${3:?clam_log required}"
  local rkh_log="${4:?rkh_log required}"
  local clam_found="${5:?clam_found required}"
  local rkh_warn="${6:?rkh_warn required}"
  local lynis_report="${7:?lynis_report required}"
  local lynis_log="${8:?lynis_log required}"

  {
    echo "==== Security Scan Summary (${now}) ===="
    echo "ClamAV log:   ${clam_log}"
    echo " - FOUND:     ${clam_found}"
    echo "rkhunter log: ${rkh_log}"
    echo " - WARN:      ${rkh_warn}"
    echo "Lynis report: ${lynis_report}"
    echo "Lynis log:    ${lynis_log}"
  } > "${out_txt}"
}

main "$@"

# [ReleaseNote] breaking: summarize uses PROJECT_STATE_DIR/security logs (not scan.raw.log) and drops chkrootkit parsing
