# media 도메인 OBS 코드 폐기 및 ai-virtual-cam 단일화

## 변경 요약

`scripts/media`의 OBS 관련 구현을 폐기하고 `ai-virtual-cam` 중심 경로로 단순화했습니다.

## 주요 변경사항

- `scripts/cmd/media.sh`
  - OBS 사전검증/설치/가상카메라 리셋 로직 제거
  - `ai-virtual-cam` 설치 스텝만 실행하도록 단순화
  - stepKey를 `media:camera:ai-virtual-cam:install`로 조정
- `scripts/media/camera/install-ai-virtual-cam.sh`
  - `ai-virtual-cam` 설치 스크립트 경로를 `audio`에서 `camera`로 이동
  - 비디오/오디오 통합 처리 도구의 역할에 맞게 경로 체계 정리
- `scripts/media/video/*` OBS 관련 파일 삭제
  - `obs-install.sh`
  - `reset_obs_cam.sh`
  - `obs_dsp_chain.lua`
  - `obs_seg_kor_royshil_min.lua`
- `scripts/install-all.sh` help의 media 설명을 ai-virtual-cam 기준으로 수정
- `README.md`, `AGENTS.md`의 media 정책을 OBS 비의존 경로로 동기화

## 영향 범위

- `./scripts/install-all.sh media` 실행 시 OBS 관련 설치/검증/보조 스크립트는 더 이상 동작하지 않습니다.
- media 도메인은 `ai-virtual-cam` 설치/업데이트 경로만 수행합니다.

## 기대 효과

- media 실행 흐름이 단순해져 유지보수 복잡도를 줄입니다.
- Linux 카메라 처리 정책을 단일 경로로 고정해 계약 해석의 모호성을 제거합니다.

## 검증

- `bash -n scripts/cmd/media.sh scripts/media/camera/install-ai-virtual-cam.sh scripts/install-all.sh`
