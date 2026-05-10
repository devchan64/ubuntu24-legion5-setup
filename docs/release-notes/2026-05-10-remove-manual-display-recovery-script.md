# Release Note: 수동 디스플레이 복구 스크립트 제거

## 변경 요약

`scripts/sys/recover-display.sh` 수동 복구 스크립트를 저장소에서 제거했습니다.

## 주요 변경사항

- `scripts/sys/recover-display.sh` 삭제
- `README.md`의 KVM 수동 복구 실행 안내 제거

## 영향 범위

- 기존 수동 복구 스크립트 경로(`./scripts/sys/recover-display.sh`)를 사용하던 사용자 절차

## 기대 효과

- 자동 복원 체인(`sys:legion:hdmi` 및 관련 스크립트) 중심으로 운영 경로를 단순화합니다.
- 더 이상 유지하지 않는 수동 스크립트 참조로 인한 혼선을 줄입니다.

## 검증

- 저장소 내 `scripts/sys/recover-display.sh` 참조 제거 확인
