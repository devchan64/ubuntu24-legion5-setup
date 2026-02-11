# CONTEXT.md

> ubuntu24-legion5-setup 컨텍스트(SSOT)

## 1) 목적

Ubuntu 24.04 LTS(noble) + **GNOME on Xorg** 환경에서 포맷 후 개발/ML/미디어/보안/운영 도구를
**bash 스크립트로 재현**한다.

- 원칙: fail-fast(폴백 없음), 명시적 계약 검증, 재실행 가능(idempotent)
- 이어하기(resume): 완료 단계는 상태파일로 기록하고 재실행 시 스킵

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
  - `log/warn/err`(에러 즉시 종료)
  - `must_run <relpath>` (상대경로 실행; *.sh/*.py 분기)
  - resume API: `resume_run_step_or_throw <scope> <stepKey> -- <cmd...>`
- resume 상태파일: `~/.local/state/ubuntu24-legion5-setup/resume.<scope>.done`
  - **stepKey 변경은 breaking** (기존 상태파일과 비호환)

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

| 날짜 | 변경 | 작성자 |
| --- | --- | --- |
| 2025-10-27 | 초기 버전 작성 및 ChatGPT 협업 규칙 정의 | 심창보   |
| 2026-02-11 | 레포 구조/디스패처/Resume/옵션/ReleaseNote 규칙을 코드와 일치하도록 갱신 | 심창보 |
