# devpath_web

DevPath 사용자 웹 앱(Flutter Web). 모노레포의 Dart pub workspace 멤버라(`resolution: workspace`) 의존성은 저장소 루트에서
받는다 — 절차는 [루트 README](../../README.md) 「실행」.

## 로컬 실행

```bash
# 목 데이터(기본값)
cd apps/web && flutter run -d chrome

# 실제 API — 게이트웨이(:8080)와 대상 서비스가 로컬에 떠 있어야 한다
cp apps/web/.env.local.example apps/web/.env.local   # .env.local 은 gitignore 대상
cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local
```

설정은 `--dart-define` 으로 넣고 `AppConfig.fromEnvironment`(`lib/src/app/app_config.dart`)가 읽는다.
`.env.local.example` 의 키는 `API_BASE_URL` · `USE_MOCK` 이다.

## 릴리스 이미지 (`Dockerfile`)

- **빌드 단계**: Flutter 3.44.1 · Dart 3.12.1 SDK 를 체크섬으로 고정해 받고, 커밋된 `pubspec.lock` 으로만 해석한다
  (`--enforce-lockfile`). Flutter Web 은 런타임 주입이 안 되므로 아래 빌드 인자를 `--dart-define` 으로 각인한다.

  | 빌드 인자 | 기본값 |
  |---|---|
  | `API_BASE_URL` | `https://api.leva.ai.kr` |
  | `USE_MOCK` | `false` |
  | `APP_VERSION` | `dev` |
  | `MISSION_SPINE_ENABLED` | `false` |
  | `ANALYTICS_CONTRACT_VERSION` | `mission-spine.analytics.v1`(다른 값이면 빌드 실패) |
  | `ANALYTICS_ENVIRONMENT` | `test` |

- **런타임 단계**: nginx 가 `build/web` 을 서빙한다. 텍스트·wasm·폰트 자산은 미리 gzip 해 두고(`gzip_static`),
  `nginx.conf` 는 `MISSION_*` 환경 변수만 치환하는 템플릿이다.
- **`release-entrypoint.sh`**: `MISSION_RELEASE_READY` 에 따라 기동 전에 `MISSION_*` 값을 검증한다.
  `true` 면 릴리스 id · candidate spec sha256 · 이미지 다이제스트 · 합성 프로브 토큰의 형식을, `false`(기본)면
  `unreleased`·0 다이제스트·`disabled` 기본값 그대로인지 확인한다.
