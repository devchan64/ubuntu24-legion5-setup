# Ubuntu 24 Legion5 Setup

Ubuntu **24.04 LTS (noble, Xorg)** 환경에서
**개발 / AI / 미디어(OBS) / 네트워크 / 운영 / 보안** 설정을
**Fail-Fast · 멱등(resumable) · 무폴백** 원칙으로 자동화합니다.

> 철학
>
> * 폴백 없음 (전제 불충족 시 즉시 실패)
> * 실패 즉시 종료 (`set -Eeuo pipefail`)
> * 단계 단위 멱등성(resume)
> * 로그는 원인 추적 가능해야 함

본 레포는 **ChatGPT와 컨텍스트를 공유**하며 발전시키기 위해
설계/규약을 `CONTEXT.md`에 **SSOT**로 유지합니다.

---

## 대상 환경 (Reference)

* **OS**: Ubuntu 24.04 LTS (`noble`)
* **세션**: **Xorg** (Wayland 미지원 단계 존재)
* **쉘**: **bash 전용**
* **하드웨어(참고)**: Lenovo Legion 5 15IAX10
  (Intel iGPU + NVIDIA dGPU Hybrid)

---

## 핵심 문서

* 📘 **[CONTEXT.md](./CONTEXT.md)**
  프로젝트 철학, 구조, 실행 계약, resume 규칙의 **SSOT**

---

## 디렉터리 구조

```text
.
├── install-all.sh          # 최상위 디스패처 (SSOT)
├── lib/
│   └── common.sh           # 공통 유틸 / 로깅 / resume 관리
├── scripts/
│   ├── cmd/                # 진입점 커맨드 (dev/sys/media/...)
│   │   ├── dev.sh
│   │   ├── sys.sh
│   │   ├── net.sh
│   │   ├── ops.sh
│   │   ├── security.sh
│   │   ├── media.sh
│   │   └── ml.sh
│   ├── dev/                # 개발환경 세부 단계
│   ├── sys/                # 시스템/Xorg/전원/커널
│   ├── net/                # 네트워크/와이파이/VPN
│   ├── ops/                # 운영/모니터링
│   ├── security/           # 보안/하드닝
│   ├── media/              # OBS/오디오/가상캠
│   └── ml/                 # CUDA/AI/ML 스택
└── background/             # 데스크탑 배경 리소스
```

---

## 실행 방식

### 1. 전체 실행

```bash
./install-all.sh all
```

### 2. 단일 도메인 실행

```bash
./install-all.sh dev
./install-all.sh sys
./install-all.sh media
```

### 3. 실행 순서 (코드 기준, SSOT)

`all` 실행 시 **아래 순서로 고정**됩니다:

```
dev → sys → net → ops → security → media → ml
```

> 순서는 의존성을 반영하며 임의 변경 불가

---

## 도메인별 가이드

각 도메인은 **독립 실행 가능**하지만, 전체 실행 시에는 정해진 순서를 따릅니다.
아래 가이드는 *단독 실행* 및 *문제 발생 시 재실행* 기준으로 작성되었습니다.

### dev (개발 환경)

**목적**

* 개발자 기본 도구 체인 구성
* 컨테이너/에디터/빌드 환경 준비

**포함 예시**

* Docker / NVIDIA Container Toolkit
* 코드 에디터 및 확장

**실행**

```bash
./install-all.sh dev
```

**주의사항**

* 이후 단계(sys, ml)에서 GPU 설정을 참조함
* dev 단계 실패 시 전체 실행을 중단하는 것이 정상

---

### sys (시스템 / Xorg)

**목적**

* OS 레벨 설정 및 하드웨어 의존 구성

**포함 예시**

* Xorg / GNOME 튜닝
* 전원 관리 / 커널 파라미터

**실행**

```bash
./install-all.sh sys
```

**계약**

* root 권한 필수 (자동 sudo 재실행)
* 재부팅이 요구될 수 있음

---

### net (네트워크)

**목적**

* 네트워크 안정성 및 외부 연결 확보

**포함 예시**

* Wi-Fi 드라이버
* VPN / 네트워크 유틸

**실행**

```bash
./install-all.sh net
```

**주의사항**

* 네트워크 단절 상태에서는 즉시 실패

---

### ops (운영)

**목적**

* 시스템 운영 편의성 및 모니터링 기반 마련

**포함 예시**

* 로그 / 상태 확인 도구
* 운영 자동화 스크립트

**실행**

```bash
./install-all.sh ops
```

---

### security (보안)

**목적**

* 기본 보안 정책 적용 및 하드닝

**포함 예시**

* 방화벽 설정
* 보안 관련 시스템 옵션

**실행**

```bash
./install-all.sh security
```

**주의사항**

* 네트워크 정책 변경으로 재접속 필요 가능

---

### media (미디어 / OBS)

**목적**

* 스트리밍/녹화 환경 구성

**포함 예시**

* OBS Studio
* 가상 오디오 / 가상 카메라

**실행**

```bash
./install-all.sh media
```

**주의사항**

* 커널 모듈 설치 후 재부팅 필요할 수 있음

---

### ml (AI / ML)

**목적**

* GPU 기반 AI/ML 실행 환경 구축

**포함 예시**

* NVIDIA Driver / CUDA
* AI 프레임워크

**실행**

```bash
./install-all.sh ml
```

**계약**

* Secure Boot 비활성 권장
* 드라이버 설치 후 재부팅 필수

---

## 전역 옵션

| 옵션        | 설명                  |
| --------- | ------------------- |
| `--yes`   | 모든 동의 프롬프트 자동 승인    |
| `--debug` | `set -x` 기반 상세 로그   |
| `--reset` | resume 상태 초기화 후 재실행 |

예시:

```bash
./install-all.sh media --yes --debug
```

---

## Root 권한 계약

* `sys` 도메인은 **root 필수**
* 일반 사용자 실행 시 자동으로 `sudo -E` 재실행
* 권한 승격 불가 시 **즉시 실패**

---

## Resume (이어하기) 메커니즘

* 각 단계 성공 시 상태 파일 생성:

  ```
  $PROJECT_STATE_DIR/resume.<scope>.done
  ```
* 재실행 시 완료된 step은 자동 skip
* **Step Key 변경 = Breaking Change**

> ⚠️ Step 이름을 바꾸면 반드시 문서/릴리즈 노트에 명시

---

## 실패 처리 규칙

* 전제조건 불충족 → 즉시 `err`
* 부분 성공 허용 ❌
* 롤백 없음
* 사용자는 **원인 수정 후 재실행**

---

## NVIDIA / GPU 관련 주의

* Secure Boot **비활성 권장**
* 드라이버 설치 후 **재부팅 필수**
* HDMI/외부 모니터는 Hybrid 구성 영향 받음
* 관련 이슈는 `sys` 또는 `ml` 단계에서 처리

---

## 설계 원칙 요약

* SSOT: `install-all.sh` + `CONTEXT.md`
* 계약은 **코드로 강제**
* 문서와 코드 불일치 = 버그
* 사람보다 **스크립트가 항상 옳다**

---

## 라이선스 / 사용

* 개인 환경 자동화 목적
* 사내/팀 사용 시 fork 권장
