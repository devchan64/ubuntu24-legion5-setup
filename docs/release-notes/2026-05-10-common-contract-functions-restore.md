# Release Note: 공통 계약 함수 복구

## 변경 요약

`lib/common.sh`에서 누락된 공통 계약 함수(`ensure_root_or_reexec_with_sudo_or_throw`, `require_ubuntu_2404`)를 복구했습니다.

## 주요 변경사항

- `lib/common.sh`
  - root 재실행 계약 함수 복구
  - Ubuntu 24.04 강제 계약 함수 복구

## 영향 범위

- `scripts/sys/xorg-ensure.sh`
- `scripts/sys/bootstrap.sh`
- `scripts/ops/monitors-install.sh`
- `scripts/security/install.sh`
- `scripts/security/scan.sh`
- `scripts/dev/python/install.sh`
- `scripts/dev/editors/install-vscode.sh`
- `scripts/dev/docker/install.sh`
- `scripts/net/tools-install.sh`

위 스크립트들의 공통 계약 호출이 정상 동작합니다.

## 기대 효과

- 공통 함수 미정의로 인한 즉시 실패가 제거됩니다.
- 루트/OS 계약이 SSOT(`lib/common.sh`) 기준으로 일관 적용됩니다.

## 검증

- `bash -n lib/common.sh scripts/install-all.sh scripts/cmd/sys.sh scripts/sys/xorg-ensure.sh scripts/sys/bootstrap.sh scripts/ops/monitors-install.sh`
