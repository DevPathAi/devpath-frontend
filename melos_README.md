# Melos 사용법 (devpath-frontend 모노레포)

## 최초 1회
- `dart pub global activate melos`
- PATH에 `~/.pub-cache/bin` 추가(필요 시). PATH 미설정 환경에선 `dart pub global run melos <명령>`으로 호출.

## 일상 명령
- 의존성 설치/동기화: `melos bootstrap` (별칭 `melos bs`)
- 정적 분석: `melos run analyze`
- 테스트: `melos run test`
- 포맷 검사/적용: `melos run format` / `melos run fix`

## 구조
- `packages/dp_core` — 도메인·데이터(UI 없음, 순수 Dart)
- `packages/dp_design` — 디자인 시스템(Material 3, 토큰 SSoT=DESIGN.md)
- `apps/{web,admin,mobile}` — Flutter 앱
- `landing/` — (P7) Jaspr 랜딩, workspace 편입 여부는 P7에서 결정

설정은 루트 `pubspec.yaml`의 `workspace:` + `melos:` 키(melos 7.x).
