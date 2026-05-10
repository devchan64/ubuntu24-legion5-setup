# Release Note: resume_step 구분자 계약 위반 수정

## 변경 요약

`cmd` 도메인 스크립트들이 `resume_step` 호출 시 필수 구분자(`--`)를 누락해 즉시 실패하던 문제를 수정했습니다.

## 주요 변경사항

- `scripts/cmd/sys.sh`
- `scripts/cmd/dev.sh`
- `scripts/cmd/net.sh`
- `scripts/cmd/ops.sh`
- `scripts/cmd/security.sh`
- `scripts/cmd/media.sh`
- `scripts/cmd/ml.sh`

모든 `resume_step` 호출을 `resume_step "<scope>" "<step>" -- <command...>` 형태로 정렬했습니다.

## 적용 설정

- 별도 환경 변수/사용자 설정 변경 없음
- 기존 실행 명령 그대로 사용 가능

## 기대 효과

- `sys` 포함 모든 도메인에서 resume 단계 실행이 계약대로 동작합니다.
- `"[resume] Contract violation: missing '--' delimiter"` 오류가 재발하지 않습니다.

## 검증

- `bash -n scripts/cmd/sys.sh scripts/cmd/dev.sh scripts/cmd/net.sh scripts/cmd/ops.sh scripts/cmd/security.sh scripts/cmd/media.sh scripts/cmd/ml.sh lib/common.sh scripts/install-all.sh`
