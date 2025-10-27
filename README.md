# Ubuntu 24 Legion5 Setup with ChatGPT

Ubuntu 24.04 LTS(Xorg)에서 **개발/AI/미디어(OBS)/보안/네트워크/모니터링** 환경을 신속히 표준화합니다.  
철학은 단순합니다: **폴백 없음 · 실패 즉시 종료 · 멱등성 보장 · 명확한 로그**.

[text](CONTEXT.md)
ChatGPT와 환경설정 프로젝트를 함께 관리하고자 합니다. 그러기위해 Context 관리를 위한 md파일을 추가하고, 이것을 통해서 ChatGPT와 컨텐스트 관리를 함께하고자 합니다.

> 대상 하드웨어(참고): Lenovo Legion 5 15IAX10 U9 5070 Plus (GeForce RTX 5070 Laptop)

---

## 요구 사항

- **Ubuntu 24.04 LTS** (`noble`)
- **Xorg 세션** (Wayland 미지원 스크립트 존재)
- 관리자 권한이 필요한 단계는 `sudo`로 실행
- NVIDIA GPU 사용 시: 드라이버 설치 및 `nvidia-smi` 동작 확인(권장)

---

## 사용법 (install-all.sh)

이 레포의 메인 엔트리포인트는 `scripts/install-all.sh` 입니다.

```
Usage:
  install-all.sh <command> [options]

Commands:
  sys                 System bootstrap (Xorg ensure, GNOME Nord, Legion HDMI)
  dev                 Developer toolchain (docker, node, python, etc.)
  ml                  ML stack (CUDA/TensorRT, etc.)
  media               OBS / video tooling
  security            Security toolchain
  net                 Networking tools
  ops                 Ops / monitors
  all                 Run dev, sys, ml, net, ops, security sequentially (※ media 제외)
  help                Show this help

Global Options:
  --yes               Assume yes to prompts (non-interactive)
  --debug             Verbose logs
```

### 예시

```bash
# 도움말
bash scripts/install-all.sh help

# 단일 도메인
sudo bash scripts/install-all.sh sys
sudo bash scripts/install-all.sh dev
bash scripts/install-all.sh media      # media는 사용자 세션에서 실행

# 전체 설치 (실제 실행 순서 주의: dev → sys → ml → net → ops → security; media는 제외)
sudo bash scripts/install-all.sh all --yes
```

> ℹ️ `--yes`, `--debug` 같은 글로벌 옵션은 **어느 위치에 둬도 인식**됩니다.

## 디렉터리 구조

```
.
├─ README.md
├─ background/                 # 배경 리소스(이미지 등)
├─ lib/
│  └─ common.sh               # 공통 유틸: 로그, 에러, 선행조건, user systemd 준비 등
└─ scripts/
   ├─ install-all.sh          # 도메인 오케스트레이터
      ├─ cmd/                 # 각 도메인 엔트리 (sys.sh, dev.sh, ml.sh, media.sh, security.sh, net.sh, ops.sh; *_main 포함)
   ├─ sys/
   │  ├─ bootstrap.sh         # 시스템 기본 부트스트랩
   │  ├─ xorg-ensure.sh       # Xorg 세션 확인/강제 가이드
   │  └─ github-web-login.sh  # GitHub CLI 웹 로그인 자동화
   ├─ dev/
   │  ├─ install-dev-stack.sh # DEV 통합 실행기
   │  ├─ docker/
   │  │  ├─ install.sh         # Docker Engine + Buildx/Compose
   │  │  └─ nvidia-toolkit.sh  # NVIDIA Container Toolkit
   │  ├─ editors/
   │  │  ├─ install-vscode.sh
   │  │  ├─ install-extensions.sh
   │  │  └─ extensions.txt
   │  ├─ node/{install.sh, setup.sh}
   │  └─ python/{install.sh, setup.sh}
   ├─ media/
   │  ├─ video/obs-install.sh
   │  └─ audio/
   │     ├─ install-virtual-audio.sh
   │     ├─ create-obs-monitor-sink.sh
   │     └─ create-obs-virtual-mic.sh
   ├─ ml/
   │  ├─ setup-cuda-tensorrt.sh
   │  └─ tf/{run-jupyter.sh, down-jupyter.sh, verify-gpu.sh}
   ├─ security/
   │  ├─ install.sh
   │  ├─ scan.sh
   │  ├─ schedule.sh
   │  └─ summarize-last-scan.sh
   ├─ net/
   │  └─ tools-install.sh
   └─ ops/
      └─ monitors-install.sh
```

---

## 공통 규약

- 모든 스크립트는 **폴백 없이 실패 시 종료**합니다: `set -Eeuo pipefail`
- 공통 유틸: `lib/common.sh`

---

## 설치 매트릭스

| 도메인   | 스크립트                                         |         루트 필요 | 상태                                               |
| -------- | ------------------------------------------------ | ----------------: | -------------------------------------------------- |
| 개발     | `scripts/install-all.sh dev` → `dev/*`           |  Docker 관련 필요 | Docker/VSCode **완료**, Node/Python                |
| 시스템   | `scripts/install-all.sh sys` → `sys/*`           |              일부 |                                                    |
| 미디어   | `scripts/install-all.sh media` → `media/*`       |            불필요 | OBS/가상오디오/에코캔슬 **완료**                   |
| ML       | `scripts/install-all.sh ml` → `ml/*`, `ml/tf/*`  |            불필요 | TF Jupyter/검증 **완료**                           |
| 보안     | `scripts/install-all.sh security` → `security/*` | 설치/스케줄: 필요 | **설치/스케줄 루트 필요**, 스캔 요약은 사용자 가능 |
| 네트워크 | `scripts/install-all.sh net` → `net/*`           |            불필요 |                                                    |
| 모니터링 | `scripts/install-all.sh ops` → `ops/*`           |            불필요 |                                                    |

---

## 도메인별 가이드

### 1) 시스템 (SYS)

```bash
sudo bash scripts/install-all.sh --sys
# 또는
sudo bash scripts/sys/bootstrap.sh
sudo bash scripts/sys/xorg-ensure.sh
```

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
# 중지:
bash scripts/ml/tf/down-jupyter.sh
```

**GPU 가시화 검증**

```bash
bash scripts/ml/tf/verify-gpu.sh
# 또는
nvidia-smi
```

### 5) 보안 (SECURITY)

#### 5.1 설치 및 자동 스케줄 구성 (systemd timer)

```bash
sudo bash scripts/security/install.sh
sudo bash scripts/security/schedule.sh     # bb-security-scan.timer 생성/활성화
# 매일 02:30 실행 (Persistent)
# 유닛 이름: bb-security-scan.service / bb-security-scan.timer
```

상태 확인 및 로그:

```bash
systemctl status bb-security-scan.timer
journalctl -u bb-security-scan.service --no-pager
```

#### 5.2 수동 스캔 실행 (명시 동의 필요)

```bash
sudo bash scripts/security/scan.sh --yes
# 동의 없이 실행 시 종료 (throw/exit 1)
```

#### 5.3 스캔 요약/종료 코드 규약

```bash
bash scripts/security/summarize-last-scan.sh
# 탐지 발견 시: exit 2 (모니터/CI에서 즉시 감지)
# 로그 디렉터리: $PROJECT_STATE_DIR/security/
```

> 정책: **폴백 없음, 에러 즉시 중단**, 사용자 동의 플로우(`--yes`) 명시.

### 6) 네트워크 (NET), 7) 모니터링 (OPS)

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

# SECURITY 타이머/요약
systemctl status bb-security-scan.timer
bash scripts/security/summarize-last-scan.sh || echo "non-zero exit (검출 가능성)"
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

- **즉시 실패**: 예외를 덮지 않습니다. 실패는 빠르게 드러나야 복구가 빠릅니다.(`set -Eeuo pipefail`)
- **멱등성**: 재실행해도 같은 결과. 이미 구성된 리소스는 건너뛰되, 상태 검증은 엄격히 합니다.
- **명시성**: 선택지는 플래그로 드러냅니다(예: ML 드라이버 설치 여부).
- **가시성**: 실행 로그는 사람이 읽기 쉬워야 합니다.
- 폴백/유연성 대신 **명확한 예외(throw/exit)** 로 디버깅 용이성 우선

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

본 프로젝트는 Ubuntu 24.04 LTS에서 “**포맷 후 30분 내 복구**”를 목표로 합니다.

## 자주 사용하는 도구와 유즈케이스

Ubuntu 24.04 LTS 환경에서 매번 손으로 세팅하던 툴 중,  
**개인적으로 꼭 필요한 도구들**을 스크립트화했습니다.  
각 도구는 단순히 “깔아두면 좋은 것”이 아니라,  
**실제 개발·운영 시에 체감 효율을 높여주는 유틸리티**입니다.

---

### 🧩 시스템 / 쉘 유틸

| 도구             | 설명                                    | 주 사용 시나리오                                 |
| ---------------- | --------------------------------------- | ------------------------------------------------ |
| **htop**         | CPU/메모리/프로세스 실시간 모니터링     | 프로세스 급증 시 원인 파악, 백그라운드 부하 점검 |
| **ncdu**         | 디스크 사용량 트리뷰 형태로 표시        | `/var/log` 나 Docker 볼륨 등에서 용량 누수 진단  |
| **ripgrep (rg)** | ultra-fast grep 대체, `.gitignore` 인식 | 프로젝트 전체에서 특정 함수나 문자열 탐색        |
| **bat**          | `cat` 대체, 하이라이트·라인번호 지원    | 설정 파일(`*.conf`, `.env`) 빠르게 미리보기      |
| **tldr**         | `man` 페이지 요약                       | 잘 안 쓰는 명령어의 실전 예시 빠르게 확인        |
| **exa**          | `ls` 대체, 컬러·아이콘·Git 상태 표시    | 소스 디렉터리 탐색 시 가독성 향상                |

---

### 🧠 개발환경

| 도구                     | 설명                          | 주 사용 시나리오                                               |
| ------------------------ | ----------------------------- | -------------------------------------------------------------- |
| **VSCode**               | 표준 에디터 환경              | `scripts/dev/editors/extensions.txt`를 통한 일관된 확장팩 셋업 |
| **Node.js / npm / pnpm** | JS/TS 런타임                  | CLI, 프론트엔드 빌드, 스크립트 유틸 개발                       |
| **Python 3 + pipx**      | CLI 기반 자동화 스크립트 실행 | `yt-dlp`, `pre-commit`, `httpie` 등 파이썬 기반 툴 배포        |
| **Docker / Compose**     | 컨테이너 기반 개발환경        | Node, Python, DB 등을 로컬 격리된 형태로 실행                  |
| **GitHub CLI (`gh`)**    | PR/이슈/릴리스 자동화         | 로컬에서 `gh pr create` 등으로 바로 워크플로 연계              |

---

### 🎥 미디어 / 화상회의 / 스트리밍

| 도구                               | 설명                                              | 주 사용 시나리오                                                    |
| ---------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------- |
| OBS Studio (Flatpak)               | 방송·녹화뿐 아니라 화상회의용 가상 카메라로 사용  | Zoom/Meet 등 회의 도중에도 OBS 장면(Scene)을 가상 카메라로 송출     |
| PipeWire / PulseAudio              | 가상 장치 OBS용 모니터링 싱크 및 가상 마이크 구성 | 회의용 오디오 라우팅, 시스템 소리와 마이크 분리 녹음                |
| Active Noise / Echo Canceling 구성 | PipeWire 필터체인 기반 최소 구현                  | 노이즈 감소, 에코 억제 – 외부 마이크 없이도 명료한 회의 오디오 확보 |
| Lua DSP Chain 스크립트             | OBS 오디오 필터 체인 자동화                       | obs_dsp_chain.lua로 EQ, 컴프레서, 노이즈 게이트 자동 적용           |
| Chroma Key / Background Scene      | OBS에서 회의 배경을 간단히 크로마키로             | 처리 배경 제거 및 가상 스튜디오 느낌의 회의화면 연출                |

---

### 🧮 머신러닝 / GPU

| 도구                            | 설명              | 주 사용 시나리오                                  |
| ------------------------------- | ----------------- | ------------------------------------------------- |
| **CUDA / TensorRT / cuDNN**     | NVIDIA GPU 최적화 | TensorFlow/PyTorch 학습·추론 테스트               |
| **TensorFlow Jupyter Launcher** | 간이 개발 서버    | `scripts/ml/tf/run-jupyter.sh`로 즉시 노트북 실행 |
| **nvidia-smi**                  | GPU 상태 모니터링 | GPU 온도, 메모리, 프로세스 점검                   |

---

### 🔐 보안 / 네트워크 / 운영

| 도구                            | 설명                        | 주 사용 시나리오                          |
| ------------------------------- | --------------------------- | ----------------------------------------- |
| **UFW / fail2ban**              | 최소 방화벽·보안기초        | SSH 포트 보호, 불필요한 외부 접근 차단    |
| **clamav**                      | 파일 기반 악성코드 검사     | 주기적 크론/타이머 기반 보안 스캔         |
| **net-tools / iproute2 / nmap** | 네트워크 분석               | eth0/wlan0 경로, 포트 스캔, 라우팅 테스트 |
| **glances / btop**              | 실시간 시스템 상태 모니터링 | 리소스 변화 추적, 장시간 세션 안정성 확인 |

---

### 🛠 기타 추천 CLI

| 도구            | 설명                       | 주 사용 시나리오                     |
| --------------- | -------------------------- | ------------------------------------ |
| **fzf**         | fuzzy finder               | 파일 탐색, Git 브랜치/명령 이력 검색 |
| **curl / wget** | HTTP 테스트                | 간단한 REST API 호출, 파일 다운로드  |
| **jq**          | JSON 포매터                | REST 응답 가독성 향상, CLI 필터링    |
| **pre-commit**  | Git 훅 기반 코드 품질 체크 | 포맷팅, lint, secret 검출 자동화     |

---

## 도구 철학

이 레포의 도구 구성은 “**새로운 툴의 나열**”이 아니라  
“**개발자가 매일 쓰는 도구를 반복 설치하지 않아도 되는 환경**”을 만드는 데 초점이 있습니다.

- 흔하지만 강력한 도구를 **스크립트로 일괄 배포**
- 각 도구의 실제 유즈케이스를 **교육적 레퍼런스로 제공**
- 결과적으로 “**새로운 머신 = 바로 업무 시작 가능한 상태**”를 실현합니다.
