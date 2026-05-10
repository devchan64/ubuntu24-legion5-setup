# Release Note: GNOME Nord 실행 환경변수 전달 수정

## 변경 요약

`sys` 단계의 GNOME Nord 적용 시 `LEGION_SETUP_ROOT`가 사용자 세션으로 전달되지 않아 실패하던 문제를 수정했습니다.

## 주요 변경사항

- `scripts/sys/gnome-nord.sh`
  - `sudo -u <user> env ... python3` 실행 환경에 `LEGION_SETUP_ROOT`를 명시 추가

## 영향 범위

- `scripts/install-all.sh sys` 실행 중 `sys:gnome:nord` 단계

## 기대 효과

- `RuntimeError: [Contract] LEGION_SETUP_ROOT required` 오류가 제거됩니다.
- GNOME Nord 테마 적용 단계가 계약대로 연속 실행됩니다.

## 검증

- `bash -n scripts/sys/gnome-nord.sh scripts/cmd/sys.sh`
