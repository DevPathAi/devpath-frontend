# WS-B. 데모 웹 이미지·빌드 설정 — 설계 (Flutter Web → Docker → gitops)

- 날짜: 2026-07-17
- 레포: devpath-frontend(주도: Dockerfile·CI) + devpath-gitops(이미지 태그 커밋 대상)
- 상태: 브레인스토밍 승인됨
- 상위 맥락: [documents/44_MVP_잔여_로드맵](https://github.com/DevPathAi/documents/blob/main/44_MVP_잔여_로드맵.md) · AWS k3s 실배포 + 홈페이지 연결 로드맵의 **워크스트림 B**

## 배경 / 목표

DevPath MVP를 `leva.ai.kr` 도메인에 베타/데모로 실배포하는 로드맵의 첫 코드 워크스트림이다.
전체 로드맵: **WS-B(본 문서) → WS-C 베타 허용리스트 → WS-D 인프라 브링업 → WS-A 홈페이지 연결 → WS-E 통합 검증**.

**해결할 공백(G1)**: `devpath-gitops/apps/devpath-web/base/deployment.yaml`은 `ghcr.io/devpathai/devpath-web:main` 이미지를 참조하지만, **이 이미지를 빌드·푸시하는 파이프라인이 없다**. `devpath-frontend/.github/workflows/ci.yml`에는 "React 전용 web-image/deploy 잡은 제거됨"이라는 NOTE만 있고 Flutter 웹 이미지 빌드가 부재하다.

**목표**: `apps/web`(Flutter Web)을 **실 API에 물린** Docker 이미지로 빌드·푸시하고, 백엔드 svc와 **동일한 CI 패턴**으로 gitops 이미지 태그를 갱신해 ArgoCD가 배포하게 한다.

## 확정 사실 (실측, 2026-07-17)

- **AppConfig 키** (`apps/web/lib/src/app/app_config.dart`):
  - `API_BASE_URL` (String, 기본 `https://mock.devpath.ai/api/v1`)
  - `USE_MOCK` (bool, 기본 `true`)
  - Flutter Web은 **빌드시 dart-define로 값이 구워진다**(런타임 주입 불가).
- **백엔드 이미지·CI 패턴** (`devpath-platform-svc`, 미러링 대상):
  - 루트 `Dockerfile` → ci.yml `image` 잡: `docker/build-push-action@v7`로 `ghcr.io/devpathai/<svc>:${{ github.sha }}`·`:main` 푸시.
  - `needs: image` 잡: GitHub App 토큰(`GITOPS_APP_ID`/`GITOPS_APP_PRIVATE_KEY`)으로 gitops 체크아웃 → kustomize v5.4.3 설치 → `kustomize edit set image ...=...:${{ github.sha }}`를 `gitops/apps/<svc>/base`에서 실행 → `devpath-gitops-bot[bot]`로 커밋·푸시.
  - **ArgoCD Image Updater 아님**: CI가 SHA 태그를 gitops에 커밋하고 ArgoCD가 auto-sync.
- **웹 라우팅**: `apps/web/web/index.html`에 표준 `<base href="$FLUTTER_BASE_HREF">`. 소스에 `usePathUrlStrategy` 호출 없음(기본 전략). nginx `try_files $uri $uri/ /index.html;` fallback이면 hash/path 양쪽에서 안전.
- **gitops 매니페스트** (`apps/devpath-web/base/deployment.yaml`): containerPort `8080`, readiness/liveness `httpGet path:/ port:8080`, resources requests cpu 50m/mem 64Mi, limit mem 128Mi.
- **frontend CI**: `subosito/flutter-action@v2` `channel: stable`(버전 미핀). melos 7.0.0 핀. 모노레포 = Dart pub workspaces + melos 7.

## 컴포넌트

### B1. Dockerfile — `apps/web/Dockerfile` (멀티스테이지)

**build stage** — Flutter SDK 이미지 기반(명시 stable 버전 핀, pubspec Dart `^3.12.1` 충족):
1. 모노레포 루트 컨텍스트에서 워크스페이스 복사(`packages/`·`apps/`·루트 `pubspec.yaml`/`pubspec.lock`).
2. `dart pub global activate melos 7.0.0` → `melos bootstrap`(워크스페이스 단일 해석).
3. `cd apps/web && flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL --dart-define=USE_MOCK=false`.
   - `API_BASE_URL`·`USE_MOCK`는 **Docker build ARG**로 받아 dart-define에 전달.

**runtime stage** — `nginx:alpine`:
- 빌드 산출물 `apps/web/build/web` → `/usr/share/nginx/html`.
- nginx conf: `listen 8080;` + `location / { try_files $uri $uri/ /index.html; }`.
- 매니페스트의 readiness/liveness(`:8080` `/`)와 일치.

> **빌드 컨텍스트 주의**: 모노레포 워크스페이스이므로 `melos bootstrap`이 `packages/dp_core`·`dp_design`를 해석해야 한다. Docker 빌드 컨텍스트는 **레포 루트**로 두고 `-f apps/web/Dockerfile`로 지정하거나, Dockerfile이 루트 기준 경로를 복사하도록 작성한다. `.dockerignore`로 `**/.dart_tool`·`**/build`·`node_modules`·`apps/*/build` 제외.

### B2. 빌드시 설정 주입

- `USE_MOCK=false` 고정(실 백엔드).
- `API_BASE_URL` 정확값은 **gateway 라우팅 확정(WS-D) 시점에 고정**. 잠정 `https://api.leva.ai.kr/api/v1`(AppConfig 기본값과 동일한 `/api/v1` prefix 형태). 본 워크스트림에서는 **CI repo variable로 파라미터화**하고, 실값 확정은 WS-D에서 반영한다(하드코딩 금지).

### B3. CI 잡 — `devpath-frontend/.github/workflows` (백엔드 패턴 미러링)

- 기존 `ci.yml`의 analyze/test/format 게이트는 **유지**(변경 없음).
- **`web-image` 잡**(트리거 `main` push): ghcr 로그인 → `docker/build-push-action@v7`로 `ghcr.io/devpathai/devpath-web:${{ github.sha }}`·`:main` 푸시. `build-args`로 `API_BASE_URL`(repo variable `WEB_API_BASE_URL`)·`USE_MOCK=false` 주입.
- **`web-deploy` 잡**(`needs: web-image`): GitHub App 토큰으로 gitops 체크아웃 → kustomize v5.4.3 → `kustomize edit set image ghcr.io/devpathai/devpath-web=ghcr.io/devpathai/devpath-web:${{ github.sha }}`를 `gitops/apps/devpath-web/base`에서 실행 → 커밋·푸시.
  - `secrets`: `GITOPS_APP_ID`·`GITOPS_APP_PRIVATE_KEY`(백엔드 svc와 동일 시크릿 재사용).

> **트리거 결정**: 백엔드와 동일하게 `main` push에서만 이미지 빌드·gitops 커밋(배포 revision=main). develop은 analyze/test만.

### B4. 검증 (이 워크스트림의 "테스트" = 빌드·렌더)

절대조건 2(Test-First)를 문서/인프라 산출물에 맞게 적용 — 구현 전 검증 절차를 먼저 고정한다:

1. **로컬 이미지 빌드**: `docker build -f apps/web/Dockerfile --build-arg API_BASE_URL=https://api.leva.ai.kr/api/v1 --build-arg USE_MOCK=false -t devpath-web:test .` (루트 컨텍스트) → 성공.
2. **기동·서빙**: `docker run -p 8080:8080 devpath-web:test` → `curl -f localhost:8080/` 200 + index.html 반환.
3. **설정 각인 확인**: `build/web/main.dart.js`(또는 컨테이너 내 산출물)에 mock 기본값(`mock.devpath.ai`)이 **없고** 실 baseURL이 반영됐는지 grep.
4. **SPA fallback**: 임의 경로 `curl -f localhost:8080/mentor` → 200(index.html) 확인(try_files 동작).
5. **gitops 렌더**: `kubectl kustomize apps/devpath-web/base` 정상(이미지 필드 갱신 후에도).

## 산출물

- `apps/web/Dockerfile` + `apps/web/.dockerignore`(또는 루트 `.dockerignore`) + nginx conf.
- `.github/workflows`에 `web-image`·`web-deploy` 잡(신규 워크플로 파일 또는 ci.yml 확장).
- (WS-D 연계) gitops `apps/devpath-web/base` 이미지 태그는 CI가 자동 커밋 — 본 워크스트림은 파이프라인만.

## 범위 밖

- **admin 이미지**: 공개 데모에 불필요 → WS-D 이후 선택적.
- **API_BASE_URL 실값 확정**: gateway 라우팅에 의존 → WS-D.
- **인프라·ingress·TLS·DNS**: WS-D.
- **베타 허용리스트**: WS-C.
- **홈페이지 배포·리브랜드**: WS-A.
- **런타임 설정 주입**(env.js 방식 등): 빌드시 dart-define로 충분하므로 도입하지 않음(YAGNI).

## 리스크 / 열린 항목

- **R1 모노레포 Docker 빌드 컨텍스트**: `melos bootstrap`이 워크스페이스 전체를 요구 → 루트 컨텍스트 필요. 빌드 캐시·이미지 크기 주의(.dockerignore로 완화).
- **R2 Flutter 버전 핀**: CI는 floating `stable`. Docker는 명시 버전 핀 → CI와 미세 불일치 가능. pubspec Dart `^3.12.1` 충족하는 stable로 핀하고, 향후 정렬은 후속.
- **R3 API_BASE_URL prefix**: `/api/v1` 포함 여부는 gateway 라우팅(WS-D)에서 최종 확인. 확정 전 하드코딩 금지, CI 변수로 유지.
