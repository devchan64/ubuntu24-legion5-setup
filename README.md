# Ubuntu 24 Legion5 Setup

Ubuntu 24.04 LTS(Xorg)에서 **개발/AI/미디어(OBS)/보안/네트워크/모니터링** 환경을 신속히 표준화합니다.  
철학은 단순합니다: **폴백 없음 · 실패 즉시 종료 · 멱등성 보장 · 명확한 로그**.

> 대상 하드웨어(참고): Lenovo Legion 5 15IAX10 U9 5070 Plus (GeForce RTX 5070 Laptop)

---

## 요구 사항

- **Ubuntu 24.04 LTS** (`noble`)
- **Xorg 세션** (Wayland 미지원 스크립트 존재)
- 관리자 권한이 필요한 단계는 `sudo`로 실행
- NVIDIA GPU 사용 시: 드라이버 설치 및 `nvidia-smi` 동작 확인(권장)

---

## TL;DR (가장 빠른 경로)

```bash
# 전체 설치(권장): SYS/DEV/ML/MEDIA/SECURITY/NET/OPS 순차 실행
sudo bash scripts/install-all.sh --all
```

원하는 도메인만 설치하려면:

```bash
sudo bash scripts/install-all.sh --sys
sudo bash scripts/install-all.sh --dev
bash  scripts/install-all.sh --media
bash  scripts/install-all.sh --ml
bash  scripts/install-all.sh --security
bash  scripts/install-all.sh --net
bash  scripts/install-all.sh --ops
```

> MEDIA/ML 처럼 데스크톱 사용자 세션과 연동되는 작업은 **sudo 없이 사용자 세션**에서 실행합니다.

---

## 디렉터리 구조

```
.
├─ README.md
├─ background/                 # 배경 리소스(이미지 등)
├─ lib/
│  └─ common.sh               # 공통 유틸: 로그, 에러, 선행조건, user systemd 준비 등
└─ scripts/
   ├─ install-all.sh          # 도메인 오케스트레이터
   ├─ sys/
   │  ├─ bootstrap.sh         # (스텁) 시스템 기본 부트스트랩
   │  ├─ xorg-ensure.sh       # (스텁) Xorg 세션 확인/강제 가이드
   │  └─ github-web-login.sh  # GitHub CLI 웹 로그인 자동화
   ├─ dev/
   │  ├─ install-dev-stack.sh # DEV 통합 실행기
   │  ├─ docker/
   │  │  ├─ install.sh    # Docker Engine + Buildx/Compose
   │  │  ├─ install-nvidia-toolkit.sh    # NVIDIA Toolkit
   │  ├─ editors/
   │  │  ├─ install-vscode.sh
   │  │  ├─ install-extensions.sh
   │  │  └─ extensions.txt
   │  ├─ node/{install.sh, setup.sh}   # (스텁)
   │  └─ python/{install.sh, setup.sh} # (스텁)
   ├─ media/
   │  ├─ video/obs-install.sh
   │  └─ audio/
   │     ├─ install-virtual-audio.sh
   │     ├─ enable-virtualmic.sh
   │     ├─ echo-cancel.sh
   │     ├─ create-obs-monitor-sink.sh
   │     └─ create-obs-virtual-mic.sh
   ├─ ml/
   │  ├─ setup-cuda-tensorrt.sh
   │  └─ tf/{run-jupyter.sh, down-jupyter.sh, verify-gpu.sh}
   ├─ security/
   │  ├─ install.sh           # (스텁)
   │  ├─ scan.sh              # (스텁)
   │  └─ schedule.sh          # 주간 타이머 유닛 생성/관리
   ├─ net/tools-install.sh    # (스텁)
   └─ ops/monitors-install.sh # (스텁)
```

---

## 공통 규약

- 모든 스크립트는 **폴백 없이 실패 시 종료**합니다: `set -Eeuo pipefail`
- 공통 유틸: `lib/common.sh`
  - `require_root`, `require_cmd`, `require_ubuntu_2404`, `require_xorg_or_die`
  - `ensure_user_systemd_ready`(user linger, user-bus 확인)
  - 간단 락·멱등 유틸(`acquire_lock`, `ensure_line`, …)

---

## 설치 매트릭스

| 도메인   | 스크립트                                           |    루트 필요 | 상태                                         |
| -------- | -------------------------------------------------- | -----------: | -------------------------------------------- |
| 시스템   | `scripts/install-all.sh --sys` → `sys/*`           |         일부 | **스텁 포함**                                |
| 개발     | `scripts/install-all.sh --dev` → `dev/*`           | Docker: 필요 | Docker/VSCode **완료**, Node/Python **스텁** |
| 미디어   | `scripts/install-all.sh --media` → `media/*`       |       불필요 | OBS/가상오디오/에코캔슬 **완료**             |
| ML       | `scripts/install-all.sh --ml` → `ml/*`, `ml/tf/*`  |       불필요 | TF Jupyter/검증 **완료**                     |
| 보안     | `scripts/install-all.sh --security` → `security/*` |       불필요 | 타이머 **완료**, install/scan **스텁**       |
| 네트워크 | `scripts/install-all.sh --net` → `net/*`           |       불필요 | **스텁**                                     |
| 모니터링 | `scripts/install-all.sh --ops` → `ops/*`           |       불필요 | **스텁**                                     |

---

## 도메인별 가이드

### 1) 시스템 (SYS)

```bashㅅ
sudo bash scripts/install-all.sh --sys
# 또는
sudo bash scripts/sys/bootstrap.sh
sudo bash scripts/sys/xorg-ensure.sh
```

- 현재 두 스크립트는 **스텁**입니다(메시지 출력만). 향후 기본 패키지/UFW/Xorg 전환 로직이 추가됩니다.
- GitHub 웹 로그인 자동화:

```bash
bash scripts/sys/github-web-login.sh
```

### 2) 개발 환경 (DEV)

**Docker + NVIDIA Container Toolkit**

```bash
sudo bash scripts/dev/docker/install.sh
docker --version && docker compose version
```

**VSCode + 확장**

```bash
bash scripts/dev/editors/install-vscode.sh
bash scripts/dev/editors/install-extensions.sh
```

**통합 실행기**

```bash
sudo bash scripts/dev/install-dev-stack.sh
```

> `dev/node/*`, `dev/python/*`은 현재 **스텁**입니다(설치/셋업 세부 로직 미작성).

### 3) 미디어 (MEDIA)

**OBS (Flatpak)**

```bash
bash scripts/media/video/obs-install.sh
flatpak info com.obsproject.Studio
```

**가상 오디오(로그인 시 자동)**

```bash
bash scripts/media/audio/install-virtual-audio.sh
# 내부적으로 user systemd에 다음을 구성:
#  - create-obs-monitor-sink.service
#  - create-obs-virtual-mic.service
```

**즉시 적용만 원할 경우**

```bash
bash scripts/media/audio/create-obs-monitor-sink.sh
bash scripts/media/audio/create-obs-virtual-mic.sh
```

**WebRTC 에코/노이즈 캔슬**

```bash
bash scripts/media/audio/echo-cancel.sh
```

### 4) 머신러닝 (ML)

**CUDA/TensorRT 준비(선택)**

```bash
# 기본은 드라이버 미설치 플래그. 필요 시 스크립트 옵션으로 토글.
sudo bash scripts/ml/setup-cuda-tensorrt.sh
```

**TensorFlow Jupyter (GPU)**

```bash
bash scripts/ml/tf/run-jupyter.sh
# 브라우저: http://localhost:8888 (token: legion)
# 중지
bash scripts/ml/tf/down-jupyter.sh
```

**GPU 가시화 검증**

```bash
bash scripts/ml/tf/verify-gpu.sh
# 또는
nvidia-smi
```

### 5) 보안 (SECURITY)

**주간 스케줄러 (user systemd timer)**

```bash
bash scripts/security/schedule.sh --enable-weekly
# 비활성화
bash scripts/security/schedule.sh --disable
```

- 실제 스캔 실행 로직은 `security/install.sh`, `security/scan.sh` 입니다.
- 요약: `security/summarize-last-scan.sh` 사용 가능.

### 6) 네트워크 (NET), 7) 모니터링(OPS)

- `net/tools-install.sh`, `ops/monitors-install.sh`는 입니다.

---

## 스모크 테스트

```bash
# Docker/Compose
docker --version && docker compose version

# GPU
nvidia-smi

# TF Jupyter 컨테이너 동작
bash scripts/ml/tf/run-jupyter.sh
sleep 3 && docker ps | grep tf-jupyter

# OBS 설치 여부
flatpak info com.obsproject.Studio

# 가상 오디오/에코캔슬
pactl list short sinks   | grep OBS_Monitor
pactl list short sources | grep OBS_VirtualMic
pactl list short modules | grep module-echo-cancel
```

---

## 트러블슈팅

- **Xorg 강제**: Wayland 세션에서는 가상 오디오/OBS 일부 동작이 보장되지 않습니다. 로그인 화면에서 **Xorg**를 선택하세요.
- **user systemd/linger**: 오디오 유닛/보안 타이머는 사용자 세션 유닛으로 동작합니다.
  ```bash
  loginctl enable-linger "$USER"
  systemctl --user daemon-reload
  systemctl --user status create-obs-monitor-sink.service
  journalctl --user-unit create-obs-monitor-sink.service -e
  ```
- **Flatpak OBS + 플러그인**: Flatpak 샌드박스 특성상 호스트 .so 플러그인을 직접 인식하지 못할 수 있습니다. 본 레포는 **기본 OBS만** 설치합니다.
- **NVIDIA Container Toolkit**: APT 키/리포 구성이나 패키지명은 배포 업데이트에 따라 변경될 수 있습니다. 스크립트 로그의 힌트를 참고해 주세요.

---

## 설계 원칙

- **즉시 실패**: 예외를 덮지 않습니다. 실패는 빠르게 드러나야 복구가 빠릅니다.
- **멱등성**: 재실행해도 같은 결과. 이미 구성된 리소스는 건너뛰되, 상태 검증은 엄격히 합니다.
- **명시성**: 선택지는 플래그로 드러냅니다(예: ML 드라이버 설치 여부).
- **가시성**: 실행 로그는 사람이 읽기 쉬워야 합니다.

---

## 로드맵

- SYS 부트스트랩(기본 패키지/UFW/Xorg 전환 가이드) 실제 구현
- DEV(Node/Python) 설치·셋업 채우기
- SECURITY 설치/스캔 본체 구현 및 요약 리포트 연결
- NET/OPS 내용 보강
- 버전 핀(이미지 TAG/DIGEST, APT 패키지) 및 간이 CI(shellcheck/shfmt)

---

## 라이선스

TBD

---

### 감사

본 프로젝트는 Ubuntu 24.04 LTS에서 “**포맷 후 30분 내 복구**”를 목표로 합니다. 피드백/PR 환영합니다.
