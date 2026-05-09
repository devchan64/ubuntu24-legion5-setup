# Release Note: HDMI 로그인 자동 재감지 등록

## 변경 요약

로그인 이후 외부 모니터 자동 감지가 누락되는 환경을 보완하기 위해, HDMI 구성 단계에서 사용자 세션 자동실행 훅을 기본 등록하도록 변경했습니다.

## 주요 변경사항

- `scripts/sys/legion-hdmi-hotplug-autostart.sh`
  로그인 후 X 세션이 안정화된 시점에 `xrandr` 재감지를 수행하는 사용자 자동실행 파일을 생성/등록하는 스크립트를 추가했습니다.
- `scripts/sys/legion-hdmi.sh`
  기존 NVIDIA/PRIME/레이아웃 적용 이후, 자동 재감지 등록 단계를 연속 실행하도록 흐름을 확장했습니다.

## 적용 설정

- `${HOME}/.local/bin/monitor-hotplug-apply.sh` 생성 및 실행권한 부여
- `${HOME}/.config/autostart/monitor-hotplug-apply.desktop` 생성
- 로그인 3초 후 내부/외부 출력 감지 시 `--right-of` 레이아웃 재적용

## 기대 효과

- 재부팅/재로그인 직후 외부 모니터 감지 타이밍 이슈로 레이아웃이 누락되는 케이스를 자동으로 보정합니다.
- `sys` 도메인 HDMI 설정을 재실행하면 사용자 자동실행 등록도 함께 일관되게 유지됩니다.

## 검증

- `bash -n scripts/sys/legion-hdmi.sh`
- `bash -n scripts/sys/legion-hdmi-hotplug-autostart.sh`
