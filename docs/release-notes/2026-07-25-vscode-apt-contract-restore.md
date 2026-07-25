# VS Code APT 저장소 단일화 계약 복구

## 변경 요약

설치 스크립트가 호출하는 VS Code APT 저장소 단일화 공통 함수를 `lib/common.sh`에 복구했습니다.

## 주요 변경사항

- `apt_fix_vscode_repo_singleton` 공통 계약 함수를 복구했습니다.
- 기존 Microsoft VS Code 저장소 항목을 정리하는 `apt_remove_repo_lines_globally` 보조 함수를 복구했습니다.
- Microsoft keyring과 `vscode.sources` Deb822 저장소 파일을 단일 경로로 다시 생성합니다.

## 영향 범위

- Docker 개발 환경 설치
- VS Code 설치
- 네트워크 도구 설치
- 모니터링 도구 설치
- 보안 도구 설치

## 기대 효과

- 설치 중 `apt_fix_vscode_repo_singleton: 명령어를 찾을 수 없음` 오류가 발생하지 않습니다.
- VS Code APT 저장소와 keyring 구성이 공통 SSOT를 통해 일관되게 적용됩니다.

## 검증

- `bash -n lib/common.sh scripts/dev/docker/install.sh scripts/dev/editors/install-vscode.sh scripts/net/tools-install.sh scripts/ops/monitors-install.sh scripts/security/install.sh`
- `lib/common.sh` 로드 후 공통 함수 정의 확인
