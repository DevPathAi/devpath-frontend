# Melos 사용법 (devpath-frontend 모노레포)

## 최초 1회
- `dart pub get --enforce-lockfile`
- 전역 Melos를 설치하지 않는다. 커밋된 `pubspec.lock`의 버전을 `dart run melos <명령>`으로 호출한다.

## 일상 명령
- 의존성 설치/동기화: `dart run melos bootstrap --enforce-lockfile`
- 정적 분석: `dart run melos run analyze`
- 테스트: `dart run melos run test`
- 포맷 검사/적용: `dart run melos run format` / `dart run melos run fix`

## 구조
- `packages/dp_core` — 도메인·데이터(UI 없음, 순수 Dart)
- `packages/dp_design` — 디자인 시스템(Material 3, 토큰 SSoT=DESIGN.md)
- `apps/{web,admin,mobile}` — Flutter 앱
- 마케팅 홈페이지는 별도 `devpath-home-page` 저장소에 있으며 이 workspace의 멤버가 아니다.

설정은 루트 `pubspec.yaml`의 `workspace:` + `melos:` 키(melos 7.x).
