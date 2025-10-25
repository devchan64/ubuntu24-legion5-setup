# 🧠 프로젝트 소개 — devchan64/ubuntu24-legion5-setup

## 개요

Ubuntu 24.04 LTS (**X11**) 기반의 개인 R&D 환경 자동화 셋업 프로젝트입니다.  
**“포맷 후 30분 내 완전 복구”**를 목표로, 자주 포맷하는 개발자가 매번 반복하는 셋업을 **Bash 스크립트 단위**로 표준화했습니다.

레노보 **리전 5 (Lenovo Legion 5)** — _15IAX10 U9 5070 Plus_ 모델(노트북 GPU: **GeForce RTX 5070 Laptop GPU**)을 기준 환경으로,

- AI 연구: **TensorFlow GPU Jupyter 컨테이너**
- 화상회의: **OBS + 가상 오디오(가상 마이크/모니터 싱크) + WebRTC 에코/노이즈 캔슬**
- 개발환경: **Python / Node.js / Docker + NVIDIA Container Toolkit**, (옵션) CUDA 네이티브
- 보안: **ClamAV + rkhunter + chkrootkit** 정밀 스캔 & 스케줄

모든 기능은 **Make 없이 Bash만**으로 동작하고, 실패 시 **즉시 종료**하며 로그를 남깁니다 (`set -Eeuo pipefail`).

---

## 🎯 프로젝트 목표

- 포맷 직후 **즉시 사용** 가능한 R&D 환경
- **도메인/기능별 세밀한 스크립트 분리**(단일 책임 원칙)
- 하위 호환/폴백 없이 **명시적 실패**
- **X11** 기준(화상회의/영상 처리 안정성 우선)
- 자주 쓰는 설정과 **보안 스캔 자동화** 포함

---

## 🧩 시스템 환경 (기준 예시)

| 항목          | 값                                   |
| ------------- | ------------------------------------ |
| **Laptop**    | Lenovo Legion 5 15IAX10 U9 5070 Plus |
| **CPU/GPU**   | **GeForce RTX 5070 Laptop GPU**      |
| **RAM / SSD** | 64 GB / 2 TB NVMe                    |

> 위 표에서 괄호 표기는 사용자가 실제 보유 사양으로 채워 넣으세요.

---

## 🗂 파일/도메인 구조

```
ubuntu24-legion5-setup/
├─ README.md
├─ lib/
│  └─ common.sh                      # 공통 유틸: log/err/need/as_root/락/Ubuntu 확인
├─ scripts/
│  ├─ sys/
│  │  ├─ bootstrap.sh                # apt 업데이트, 기본 패키지, UFW
│  │  └─ xorg-ensure.sh              # Xorg 세션 확인/가이드
│  ├─ dev/
│  │  ├─ python/
│  │  │  └─ setup.sh                 # pipx/venv/ipykernel/linters
│  │  ├─ node/
│  │  │  └─ setup.sh                 # nvm + pnpm(corepack)
│  │  └─ docker/
│  │     └─ install.sh               # Docker CE + NVIDIA Container Toolkit
│  ├─ ai/
│  │  └─ tf/
│  │     ├─ run-jupyter.sh           # TF GPU Jupyter 컨테이너 실행
│  │     └─ down-jupyter.sh          # 컨테이너 중지
│  ├─ av/
│  │  ├─ video/
│  │  │  └─ obs-install.sh           # OBS(Flatpak) 설치
│  │  └─ audio/
│  │     ├─ enable-virtualmic.sh     # OBS_Monitor/OBS_VirtualMic 생성 (systemd --user)
│  │     └─ echo-cancel.sh           # WebRTC Echo/Noise cancel {on|off}
│  ├─ security/
│  │  └─ av/
│  │     ├─ install.sh               # ClamAV + rkhunter + chkrootkit
│  │     ├─ scan.sh                  # 전체 스캔 + 요약(비-0 종료)
│  │     └─ schedule.sh              # 주간 자동 스캔 타이머(systemd --user)
│  ├─ net/
│  │  └─ tools-install.sh            # iftop/nethogs/bmon/tshark/iperf3
│  └─ ops/
│     └─ monitors-install.sh         # glances/nvtop/lm-sensors/btop
└─ tools/                             # (옵션) 유틸/스니펫
```

---

## 📜 도메인별 스크립트 목록

- **sys/**: `bootstrap.sh`, `xorg-ensure.sh`
- **dev/python/**: `setup.sh`
- **dev/node/**: `setup.sh`
- **dev/docker/**: `install.sh`
- **ai/tf/**: `run-jupyter.sh`, `down-jupyter.sh`
- **av/video/**: `obs-install.sh`
- **av/audio/**: `enable-virtualmic.sh`, `echo-cancel.sh`
- **security/av/**: `install.sh`, `scan.sh`, `schedule.sh`
- **net/**: `tools-install.sh`
- **ops/**: `monitors-install.sh`

---

## 🚀 시작하기

```bash
# 1) 리포 클론
git clone https://github.com/devchan64/ubuntu24-legion5-setup.git
cd ubuntu24-legion5-setup

# 2) 시스템/기본
bash scripts/sys/bootstrap.sh

# 3) 개발환경
bash scripts/dev/python/setup.sh
bash scripts/dev/node/setup.sh
bash scripts/dev/docker/install.sh

# 4) AI (TensorFlow Jupyter)
bash scripts/ai/tf/run-jupyter.sh      # http://localhost:8888
# 중지: bash scripts/ai/tf/down-jupyter.sh

# 5) 화상회의 (OBS/Audio/Noise)
bash scripts/av/video/obs-install.sh
bash scripts/av/audio/enable-virtualmic.sh
bash scripts/av/audio/echo-cancel.sh on   # off 로 비활성화

# 6) 네트워크/시스템 모니터
bash scripts/net/tools-install.sh
bash scripts/ops/monitors-install.sh
```

---

## 🔐 보안 / 백신 도메인 예시

```bash
# 설치
bash scripts/security/av/install.sh
# 즉시 스캔
bash scripts/security/av/scan.sh
# 주간 자동 스케줄 등록 (일 03:00)
bash scripts/security/av/schedule.sh
```

> 감염/의심 탐지 시 **비-0 종료** → CI/알림 연동에 유리

---

## 📦 이전 스크립트 가져오기(통합 계획)

- 업로드한 `a.zip`을 분석하여 **도메인별 이동 제안 CSV**(`mapping_suggestion.csv`)를 생성했습니다.
- CSV의 `suggested_target`을 검토/수정 후, `tools/migrate_from_zip.sh` 스니펫(README 내)을 사용해 자동 배치할 수 있습니다.
- 배치 후에는 각 스크립트 상단 헤더를 `lib/common.sh` 스타일로 통일하세요.

---

## 🧭 로드맵

- [ ] OBS 플러그인/장면 프리셋 자동화 스크립트
- [ ] TensorRT/cuDNN 네이티브 설치 스크립트(선택)
- [ ] `meeting-ready` / `ai-ready` 스크립트 번들
- [ ] Slack/Webhook 연동: 보안 스캔 결과 알림
- [ ] WSL2/Server 변형 프로필 (서브레포 or 브랜치)

---

## 👤 제작자

**[@devchan64](https://github.com/devchan64)**

> “자주 포맷하는 개발자가 귀찮음을 자동화한 Ubuntu 24 연구개발 플랫폼”  
> Python·Node·Docker·TensorFlow·OBS·Audio·AV 보안 도메인을 모두 Bash로 정리한 개인 R&D 환경 표준화 프로젝트.
