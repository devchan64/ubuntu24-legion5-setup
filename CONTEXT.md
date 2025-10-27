# CONTEXT.md

> ChatGPT와 함께 관리되는 Ubuntu 24 Legion5 Setup 프로젝트의 컨텍스트 문서

---

## 1. 프로젝트 개요

이 프로젝트는 **Ubuntu 24.04 LTS(Xorg)** 기반의 개인 연구·개발 환경을  
자동화된 스크립트로 재현하기 위한 셋업 프로젝트입니다.

목표:

> “포맷 후 30분 내 완전 복구 가능한 표준화된 R&D 환경”

주요 영역:

- **개발환경(dev)** : Python, Node.js, Docker, NVIDIA Container Toolkit
- **AI(ai)** : TensorFlow GPU 컨테이너 + Jupyter 환경
- **Media(av)** : OBS Studio + PipeWire + 가상 마이크 및 에코 캔슬
- **보안(security)** : ClamAV / rkhunter / chkrootkit 자동 점검
- **운영(ops)** : 시스템 모니터링 및 로그 유틸리티

실행 원칙:

- **fail-fast** (폴백 없음, 오류 즉시 중단)
- **명확한 로그와 종료코드**
- **bash only**, POSIX 호환 문법
- **idempotent** (재실행 시 상태 불변)

---

## 2. 코드 및 스타일 규칙

### Bash 스크립트

- 항상 `set -Eeuo pipefail` 지정
- `lib/common.sh` 의 공통 함수(`log`, `err`, `need`, `as_root`)를 통해 제어
- `if` 조건문은 모호한 검사 금지 (`if [ -f file ]` 형태 명시)
- 하위 호환 or 폴백 코드 작성 금지
- 오류 발생 시 즉시 `exit 1` 또는 `throw` 유사 형태로 종료

### JavaScript / React

- **Hook은 항상 구조 분해 할당으로 사용**
  ```js
  const { getLatestDocumentBySchemaName } = useDocument();
  ```
- 불필요한 객체 체인 접근 금지 (useDocument().getLatestDocumentBySchemaName() 형태 금지)

-조건 타입 검사는 명시적 타입 체크로 대체

```js
if (!Array.isArray(items)) throw new Error("items must be array");
```

-`typeof push === "function"` 같은 동적 검사 금지

- 오류 발생 시 폴백 값 대신 throw new Error(...) 사용

## 3. ChatGPT 협업 규칙

ChatGPT는 이 문서의 규칙과 맥락을 항상 기준으로 reasoning 해야 함.
(README 또는 코드 수정 요청 시 이 문서를 참조)

- 수정 안내 시 “수정 전” / “수정 후” 모두 표시

  - 단, 30 라인 초과 시 “수정 후”만 출력

- diff 기호 (+ -) 사용 금지

- 코드 외 설명 시 간결한 문단 + 제목 표시

- ChatGPT가 제안하는 코드는 항상 set -Eeuo pipefail 과 명시적 오류처리 포함

- 하위 호환 대신 명시적 예외 (throw) 사용

- “개발 철학 또는 명명규칙” 변경 제안 시 항상 이 문서 갱신 제안 동반

## 4. 프로젝트 구조 요약

```tree
ubuntu24-legion5-setup/
├── README.md
├── CONTEXT.md             # ← 이 파일
├── lib/
│   └── common.sh          # 공통 유틸 (log, err, need, as_root 등)
├── scripts/
│   ├── sys/               # 시스템 기초 설정
│   ├── dev/               # Python/Node/Docker 환경
│   ├── ai/                # AI 연구 환경
│   ├── av/                # Audio/Video 환경(OBS, PipeWire)
│   ├── security/          # 보안 점검
│   ├── net/               # 네트워크 도구
│   └── ops/               # 운영 및 모니터링
└── tools/                 # 보조 유틸 및 메타 스크립트
```

주요 진입점:

- `scripts/install-all.sh` → 전체 설치 엔트리

- `scripts/cmd/dev.sh` → dev_main 엔트리

- `lib/common.sh` → 공용 함수 모듈

## 5. ChatGPT 이용 패턴 예시

| 상황             | ChatGPT 요청 예시                                                   |
| ---------------- | ------------------------------------------------------------------- |
| 새 스크립트 추가 | “scripts/net/add-wifi-tools.sh 를 추가하고 CONTEXT.md 에 반영해줘.” |
| 코드 리팩토링    | “CONTEXT.md 기준으로 명시적 throw 형태로 오류 처리하도록 수정해줘.” |
| 문서 보완        | “ChatGPT 협업 섹션을 강조해서 README.md 를 업데이트해줘.”           |
| 규칙 변경        | “이제 Bash 함수는 snake_case 로 통일, CONTEXT.md 에 추가해줘.”      |

## 6. 업데이트 로그

| 날짜       | 변경 요약                                | 작성자   |
| ---------- | ---------------------------------------- | -------- |
| 2025-10-27 | 초기 버전 작성 및 ChatGPT 협업 규칙 정의 | 심창보   |
| YYYY-MM-DD | 코드 스타일 갱신 또는 새 도메인 추가     | 작성자명 |
