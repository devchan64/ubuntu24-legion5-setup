# Continue 명령 검사 계약 수정

## 변경 요약

Continue 인라인 자동완성 설정 단계가 제거된 이전 공통 API를 호출해 중단되던 문제를 수정했습니다.

## 주요 변경사항

- `require_cmd` 호출을 공통 SSOT 함수인 `must_cmd_or_throw`로 교체했습니다.
- 별칭 또는 폴백 API를 추가하지 않고 현재 공통 계약에 맞췄습니다.

## 영향 범위

- `dev:vscode:continue-inline` resume 단계
- `scripts/dev/editors/install-continue-inline.sh`

## 기대 효과

- Continue 설정 단계가 `명령어를 찾을 수 없음` 오류 없이 실행됩니다.
- `code`와 `python3` 사전조건이 공통 fail-fast 계약으로 검사됩니다.

## 검증

- 대상 스크립트 Bash 구문 검사
- ShellCheck 정적 검사
- 저장소 전체 이전 명령 검사 API 호출 부재 확인
