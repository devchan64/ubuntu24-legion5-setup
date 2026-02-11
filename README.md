# Ubuntu 24 Legion5 Setup

Ubuntu **24.04 LTS (noble, Xorg)** 환경에서
**개발 / AI / 미디어(OBS) / 네트워크 / 운영 / 보안** 설정을
**Fail-Fast · 멱등(resumable) · 무폴백** 원칙으로 자동화합니다.

> 철학
>
> - 폴백 없음 (전제 불충족 시 즉시 실패)
> - 실패 즉시 종료 (`set -Eeuo pipefail`)
> - 단계 단위 멱등성(resume)
> - 재부팅 경계(reboot barrier) 계약 강제
> - 로그는 원인 추적 가능해야 함

본 레포는 **ChatGPT와 컨텍스트를 공유**하며 발전시키기 위해
설계/규약을 `CONTEXT.md`에 **SSOT**로 유지합니다.

---

## 대상 환경 (Reference)

- **OS**: Ubuntu 24.04 LTS (`noble`)
- **세션**: **Xorg** (Wayland 미지원 단계 존재)
- **쉘**: **bash 전용**
- **하드웨어(참고)**: Lenovo Legion 5 15IAX10
  (Intel iGPU + NVIDIA dGPU Hybrid)

---

## 핵심 문서

- 📘 **[CONTEXT.md](./CONTEXT.md)**
  프로젝트 철학, 구조, 실행 계약, resume 및 reboot barrier 규칙의 **SSOT**

---

## 디렉터리 구조

```text
.
├── install-all.sh          # 최상위 디스패처 (SSOT)
├── lib/
│   └── common.sh           # 공통 유틸 / 로깅 / resume / reboot barrier 관리
├── scripts/
│   ├── cmd/                # 진입점 커맨드 (dev/sys/media/...)
│   │   ├── dev.sh
│   │   ├── sys.sh
│   │   ├── net.sh
│   │   ├── ops.sh
│   │   ├── security.sh
│   │   ├── media.sh
│   │   └── ml.sh
│   ├── dev/
│   ├── sys/
│   ├── net/
│   ├── ops/
│   ├── security/
│   ├── media/
│   └── ml/
└── background/
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

> 순서는 의존성을 반영하며 임의 변경 불가 (Breaking)

---

## 도메인별 가이드

각 도메인은 **독립 실행 가능**하지만, 전체 실행 시에는 정해진 순서를 따릅니다.
아래 가이드는 _단독 실행_ 및 _문제 발생 시 재실행_ 기준입니다.

---

### dev (개발 환경)

**목적**

- 개발자 기본 도구 체인 구성
- 컨테이너/에디터/빌드 환경 준비

**포함 예시**

- Docker / NVIDIA Container Toolkit
- 코드 에디터 및 확장

```bash
./install-all.sh dev
```

**계약**

- 이후 단계(sys, ml)에서 GPU 설정을 참조
- 실패 시 전체 실행 중단이 정상 동작

---

### sys (시스템 / Xorg / PRIME)

**목적**

- OS 레벨 설정 및 하드웨어 의존 구성

**포함 예시**

- Xorg 보장
- GNOME 튜닝
- PRIME 전환
- 커널/디스플레이 스택 설정

```bash
./install-all.sh sys
```

**계약**

- root 권한 필수 (자동 sudo 재실행)
- NVIDIA/PRIME 전환 시 **reboot barrier 발생 가능**
- 재부팅 전에는 다음 단계 진행 불가

---

### net (네트워크)

**목적**

- 네트워크 안정성 및 외부 연결 확보

**포함 예시**

- Wi-Fi 드라이버
- VPN / 네트워크 유틸

```bash
./install-all.sh net
```

**계약**

- 네트워크 단절 상태 → 즉시 실패
- 드라이버 설치 시 reboot barrier 가능

---

### ops (운영)

**목적**

- 시스템 운영 편의성 및 모니터링 기반 마련

```bash
./install-all.sh ops
```

---

### security (보안)

**목적**

- 기본 보안 정책 적용 및 하드닝

```bash
./install-all.sh security
```

**주의사항**

- 네트워크 정책 변경 후 재접속 필요 가능

---

### media (미디어 / OBS)

**목적**

- 스트리밍/녹화 환경 구성

```bash
./install-all.sh media
```

**계약**

- OBS는 **apt-only 정책**
- 커널 모듈(v4l2loopback 등) 설치 시 reboot barrier 가능

---

### ml (AI / ML)

**목적**

- GPU 기반 AI/ML 실행 환경 구축

```bash
./install-all.sh ml
```

**계약**

- Secure Boot 비활성 권장
- 드라이버 설치 후 **reboot barrier 필수 발생 가능**

---

## 전역 옵션

| 옵션      | 설명                         |
| --------- | ---------------------------- |
| `--yes`   | 모든 동의 프롬프트 자동 승인 |
| `--debug` | `set -x` 기반 상세 로그      |
| `--reset` | resume 상태 초기화 후 재실행 |

예시:

```bash
./install-all.sh media --yes --debug
```

---

## Resume (이어하기) 메커니즘

- 상태 파일:

```
~/.local/state/ubuntu24-legion5-setup/resume.<scope>.done
```

- 완료된 step은 자동 skip
- **Step Key 변경 = Breaking Change**

---

## Reboot Barrier (재부팅 경계)

재부팅이 필요한 단계는 다음 규칙을 따릅니다:

1. `require_reboot_or_throw <reason>` 호출
2. `reboot.required` 상태파일 생성
3. 즉시 종료 (Fail-Fast)
4. 재부팅 후 dispatcher 재실행
5. boot_id 변경 감지 시 barrier 자동 해제

> 재부팅 전에는 어떤 도메인도 진행되지 않음.

---

## 실패 처리 규칙

- 전제조건 불충족 → 즉시 `err`
- 부분 성공 허용 ❌
- 롤백 없음
- 사용자는 원인 수정 후 재실행

---

## 설계 원칙 요약

- SSOT: `install-all.sh` + `CONTEXT.md`
- 계약은 코드로 강제
- 문서와 코드 불일치 = 버그
- 사람보다 스크립트가 항상 옳다

---

## 라이선스 / 사용

- 개인 환경 자동화 목적
- 팀/조직 사용 시 fork 후 정책 확장 권장
