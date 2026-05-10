# Release Note: HDMI 레이아웃 해상도 고정 옵션 추가

## 변경 요약

`legion-hdmi-layout.sh`에 내부/외부 모니터 해상도를 명시할 수 있는 옵션을 추가했습니다.

## 주요 변경사항

- `scripts/sys/legion-hdmi-layout.sh`
  - `--internal-mode <가로x세로>` 추가
  - `--external-mode <가로x세로>` 추가
  - 미지정 시 기존과 동일하게 `--auto` 동작 유지

## 적용 설정

- 예시:
  - `--internal-mode 2560x1600`
  - `--external-mode 1920x1080`

## 기대 효과

- 디스플레이 1/2 해상도가 바뀌거나 잘못 매핑되는 상황에서 원하는 해상도로 고정 적용할 수 있습니다.

## 검증

- `bash -n scripts/sys/legion-hdmi-layout.sh`
