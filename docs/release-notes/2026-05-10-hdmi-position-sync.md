# Release Note: HDMI 레이아웃 좌표(X,Y) 동기화

## 변경 요약

모니터 절대 좌표(X,Y)가 적용되지 않던 문제를 해결하기 위해 HDMI 레이아웃에 좌표 지정 옵션을 추가하고 GNOME 기준값으로 기본 동작을 동기화했습니다.

## 주요 변경사항

- `scripts/sys/legion-hdmi-layout.sh`
  - `--internal-pos`, `--external-pos` 옵션 추가
  - 좌표가 전달되면 `xrandr --pos` 기반으로 절대 위치 적용
- `scripts/sys/legion-hdmi.sh`
  - 좌표 인자 파싱/전달 추가
  - 기본 좌표를 `--internal-pos 3840x0 --external-pos 0x0`으로 설정
- `scripts/sys/legion-hdmi-hotplug-autostart.sh`
  - 로그인 자동 재감지 훅에 좌표 인자 추가
  - 훅 내부 `xrandr`를 `--pos` 기반으로 변경
- `scripts/cmd/sys.sh`
  - `sys:legion:hdmi` 기본 호출 인자에 좌표 추가

## 영향 범위

- `install-all.sh sys`의 HDMI 배치
- 로그인 후 자동 재감지 배치

## 기대 효과

- GNOME에서 맞춘 모니터 위치(X,Y)가 스크립트 재적용 시에도 동일하게 유지됩니다.

## 검증

- `bash -n scripts/sys/legion-hdmi-layout.sh scripts/sys/legion-hdmi-hotplug-autostart.sh scripts/sys/legion-hdmi.sh scripts/cmd/sys.sh`
