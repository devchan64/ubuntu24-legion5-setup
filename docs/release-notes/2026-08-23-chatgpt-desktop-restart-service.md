# ChatGPT Desktop 비정상 종료 자동 재시작

## 변경 요약

`codex` 설치 흐름에서 ChatGPT Desktop이 비정상 종료되면 다시 실행하는 사용자 systemd 서비스를 등록합니다.

## 주요 변경사항

- `chatgpt-restart.service`를 사용자 systemd 유닛으로 작성하고 활성화합니다.
- 그래픽 세션에서 ChatGPT Desktop을 시작합니다.
- 기존에 수동으로 시작한 ChatGPT 프로세스를 종료한 뒤 서비스가 새 인스턴스를 관리합니다.
- 실패 종료 시 5초 후 다시 시작합니다.
- 60초 동안 5회 이상 반복 실패하면 systemd가 재시작을 중단합니다.

## 적용 설정

- `./scripts/install-all.sh codex` 실행 시 `~/.config/systemd/user/chatgpt-restart.service`를 등록합니다.
- 서비스는 `graphical-session.target`에 연결됩니다.

## 기대 효과

ChatGPT Desktop이 간헐적으로 비정상 종료되어도 그래픽 사용자 세션에서 자동으로 복구됩니다.

## 검증

- `bash -n scripts/cmd/codex.sh scripts/codex/chatgpt-restart-service.sh`
- `systemd-analyze --user verify ~/.config/systemd/user/chatgpt-restart.service`
