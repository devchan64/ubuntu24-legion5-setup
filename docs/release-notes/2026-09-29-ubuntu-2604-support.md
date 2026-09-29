# Ubuntu 26.04 대응 및 xrandr 배치 폐기

## 변경 요약

24.04 지원을 유지하면서 26.04/resolute의 Wayland 설치 경로를 추가했습니다.

## 주요 변경사항

- OS 검사 함수를 공통 계약으로 통합하고 정확한 버전/코드명 쌍만 허용합니다.
- 26.04 완료 상태는 `.ubuntu-26.04` 접미사로 분리합니다. 기존 stepKey, 상태 디렉터리와 전역 재부팅 경계는 유지합니다.
- 26.04에서 GDM의 기존 Xorg 강제 설정을 백업 후 해제하고 재부팅 경계를 설정합니다.
- GNOME 테마용 세션 조회에 Wayland를 허용합니다. Nord 팔레트용 GNOME Terminal을 명시적으로 설치합니다.
- xrandr 배치 및 복구 스크립트, PRIME 강제 전환 경로를 제거합니다. 모니터 배치는 GNOME 설정에서 관리합니다.
- CUDA는 26.04의 Ubuntu 공식 `cuda-toolkit`을 사용합니다. 24.04 전용 로컬 저장소 설치·정리 로직은 실행하지 않습니다.

## 영향 범위

- OS 자체를 업그레이드하는 기능은 아닙니다. 26.04 설치 후 일반 사용자로 기존 명령을 실행합니다.
- 기존 `~/.local/bin/monitor-hotplug-apply.sh`는 사용을 중단해야 합니다. 사용자 파일은 자동 삭제하지 않습니다.
- 26.04에서 CUDA 로컬 저장소 변수와 별도 드라이버 설치 옵션은 오류로 처리합니다.
- 저장소 이름과 상태 경로의 `ubuntu24`는 호환성을 위해 유지합니다.
- TensorRT는 기존 pip 설치 정책을 유지하며 Python/휠 호환성은 실제 설치 시 검증합니다.
- NVIDIA Container Toolkit 설치 단계는 기존 미구현 상태이며 이번 변경의 구현 범위가 아닙니다.

## 기대 효과

26.04에서 Xorg 강제 설정과 24.04 CUDA 저장소를 적용하는 문제를 방지합니다.

## 검증

- 모든 Bash 파일 구문 검사, `git diff --check`.
- OS 버전/코드명 및 resume 분리 모의 검증.
- 26.04 실기기 설치, GPU 출력 및 TensorRT 설치는 미검증입니다.

## 근거

- [Ubuntu 26.04 공식 변경사항: Wayland 및 CUDA](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/)
- [Docker Ubuntu 설치 요구사항](https://docs.docker.com/engine/install/ubuntu/)
