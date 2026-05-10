# Release Note: KVM 환경 수동 디스플레이 복구 스크립트 추가

## 변경 요약

KVM 스위칭 이후 자동복원이 불안정한 환경을 위해 수동 복구 스크립트를 추가했습니다.

## 주요 변경사항

- `scripts/sys/recover-display.sh` 추가
  - 외부 단독 신호 복구 시도 후 듀얼 레이아웃 재구성
  - 기본 구성:
    - 외부 `HDMI-0` `3840x2160@60` primary
    - 내부 `eDP-1-1` `2560x1600@165` `+3840+0`
- `README.md`에 KVM 수동 복구 실행 안내 추가

## 영향 범위

- KVM 스위칭 시 자동복원이 실패하는 사용자 운영 절차

## 기대 효과

- KVM 전원 재부팅 없이 사용자 명령 1회로 외부 신호를 복구할 수 있습니다.

## 검증

- `bash -n scripts/sys/recover-display.sh`
