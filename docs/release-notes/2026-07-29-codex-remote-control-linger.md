# Codex 원격 제어 재부팅 유지 설정 추가

## 변경 요약

Codex 원격 제어 사용자 서비스가 재부팅 직후에도 기동될 수 있도록 사용자 systemd linger 설정을 추가했습니다.
또한 `codex remote-control start`가 데몬 시작 후 종료되는 동작에 맞춰 user systemd 유닛 타입을 보정했습니다.

## 주요 변경사항

- `codex:remote-control:linger` resume 단계를 추가했습니다.
- `codex:remote-control:service-unit-v2` resume 단계를 추가해 기존 설치 환경에도 유닛 보정을 다시 적용합니다.
- `codex-remote-control.service`를 `Type=oneshot`, `RemainAfterExit=yes`로 변경했습니다.
- `loginctl enable-linger <user>`를 직접 실행해 로그인 세션이 없어도 사용자 systemd 매니저가 유지되도록 구성했습니다.
- linger 활성화 후 `loginctl show-user`로 `Linger=yes` 상태를 확인합니다.

## 영향 범위

- `scripts/cmd/codex.sh`
- `scripts/codex/remote-control-service.sh`
- `scripts/codex/remote-control-linger.sh`
- `README.md`

## 기대 효과

- 재부팅 후 로그인 전 또는 로그인 세션 종료 후에도 Codex 원격 제어 사용자 서비스가 유지될 수 있습니다.
- user systemd가 원격 제어 데몬 시작 직후 `ExecStop`을 호출해 서비스를 다시 끄는 문제를 방지합니다.
- 기존 `codex:remote-control:service` 완료 상태를 변경하지 않고 누락된 재부팅 유지 설정만 추가 적용할 수 있습니다.

## 검증

- 대상 스크립트 Bash 구문 검사
- Codex 문서의 원격 제어 서비스 포함 항목 확인
