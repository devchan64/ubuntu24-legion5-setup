# Release Note: NVIDIA HDMI 감지 점검 절차 추가

## 변경 요약

NVIDIA 드라이버 로드 이후에도 HDMI/DP 외부 모니터가 미검출되는 상황을 진단할 수 있도록 README와 HDMI 레이아웃 실패 메시지를 보강했습니다.

## 주요 변경사항

- `README.md`의 `sys` 도메인에 외부 모니터 미검출 점검 절차 추가
- `scripts/sys/legion-hdmi-layout.sh`의 외부 디스플레이 미검출 오류 메시지에 NVIDIA/DRM 진단 정보 추가
- 현재 커널용 NVIDIA 모듈, 드라이버 계열 혼재, GNOME 모니터 캐시, NVIDIA Runtime PM 점검 순서 명시

## 영향 범위

- `./install-all.sh sys` 실행 중 HDMI/DP 외부 모니터를 찾지 못하는 경우
- NVIDIA PRIME 환경에서 재부팅 후 외부 모니터가 `disconnected`로 남는 경우
- 커널 업데이트 이후 NVIDIA 모듈 패키지 정합성이 깨진 경우

## 기대 효과

- 외부 모니터 미검출 시 하드웨어 문제와 드라이버/커널 정합성 문제를 빠르게 구분합니다.
- 반복 실행 시 실패 지점에서 바로 다음 점검 명령을 확인할 수 있습니다.
- NVIDIA 드라이버 계열 혼재로 인한 재발 가능성을 줄입니다.

## 검증

- `bash -n scripts/sys/legion-hdmi-layout.sh`
- README 및 릴리즈 노트 형식 확인
