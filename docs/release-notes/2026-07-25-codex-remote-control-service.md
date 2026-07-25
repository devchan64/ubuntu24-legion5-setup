# Codex CLI 및 원격 제어 사용자 서비스 명령 추가

## 변경 요약

Codex CLI를 설치하고 원격 제어를 사용자 systemd 서비스로 등록하는 `codex` 명령을 추가했습니다.

## 주요 변경사항

- `./scripts/install-all.sh codex` 명령을 추가했습니다.
- `codex:cli:install` resume 단계를 추가했습니다.
- `codex:remote-control:service` resume 단계를 추가했습니다.
- Codex standalone installer를 `CODEX_NON_INTERACTIVE=1`로 실행해 CLI를 설치하도록 구성했습니다.
- 사용자 systemd 유닛 `codex-remote-control.service`를 작성하고 활성화/시작하도록 구성했습니다.

## 영향 범위

- `scripts/install-all.sh`
- `scripts/cmd/codex.sh`
- `scripts/codex/install-cli.sh`
- `scripts/codex/remote-control-service.sh`
- `AGENTS.md`
- `README.md`

## 기대 효과

- 수동으로 Codex CLI를 설치하거나 user systemd 유닛을 작성하지 않고 Codex 원격 제어 서비스를 재현 가능하게 설정할 수 있습니다.
- 기존 resume 계약에 따라 동일 단계를 반복 실행해도 완료 상태를 추적할 수 있습니다.

## 검증

- 대상 스크립트 Bash 구문 검사
- 최상위 도움말에 `codex` 명령 노출 확인
- ShellCheck 미설치로 정적 검사는 수행하지 못함
