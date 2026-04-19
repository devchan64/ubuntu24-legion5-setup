# Release Note: AGENTS.md Adoption

## 변경 요약

저장소 협업 규약 문서를 `CONTEXT.md`에서 `AGENTS.md`로 전환하고, VS Code가 이를 자동 인식하도록 워크스페이스 설정을 추가했습니다.

## 주요 변경사항

- `CONTEXT.md` -> `AGENTS.md`
  저장소 SSOT 문서명을 `AGENTS.md`로 변경했습니다.
- `AGENTS.md`
  VS Code와 Codex 계열 도구가 저장소 지침을 자동 인식할 수 있도록 루트 `AGENTS.md`를 SSOT로 사용한다고 명시했습니다.
- `AGENTS.md`
  커밋 메시지 규칙으로 `Conventional Commits` 사용을 명시했습니다.
- `.vscode/settings.json`
  VS Code chat가 루트 `AGENTS.md`를 자동 인식하도록 설정을 추가했습니다.
- `README.md`
  저장소 핵심 문서와 SSOT 참조를 `AGENTS.md` 기준으로 갱신했습니다.
- `lib/common.sh`
  협업 문서 참조 주석을 `AGENTS.md` 기준으로 수정했습니다.

## 적용 설정

- `chat.useAgentsMdFile = true`
- `chat.useNestedAgentsMdFiles = false`

## 기대 효과

- VS Code가 저장소 루트의 `AGENTS.md`를 자동 인식해 일관된 협업 규칙을 적용합니다.
- Codex 계열 도구와 VS Code에서 같은 협업 문서를 공유할 수 있습니다.
- 커밋 메시지 규칙이 `Conventional Commits`로 명확해져 변경 이력 관리가 쉬워집니다.

## 검증

- 저장소 내 `CONTEXT.md` 참조 제거 확인
- 루트 `AGENTS.md` 파일 존재 확인
- `.vscode/settings.json`에 `chat.useAgentsMdFile` 설정 추가 확인
