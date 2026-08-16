# Codex 원격 제어 사용자 서비스 제거

## 변경 요약

Codex 설치 흐름에서 원격 제어 사용자 systemd 서비스 등록 기능을 제거했습니다.

## 주요 변경사항

- `codex-remote-control.service` 작성, 활성화 및 등록 단계를 제거했습니다.
- 원격 제어 서비스의 재부팅 유지에 사용하던 사용자 linger 설정 단계를 제거했습니다.
- 관련 서비스 설정 스크립트를 제거했습니다.

## 영향 범위

- `./scripts/install-all.sh codex`는 원격 제어 서비스 없이 Codex CLI와 Desktop을 설치합니다.
- 기존에 활성화된 사용자 서비스는 중지·비활성화하고 유닛 파일을 제거해야 합니다.

## 기대 효과

Codex 원격 제어가 로그인 또는 재부팅 후 자동으로 시작되지 않습니다.

## 검증

- `bash -n scripts/cmd/codex.sh`
- `rg -n -i 'remote-control|remote control|remote_control' scripts/cmd/codex.sh README.md`
