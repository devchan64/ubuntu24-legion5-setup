# Release Note: Continue Inline Autocomplete Integration

## 변경 요약

이번 변경으로 VS Code용 Continue 인라인 자동완성 설정이 개발환경 기본 설치 흐름에 포함되었습니다.

## 주요 변경사항

- `scripts/cmd/dev.sh`
  `install-all.sh dev` 및 `install-all.sh all` 실행 시 `install-continue-inline.sh`가 자동으로 수행되도록 `dev` 설치 단계에 추가했습니다.
- `scripts/dev/editors/install-continue-inline.sh`
  Continue 확장과 VS Code 인라인 자동완성 관련 설정을 적용하는 전용 스크립트를 추가했습니다.
- `scripts/dev/editors/extensions.txt`
  표준 VS Code 확장 목록에 `Continue.continue`를 추가했습니다.
- `README.md`
  에디터 설치 섹션과 디렉터리 구조 문서에 Continue 인라인 자동완성 설정 단계를 반영했습니다.

## 적용 설정

- `editor.inlineSuggest.enabled = true`
- `continue.enableTabAutocomplete = true`
- `continue.enableNextEdit = false`
- `continue.enableQuickActions = false`
- `continue.disableQuickFix = true`
- `continue.pauseCodebaseIndexOnStart = true`
- `continue.showInlineTip = false`

## 기대 효과

- 신규 환경 셋업 시 Continue 인라인 자동완성이 표준 개발환경의 일부로 함께 구성됩니다.
- VS Code 확장 설치와 사용자 설정 반영이 분리되어 재실행 시에도 예측 가능하게 동작합니다.
- `AGENTS.md`의 fail-fast, 공통 유틸 사용 원칙에 맞춰 스크립트 일관성을 유지합니다.

## 검증

- `bash -n scripts/cmd/dev.sh`
- `bash -n scripts/dev/editors/install-continue-inline.sh`
