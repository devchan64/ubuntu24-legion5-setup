# CONTEXT.md

> ubuntu24-legion5-setup 컨텍스트(SSOT)

## 1) 목적

Ubuntu 24.04 LTS(noble) + **GNOME on Xorg** 환경에서 포맷 후 개발/ML/미디어/보안/운영 도구를
**bash 스크립트로 재현**한다.

- 원칙: fail-fast(폴백 없음), 명시적 계약 검증, 재실행 가능(idempotent)
- 이어하기(resume): 완료 단계는 상태파일로 기록하고 재실행 시 스킵
- 재부팅 경계(reboot barrier): 드라이버/커널 등 **재부팅이 필요한 단계는 barrier를 세우고 즉시 종료**. 재부팅 후에만 다음 단계 진행.

## 2) 실행 모델

엔트리포인트(Dispatcher): `scripts/install-all.sh`

- `scripts/cmd/<command>.sh` 를 source 후 `<command>_main` 실행
- command: `dev | sys | net | ops | security | media | ml | all`
- all 순서(코드 기준): `dev → sys → net → ops → security → media → ml`

글로벌 옵션(install-all.sh):

- `--yes` : 비대화형 진행
- `--debug` : set -x + 디버그
- `--reset` : 선택 command의 resume 상태 초기화

주요 env:

- `LEGION_SETUP_ROOT` : 레포 루트(우선/강제). 미지정 시 자동 해석
- `LEGION_ASSUME_YES` : `--yes` 반영(0/1)
- `LEGION_DEBUG` : `--debug` 반영(0/1)
- `RESUME_SCOPE_KEY` : resume 스코프(예: `cmd:media`)

## 3) 공통 규약(Contract)

- bash 전용: 모든 스크립트는 `set -Eeuo pipefail`
- 공통 유틸은 `lib/common.sh` 가 SSOT
  - `log/warn/err` (에러 즉시 종료)
  - `must_run_or_throw <relpath> [args...]` (상대경로 실행; **-x(실행권한) 필수**, bash로 실행)
  - resume API: `resume_step <scope> <stepKey> -- <cmd...>`

> Domain rule: SSOT API 이름/시그니처는 `lib/common.sh`를 기준으로만 한다. 별칭/폴백 금지.

### 3.1 Resume(이어하기)

- resume 상태파일: `~/.local/state/ubuntu24-legion5-setup/resume.<scope>.done`
  - **stepKey 변경은 breaking** (기존 상태파일과 비호환)

### 3.2 Reboot barrier(재부팅 경계)

드라이버/커널/디스플레이 스택처럼 재부팅이 요구되는 단계는 **‘재부팅 전에는 다음 단계 진행 불가’**를 계약으로 강제한다.

- reboot barrier 상태파일(SSOT): `~/.local/state/ubuntu24-legion5-setup/reboot.required`
- 동작 규칙:
  - 어떤 step이 재부팅이 필요하면 `require_reboot_or_throw <reason>` 호출
    - barrier 파일 생성(생성시각/boot_id/reason 기록)
    - 즉시 `err` 종료 (Fail-Fast)

  - dispatcher 시작 시:
    - `clear_reboot_barrier_if_rebooted` 로 boot_id 변경을 감지하면 barrier 자동 해제
    - barrier가 남아있으면 `assert_no_reboot_barrier_or_throw` 로 즉시 실패

> Domain rule: “재부팅 요구 단계는 성공 후에도 **‘완료(done)’로 마킹하지 않는다**. `require_reboot_or_throw`는 즉시 종료하므로 `resume_step`의 done 마킹이 발생하지 않는다.”

권한:

- root가 필요한 작업은 sudo 재실행 또는 내부에서 sudo 요구(우회 금지)

## 4) 구조(현재 레포)

```tree
ubuntu24-legion5-setup/
├── README.md
├── CONTEXT.md
├── lib/common.sh
└── scripts/
    ├── install-all.sh
    ├── cmd/{dev,sys,net,ops,security,media,ml}.sh
    ├── dev/*
    ├── sys/*
    ├── net/*
    ├── ops/*
    ├── security/*
    ├── media/*
    └── ml/*
```

## 5) 도메인 핵심 요약

- sys: 24.04 계약 + Xorg 활성 세션 요구, 일부 단계는 root로 디스패처를 sudo 재호출
  - NVIDIA/PRIME/커널 모듈 등 재부팅이 필요한 단계는 reboot barrier로 경계 강제

- media: OBS **apt-only** 정책(Flatpak 혼재/단독은 즉시 실패), v4l2loopback 영구 설정

- ml: CUDA/TensorRT 및 TF 컨테이너 유틸(verify/run)

- security: 설치/스캔/스케줄/요약

- dev/net/ops: 개발 도구체인/네트워크 도구/모니터링 유틸

## 6) ChatGPT 협업 규칙

- SSOT는 top-level(문서/상수)로 유지, 계약 검증은 entry에서만 수행(실패=throw/err)
- side effect(설치/파일쓰기/systemd 변경)는 명시적으로 묶어서 설명/코드화
- 출력: 30라인 미만은 Before/After, 30라인 이상은 After 전체 + 함수별 설명

### ReleaseNote(major/breaking)

resume stepKey/command 순서/정책(예: apt-only) 등 **호환성 깨짐** 변경은
해당 파일에 `# [ReleaseNote] ...` 한 줄로 요약(100자 내).

## 7) 업데이트 로그

| 날짜       | 변경                                                                     |
| ---------- | ------------------------------------------------------------------------ |
| 2025-10-27 | 초기 버전 작성 및 ChatGPT 협업 규칙 정의                                 |
| 2026-02-11 | 레포 구조/디스패처/Resume/옵션/ReleaseNote 규칙을 코드와 일치하도록 갱신 |
| 2026-02-11 | 재부팅 경계(reboot barrier) 계약 추가(드라이버/커널 단계 진행 금지)      |
