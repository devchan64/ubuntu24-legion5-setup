# Codex CLI 및 Desktop 통합 설치

## 변경 요약

`codex` 설치 명령이 Codex CLI와 Codex Desktop을 함께 설치하도록 확장했습니다.

## 주요 변경사항

- Codex Desktop 설치 스크립트를 추가했습니다.
- OpenAI Codex App 저장소에서 amd64용 `chatgpt` 패키지와 SHA-256을 조회합니다.
- 내려받은 패키지의 SHA-256을 검증한 뒤 `apt-get`으로 설치합니다.

## 적용 설정

- Codex Desktop Linux 패키지 이름은 `chatgpt`이며 실행 명령은 `chatgpt`입니다.
- Codex Desktop 설치는 암호 입력이 필요한 권한 상승을 사용합니다.

## 기대 효과

한 번의 `./scripts/install-all.sh codex` 실행으로 터미널용 CLI와 데스크톱 앱을 모두 준비할 수 있습니다.

## 검증

- `bash -n scripts/cmd/codex.sh scripts/codex/install-cli.sh scripts/codex/install-desktop.sh`
- Codex App 저장소의 패키지 메타데이터 확인
