# ubuntu24-legion5-setup

Ubuntu 24.04 LTS(X11) 기반 Lenovo Legion 5 개발/ML/미디어 환경을  
**포맷 후 30분 이내 완전 복구** 가능한 수준으로 자동화한 셋업 스크립트 모음입니다.

모든 스크립트는 Bash 단일 의존을 원칙으로 하며,  
에러 발생 시 즉시 중단(`set -Eeuo pipefail`).

---

## 📁 구조

```
lib/
  └─ common.sh            # 공통 유틸 (log/err/need/as_root 등)
scripts/
  ├─ sys/
  │   ├─ bootstrap.sh
  │   └─ xorg-ensure.sh
  ├─ dev/
  │   ├─ python/setup.sh
  │   ├─ node/setup.sh
  │   └─ docker/install.sh
  ├─ ml/tf/
  │   ├─ run-jupyter.sh
  │   └─ down-jupyter.sh
  ├─ media/
  │   ├─ video/obs-install.sh
  │   └─ audio/{enable-virtualmic.sh,echo-cancel.sh,create-obs-monitor-sink.sh,create-obs-virtual-mic.sh,install-virtual-audio.sh}
  ├─ security/av/
  │   ├─ install.sh
  │   ├─ scan.sh
  │   └─ schedule.sh
  ├─ net/tools-install.sh
  └─ ops/monitors-install.sh
```

---

## 🚀 시작하기

### 공통 부트스트랩
```bash
bash scripts/sys/bootstrap.sh
```

### 개발 도구
```bash
bash scripts/dev/python/setup.sh
bash scripts/dev/node/setup.sh
bash scripts/dev/docker/install.sh
```

### 오디오/비디오
```bash
bash scripts/media/video/obs-install.sh
bash scripts/media/audio/enable-virtualmic.sh
bash scripts/media/audio/echo-cancel.sh
```

### ML (TensorFlow Jupyter)
```bash
bash scripts/ml/tf/run-jupyter.sh
```

---

## ⚙️ Prerequisites (Ubuntu 24.04 LTS)

- **Xorg (X11)** 세션 필수  
  ```bash
  echo "$XDG_SESSION_TYPE"  # "x11" 이 출력되어야 합니다.
  ```
  Wayland 환경에서는 OBS/가상오디오/에코캔슬 기능이 제한될 수 있습니다.

- **NVIDIA 드라이버 ≥ 550**
  ```bash
  nvidia-smi
  ```

- **Docker + NVIDIA Container Toolkit**  
  ```bash
  docker --version
  nvidia-ctk --version
  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
  ```

- 필수 명령: `bash`, `curl`, `git`, `systemd --user`

---

## 🧰 Security Scan Guide

- **첫 실행 시간**: 수~십 분 소요  
- **오탐 주의**: rkhunter/chkrootkit은 환경에 따라 경고가 자주 발생할 수 있습니다.  
  반복되는 메시지는 드라이버/모듈 특성일 수 있으니 맥락을 검토하세요.  
- **종료 코드 정책**: 의심 항목 존재 시 비-0 종료 → 자동화/알림 연동에 유리합니다.  
- **리포트 보존 예시**
  ```bash
  $XDG_STATE_HOME/ubuntu24-legion5-setup/security/$(date +%Y%m%d)/summary.log
  ```

---

## 🧩 통합 설치 (추천)

모든 도메인을 한 번에 셋업하려면 아래를 실행하세요.

```bash
bash scripts/install-all.sh --all
```

개별 도메인만 설치하려면:

```bash
bash scripts/install-all.sh --sys --dev --ml --media
```

---

## ✅ 도메인 개요

| 도메인 | 기능 요약 |
|---------|------------|
| **sys** | 초기 부트스트랩, Xorg 환경 보정 |
| **dev** | Python / Node / Docker |
| **ml** | TensorFlow GPU Jupyter 컨테이너 |
| **media** | OBS, 가상마이크, 에코캔슬(Xorg 필요) |
| **security** | ClamAV / rkhunter / chkrootkit 설치 및 스케줄 |
| **net** | iftop, nethogs, bmon, tshark, iperf3 등 |
| **ops** | glances, nvtop, lm-sensors, btop 등 |

---

## 📜 정책 요약

- Bash 단일 의존
- 실패 시 즉시 종료
- 폴백 없음 (throw/exit-on-error)
- idempotent(중복 실행 안전) 개선 예정
- 로그 및 리포트 표준화 예정

---

## 🧱 Hardware Profile

- Base: Lenovo Legion 5 15IAX10  
- GPU: RTX 5070 Laptop  
- Display Server: Xorg (X11)  
- Ubuntu 24.04 LTS (Noble Numbat)

---

## 🧩 License

MIT License
