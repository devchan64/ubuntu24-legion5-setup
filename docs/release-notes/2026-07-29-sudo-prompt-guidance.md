# sudo 실행 안내 제거 및 인증 프롬프트 원칙 명시

## 변경 요약

스크립트 진입점을 `sudo`로 실행하도록 안내하지 않고, 권한이 필요한 하위 명령에서만 인증 프롬프트를 사용한다는 원칙을 명시했습니다.

## 주요 변경사항

- `AGENTS.md`에 일반 사용자 실행 원칙을 추가했습니다.
- 권한 상승이 필요한 작업은 해당 명령 실행 시점에만 `sudo` 인증 프롬프트를 사용하도록 안내를 정리했습니다.
- README 실행 방식과 Codex 계약 문구를 동일한 권한 모델로 맞췄습니다.
- 직접 `sudo -v`와 직접 APT sudo 호출 일부를 공통 sudo 계약 함수로 통일했습니다.

## 영향 범위

- `AGENTS.md`
- `README.md`
- `scripts/dev/github-web-login.sh`
- `scripts/media/camera/install-ai-virtual-cam.sh`
- `scripts/ml/setup-cuda-tensorrt.sh`

## 기대 효과

- 사용자가 `sudo ./scripts/install-all.sh ...` 형태로 실행해 사용자 홈, resume 상태, systemd user 설정 소유권을 깨는 상황을 방지합니다.
- 필요한 권한만 실행 중 프롬프트로 요청해 사용자 컨텍스트를 유지합니다.

## 검증

- sudo/root 실행 안내 문구 검색
- 대상 스크립트 Bash 구문 검사
