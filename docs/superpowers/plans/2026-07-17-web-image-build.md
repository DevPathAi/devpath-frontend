# WS-B 데모 웹 이미지·빌드 설정 Implementation Plan

> **Historical plan — do not execute.** 이후 릴리스 보안 작업에서 mutable 태그와 Frontend CI의 직접 GitOps 변경을 제거했다. 아래 App 자격증명 예시는 폐기된 흐름을 설명하는 비실행 placeholder이며 실제 시크릿으로 만들거나 재사용하면 안 된다.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`(Flutter Web)을 실 API에 물린 Docker 이미지로 빌드하고, 백엔드 svc와 동일한 CI 패턴으로 ghcr 푸시 + gitops 이미지 태그 커밋을 자동화한다.

**Architecture:** 멀티스테이지 Dockerfile(cirruslabs/flutter로 워크스페이스 부트스트랩→`flutter build web` dart-define 주입 → nginx:alpine `:8080` 정적 서빙 + SPA fallback). CI 두 잡(`web-image` ghcr 푸시 / `web-deploy` gitops kustomize 태그 커밋)을 `main` push에서만 실행 — devpath-platform-svc의 `image`·`deploy` 잡을 그대로 미러링.

**Tech Stack:** Flutter Web(Dart pub workspaces + melos 7) · Docker(멀티스테이지) · nginx:alpine · GitHub Actions(`docker/build-push-action@v7`·`actions/create-github-app-token@v3`·kustomize v5.4.3) · gitops(ArgoCD auto-sync).

## Global Constraints

- 브랜치: `feat/web-image-build`(이미 `develop`에서 분기됨)에서 작업. `develop`·`main` 직접 커밋 금지. 완료 후 → `develop` PR.
- `USE_MOCK=false` 고정(실 백엔드).
- `API_BASE_URL`은 **하드코딩 금지** — CI repo variable `WEB_API_BASE_URL`로 주입. 실값 확정은 WS-D(gateway 라우팅). 로컬 검증 시 잠정 `https://api.leva.ai.kr/api/v1` 사용.
- Docker 빌드 컨텍스트 = **레포 루트**(모노레포 워크스페이스 해석 필요). Dockerfile은 `apps/web/Dockerfile`, 빌드는 `-f apps/web/Dockerfile .`.
- runtime = `nginx:alpine`, `listen 8080`, `try_files $uri $uri/ /index.html;`(매니페스트 readiness/liveness `:8080 /`와 일치).
- 이미지 태그: `ghcr.io/devpathai/devpath-web:${{ github.sha }}` + `:main`. gitops 커밋은 GitHub App 토큰(`GITOPS_APP_ID`/`GITOPS_APP_PRIVATE_KEY`).
- `web-image`·`web-deploy` 잡은 `if: github.ref == 'refs/heads/main'`. 기존 `analyze-test` 게이트는 변경 없이 유지하고 `needs:`로 선행.
- Flutter SDK 이미지 = `ghcr.io/cirruslabs/flutter:stable`(CI의 floating `channel: stable`과 정렬 — Dart↔Flutter 버전 매핑 추측 회피). pubspec Dart `^3.12.1`.
- 커밋: Conventional Commits, 태스크마다 커밋.

---

### Task 1: Docker 이미지 (Dockerfile + nginx conf + .dockerignore)

`apps/web`를 실 API 설정으로 빌드해 nginx로 서빙하는 이미지를 만든다. 이 태스크의 "테스트"는 **로컬 이미지 빌드·기동·서빙 검증**이다(인프라 산출물 → 빌드/런타임 관찰이 곧 테스트).

**Files:**
- Create: `apps/web/Dockerfile`
- Create: `apps/web/nginx.conf`
- Create: `.dockerignore` (레포 루트)

**Interfaces:**
- Consumes: 루트 `pubspec.yaml`(워크스페이스 멤버 `packages/dp_core`·`packages/dp_design`·`apps/web`·`apps/admin`·`apps/mobile`), `apps/web/lib/src/app/app_config.dart`의 dart-define 키 `API_BASE_URL`·`USE_MOCK`.
- Produces: 이미지가 build ARG `API_BASE_URL`·`USE_MOCK`를 받아 `:8080`에서 정적 서빙. CI(Task 2)가 이 Dockerfile을 `-f apps/web/Dockerfile .`로 빌드.

- [ ] **Step 1: 실패 확인 (Dockerfile 부재 → 빌드 실패)**

Run (레포 루트 `devpath-frontend/`에서):
```bash
docker build -f apps/web/Dockerfile --build-arg API_BASE_URL=https://api.leva.ai.kr/api/v1 --build-arg USE_MOCK=false -t devpath-web:test .
```
Expected: FAIL — `failed to read dockerfile: open apps/web/Dockerfile: no such file or directory`.

- [ ] **Step 2: `.dockerignore` 작성 (레포 루트)**

빌드 컨텍스트에서 불필요·대용량 산출물을 제외한다(컨텍스트 전송·이미지 크기 완화).
```
.git
.github
**/.dart_tool
**/build
**/.dockerignore
node_modules
**/node_modules
landing
docs
test
**/test
**/*.iml
.gitconfig-codex
```
> `landing`(워크스페이스 밖 Jaspr)·`docs`·`test`는 웹 빌드에 불필요. `**/build`·`**/.dart_tool`는 로컬 캐시 제외.

- [ ] **Step 3: `apps/web/nginx.conf` 작성**

```nginx
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

- [ ] **Step 4: `apps/web/Dockerfile` 작성 (멀티스테이지)**

```dockerfile
# ---- build stage: Flutter Web ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=https://api.leva.ai.kr/api/v1
ARG USE_MOCK=false

WORKDIR /src
# 워크스페이스 전체 복사(Dart pub workspaces 단일 해석에 전 멤버 필요)
COPY . .

# melos 부트스트랩(CI와 동일한 흐름) — pub-cache/bin을 PATH에 추가
ENV PATH="/root/.pub-cache/bin:${PATH}"
RUN dart pub global activate melos 7.0.0 \
 && melos bootstrap

# 실 API 설정을 빌드시 각인(Flutter Web은 런타임 주입 불가)
RUN cd apps/web \
 && flutter build web --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=USE_MOCK=${USE_MOCK}

# ---- runtime stage: nginx ----
FROM nginx:alpine AS runtime
COPY --from=build /src/apps/web/build/web /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
```
> `git` 트리에 `--dart-define`을 넣는 이유: `AppConfig.fromEnvironment`가 `String.fromEnvironment('API_BASE_URL')`·`bool.fromEnvironment('USE_MOCK')`로 읽으며 기본값이 mock(`https://mock.devpath.ai/api/v1`, `true`)이라 명시 주입이 없으면 mock으로 빌드된다.

- [ ] **Step 5: 이미지 빌드 (Step 1 명령 재실행 → 성공)**

Run (레포 루트):
```bash
docker build -f apps/web/Dockerfile --build-arg API_BASE_URL=https://api.leva.ai.kr/api/v1 --build-arg USE_MOCK=false -t devpath-web:test .
```
Expected: PASS — 빌드 완료(`naming to docker.io/library/devpath-web:test`). (Flutter 웹 빌드로 수 분 소요·SDK 다운로드 정상)

- [ ] **Step 6: 기동·서빙 검증**

Run:
```bash
docker run -d --name devpath-web-test -p 8080:8080 devpath-web:test
curl -f -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/
curl -f -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/mentor
```
Expected: 두 요청 모두 `200`(루트 index.html + SPA fallback으로 `/mentor`도 index.html 반환).

- [ ] **Step 7: 설정 각인 검증 (mock 기본값 미포함)**

Run:
```bash
docker run --rm devpath-web:test sh -c "grep -rl 'mock.devpath.ai' /usr/share/nginx/html || echo 'NO_MOCK_DEFAULT'"
docker rm -f devpath-web-test
```
Expected: `NO_MOCK_DEFAULT`(빌드 산출물에 mock 기본 baseURL이 없음 = 실 `API_BASE_URL`이 각인됨).
> 만약 `mock.devpath.ai`가 검출되면 dart-define 주입 실패 — Dockerfile의 ARG→`--dart-define` 전달을 점검(추측 금지, 원인 규명 후 수정).

- [ ] **Step 8: Commit**

```bash
git add apps/web/Dockerfile apps/web/nginx.conf .dockerignore
git commit -m "feat(web): Flutter Web Docker 이미지(멀티스테이지 nginx:8080 + dart-define 실API 주입)"
```

---

### Task 2: CI 잡 (`web-image` + `web-deploy`)

`main` push 시 이미지를 ghcr에 푸시하고 gitops 이미지 태그를 커밋한다. devpath-platform-svc `ci.yml`의 `image`·`deploy` 잡을 미러링한다.

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: Task 1의 `apps/web/Dockerfile`(빌드 컨텍스트 `.`), repo variable `WEB_API_BASE_URL`, secrets `GITOPS_APP_ID`·`GITOPS_APP_PRIVATE_KEY`(백엔드 svc와 공유), gitops `apps/devpath-web/base/kustomization.yaml`의 `images[0].name = ghcr.io/devpathai/devpath-web`.
- Produces: `ghcr.io/devpathai/devpath-web:<sha>`·`:main` 이미지 + gitops `apps/devpath-web/base` 이미지 태그 자동 커밋 → ArgoCD 배포.

- [ ] **Step 1: `ci.yml`에 `web-image`·`web-deploy` 잡 추가**

`.github/workflows/ci.yml`의 기존 `analyze-test` 잡은 그대로 두고, 파일 하단 NOTE 주석(28~30행)을 실제 잡으로 교체한다. 아래를 `analyze-test` 잡 아래에 추가:

```yaml
  web-image:
    needs: analyze-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v6
      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v7
        with:
          context: .
          file: apps/web/Dockerfile
          push: true
          build-args: |
            API_BASE_URL=${{ vars.WEB_API_BASE_URL }}
            USE_MOCK=false
          tags: |
            ghcr.io/devpathai/devpath-web:${{ github.sha }}
            ghcr.io/devpathai/devpath-web:main

  web-deploy:
    needs: web-image
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/create-github-app-token@v3
        id: app-token
        with:
          app-id: ${{ secrets.LEGACY_RELEASE_WRITER_APP_ID_DO_NOT_USE }}
          private-key: ${{ secrets.LEGACY_RELEASE_WRITER_APP_PRIVATE_KEY_DO_NOT_USE }}
          owner: DevPathAi
          repositories: devpath-gitops
      - uses: actions/checkout@v6
        with:
          repository: DevPathAi/devpath-gitops
          token: ${{ steps.app-token.outputs.token }}
          path: gitops
      - name: Install kustomize
        run: |
          curl -sLo kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.3/kustomize_v5.4.3_linux_amd64.tar.gz
          tar -xzf kustomize.tar.gz && sudo mv kustomize /usr/local/bin/
      - name: set image to commit SHA
        working-directory: gitops/apps/devpath-web/base
        run: kustomize edit set image ghcr.io/devpathai/devpath-web=ghcr.io/devpathai/devpath-web:${{ github.sha }}
      - name: commit & push
        working-directory: gitops
        run: |
          git config user.name "devpath-gitops-bot[bot]"
          git config user.email "devpath-gitops-bot[bot]@users.noreply.github.com"
          git add -A
          git diff --cached --quiet && echo "no change" && exit 0
          git commit -m "deploy(web): ${{ github.sha }}"
          for i in 1 2 3; do git push && break || (git pull --rebase && sleep 2); done
```

그리고 기존 28~30행의 `# NOTE: React 전용 ...` 주석 블록을 삭제한다(더 이상 유효하지 않음).

- [ ] **Step 2: 워크플로 YAML 유효성 검증**

Run:
```bash
python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
```
Expected: `YAML OK`. (`actionlint`이 설치돼 있으면 `actionlint .github/workflows/ci.yml`도 실행 — 없으면 생략)

- [ ] **Step 3: 미러링 정합 확인 (구조 리뷰)**

다음을 눈으로 확인한다(백엔드 `deploy` 잡과 1:1 대응):
- `web-image` 태그가 `:${{ github.sha }}`·`:main` 2개.
- `web-deploy`의 `working-directory`가 `gitops/apps/devpath-web/base`(web 경로).
- `kustomize edit set image`의 좌변 name이 gitops kustomization `images[0].name`(`ghcr.io/devpathai/devpath-web`)과 일치.
- 두 잡 모두 `if: github.ref == 'refs/heads/main'`.

Run(대상 name 일치 재확인):
```bash
grep -n "ghcr.io/devpathai/devpath-web" ../devpath-gitops/apps/devpath-web/base/kustomization.yaml
```
Expected: `name: ghcr.io/devpathai/devpath-web` 라인이 존재(이미 `images:` 필드 있음 → `kustomize edit set image`가 `newTag` 갱신).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(web): Flutter Web 이미지 빌드·gitops 배포 잡 추가(main push, 백엔드 패턴 미러링)"
```

---

## 완료 후 (PR)

- `feat/web-image-build` → `develop` PR 생성. 본문: WS-B(스펙 링크) 요약 + "실제 이미지 빌드·배포는 develop→main 릴리스 후 `main` push에서 트리거됨" 명시.
- CI `analyze-test`(analyze/test/format) 녹색 확인 후 머지(브랜치 전략 2단계).
- **후속 의존(범위 밖·문서화만)**: `WEB_API_BASE_URL` repo variable 실값은 WS-D(gateway 라우팅 확정)에서 설정. GitHub App secrets(`GITOPS_APP_ID`/`GITOPS_APP_PRIVATE_KEY`)는 백엔드 svc에서 이미 사용 중인 조직 시크릿 재사용.

## Self-Review (작성자 체크)

**Spec coverage:** B1 Dockerfile=Task1(Step3·4) / nginx·SPA fallback=Task1(Step3,6) / B2 빌드시 설정=Task1(Step4)+Global Constraints(WEB_API_BASE_URL) / B3 CI web-image·web-deploy=Task2 / B4 검증(빌드·curl·grep·gitops 렌더)=Task1 Step5~7·Task2 Step3. 전 항목 커버.
**Placeholder scan:** TBD/TODO 없음. 모든 코드 블록 실내용. `API_BASE_URL` 실값은 의도적 파라미터화(Global Constraints·후속에 명시).
**Type consistency:** dart-define 키 `API_BASE_URL`·`USE_MOCK`(AppConfig 실측)·이미지 name `ghcr.io/devpathai/devpath-web`(gitops kustomization 실측)·경로 `apps/devpath-web/base`(gitops 실측) 전부 일치.
