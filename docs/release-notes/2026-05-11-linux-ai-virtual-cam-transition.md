# 카메라 처리 경로 전환 (ai-virtual-cam)

## 변경 요약

`media` 도메인에서 기존 OBS 가상 오디오 유닛 생성 기능을 제거하고 `ai-virtual-cam`(Linux `v4l2loopback` 경로, 비디오+오디오 통합 처리) 설치 단계로 전환했습니다.

## 주요 변경사항

- `scripts/cmd/media.sh`
  - 오디오 설치 스텝을 `media:audio:virtual:install`에서 `media:camera:ai-virtual-cam:install`으로 변경
  - 실행 스크립트를 `scripts/media/camera/install-ai-virtual-cam.sh`로 교체
- `scripts/media/audio/install-virtual-audio.sh` 삭제
- `scripts/media/camera/install-ai-virtual-cam.sh` 추가
  - `https://github.com/devchan64/ai-virtual-cam` 저장소를 clone/pull
  - 공식 진입점 `./bin/avc setup` 실행 방식으로 설치
- `README.md` media 계약 섹션에 전환 정책 반영

## 영향 범위

- `./install-all.sh media` 실행 시, 기존 PipeWire/Pulse 기반 OBS 가상 오디오 유닛 자동 구성은 더 이상 수행되지 않습니다.
- 대신 `ai-virtual-cam` 설치/업데이트와 `./bin/avc setup` 실행이 `media` 단계에 포함됩니다.
- `ai-virtual-cam` 설치 단계는 Linux 경로 기준이며 OBS 실행/연동 동작을 수행하지 않습니다.
- `ai-virtual-cam`은 카메라 비디오/오디오 처리를 함께 수행합니다.

## 기대 효과

- Linux 카메라 비디오/오디오 처리 경로를 단일 도구(`ai-virtual-cam`)로 표준화합니다.
- 기존 사용자 systemd 유닛 및 pactl 모듈 의존도를 제거해 관리 복잡도를 낮춥니다.

## 검증

- `bash -n scripts/cmd/media.sh scripts/media/camera/install-ai-virtual-cam.sh`
