# devpath-frontend

**DevPath AI** 프론트엔드 모노레포입니다. 사용자 웹 / 관리자 웹 / 모바일 앱을 한 레포에서 관리합니다.

## 구조

**Dart pub workspaces + melos 7** 기반 Flutter 모노레포입니다(과거 React `web`/`admin`은 Flutter로 전환 완료).

```
devpath-frontend/
├── apps/
│   ├── web/      # 사용자 앱 (Flutter Web · 학습 경로·AI 멘토 접근·Home 공지)
│   ├── admin/    # 관리자 콘솔 (Flutter Web · 콘텐츠·FinOps·지원 요청)
│   └── mobile/   # 모바일 앱 (Flutter · 대시·퀵 캡처)
└── packages/
    ├── dp_core/    # 도메인·데이터 계층 (순수 Dart · API·SSE·모델·목)
    └── dp_design/  # 디자인 시스템 (Flutter · Material 3 토큰, SSoT=DESIGN.md)
```

| 영역 | 스택 |
|------|------|
| web / admin | Flutter Web · Dart · Riverpod 3 · go_router · (Sandbox: Monaco Editor) |
| mobile | Flutter · Dart · Riverpod 3 · go_router · (캐시: drift) |
| 공용 | dp_core(dio·SSE·freezed 모델·목 어댑터) · dp_design(테마·상태 위젯) |

## 실행

루트에서 **melos**로 워크스페이스를 다룹니다(설정은 루트 `pubspec.yaml`의 `workspace:`+`melos:`, 요약은 `melos_README.md`).

```bash
# 의존성 동기화 / 분석 / 테스트 / 포맷
dart pub get --enforce-lockfile
dart run melos bootstrap --enforce-lockfile
dart run melos run analyze
dart run melos run test
dart run melos run format   # 적용: dart run melos run fix
```

### 단일 앱 실행

```bash
cd apps/web && flutter run -d chrome    # admin 동일
cd apps/mobile && flutter run
```

## 환경 변수

런타임 설정(API 엔드포인트·`useMock` 등)은 **`--dart-define`**(또는 `--dart-define-from-file`)로 주입하고 `AppConfig.fromEnvironment`로 읽습니다. 기본값은 목 프로토라 별도 주입 없이도 실행됩니다. `HOME_BASE_URL`은 공지 feed와 Home CTA의 기준 URL이며 기본값은 `https://leva.ai.kr`입니다. 비밀값(키·토큰)은 **절대 커밋하지 않습니다** ([documents/10_환경_설정_템플릿](https://github.com/DevPathAi/documents/blob/main/10_환경_설정_템플릿.md)).

## 개발 규칙

- 화면 설계: [documents/06_화면_기능_정의서](https://github.com/DevPathAi/documents/blob/main/06_화면_기능_정의서.md) · [storyboard](https://github.com/DevPathAi/storyboard)
- Git 규칙: [documents/09_Git_규칙_정의서](https://github.com/DevPathAi/documents/blob/main/09_Git_규칙_정의서.md)
- 워크플로우 현황: [workflow-dashboard](https://devpathai.github.io/workflow-dashboard/)
- 로컬 계약과 이력: [`DESIGN.md`](./DESIGN.md) · [`TODOS.md`](./TODOS.md) · [`HANDOFF.md`](./HANDOFF.md) · [`melos_README.md`](./melos_README.md)
