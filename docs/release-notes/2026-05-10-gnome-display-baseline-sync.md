# Release Note: GNOME 디스플레이 기준값 동기화

## 변경 요약

현재 GNOME에서 적용된 듀얼 모니터 구성(외부 4K 60Hz primary, 내부 2560x1600)을 HDMI 기본 스크립트 값으로 반영했습니다.

## 주요 변경사항

- `scripts/cmd/sys.sh`
  - `sys:legion:hdmi` 기본 호출 인자 변경
  - `--rate 60 --internal-mode 2560x1600 --external-mode 3840x2160` 반영
- `scripts/sys/legion-hdmi.sh`
  - 기본값을 GNOME 현재 설정 기준으로 조정
  - `--internal-mode`, `--external-mode` 인자 파싱 및 하위 스크립트 전달 추가
- `scripts/sys/legion-hdmi-hotplug-autostart.sh`
  - `--rate`, `--internal-mode`, `--external-mode` 인자 추가
  - 로그인 자동 재감지 훅에 동일 해상도/주사율 적용

## 영향 범위

- `install-all.sh sys` 실행 시 HDMI 배치 기본값
- 로그인 직후 자동 재감지 훅 동작

## 기대 효과

- 수동으로 맞춘 GNOME 디스플레이 설정과 스크립트 기본값이 일치합니다.
- 재실행/재로그인 후 해상도 재적용 불일치가 줄어듭니다.

## 검증

- `bash -n scripts/cmd/sys.sh scripts/sys/legion-hdmi.sh scripts/sys/legion-hdmi-hotplug-autostart.sh scripts/sys/legion-hdmi-layout.sh`
