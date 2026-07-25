# 데스크탑 세션 환경 출력 계약 수정

## 변경 요약

`scripts/sys/_desktop-session-env.sh`가 `eval` 가능한 export 문만 표준 출력으로 내보내도록 수정했습니다.

## 주요 변경사항

- 데스크탑 세션 환경 추출 중 sudo 인증 로그가 표준 출력에 섞이지 않도록 stderr로 분리했습니다.
- `legion-hdmi-layout.sh`와 `gnome-nord.sh`에서 환경 추출 결과를 `eval`할 때 로그 문자열이 명령으로 실행되는 문제를 방지했습니다.

## 영향 범위

- `scripts/sys/_desktop-session-env.sh`
- `scripts/sys/legion-hdmi-layout.sh`
- `scripts/sys/gnome-nord.sh`

## 기대 효과

- HDMI 레이아웃 적용 중 `[INFO: 명령어를 찾을 수 없음` 오류가 발생하지 않습니다.
- 세션 환경 추출 함수의 stdout 계약이 명확하게 유지됩니다.

## 검증

- `bash -n`으로 변경된 스크립트 문법을 확인했습니다.
- sudo 인증 로그가 stdout 대신 stderr로 분리되도록 변경 내용을 확인했습니다.
