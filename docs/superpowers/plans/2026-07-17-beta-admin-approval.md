# WS-C2a admin 실 인증 + 베타 승인 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** admin 앱이 실 OAuth로 ADMIN JWT를 얻어 실 `/admin` API로 베타 대기자를 승인/사전승인하게 만든다.

**Architecture:** platform이 `client_type=admin` OAuth 로그인을 admin 콜백으로 복귀시키고(모바일 마커 패턴 미러) ADMIN role은 베타 게이트를 우회한다. admin 앱은 web과 동일한 OAuth 왕복(`/auth/refresh`)으로 세션을 복원하고, users 화면에 BETA_PENDING 필터·승인 버튼·사전승인 폼을 추가한다.

**Tech Stack:** platform=Java 21·Spring Boot 4.0.7·Spring Security · admin=Flutter Web·Riverpod·go_router·Dio(dp_core)·melos.

## Global Constraints

- platform: Jackson 3(`tools.jackson`), `@ConfigurationPropertiesScan` 자동등록, 런타임 Flyway 없음. Conventional Commits. 작업 브랜치는 develop에서 분기, main·develop 직접 커밋 금지.
- admin(Flutter): 테스트는 `flutter_test`+`flutter_riverpod` `ProviderContainer`/위젯 테스트. OAuth 런처·ApiClient는 Provider override로 Fake 주입. 런타임 설정은 `--dart-define`(AppConfig.fromEnvironment). 비밀값 커밋 금지.
- admin OAuth 개시 URL 규약: `{apiBase}/oauth2/authorization/{provider}?client_type=admin` (provider=github|google).
- admin state 마커 문자열: `.admin.` (platform `MobileAwareAuthorizationRequestResolver.ADMIN_STATE_MARKER`). 모바일 마커 `.mobile.`와 구분.
- 모든 git/파일 명령은 절대경로 또는 `-C <레포 절대경로>` 사용(cwd 리셋 방지).
- 레포 절대경로: platform=`D:/workspace/dpa/devpath-platform-svc`, frontend=`D:/workspace/dpa/devpath-frontend`.

## 실행 순서

```
Phase P: devpath-platform-svc (admin OAuth enabler)  →  develop 머지
Phase F: devpath-frontend/apps/admin (실 인증 + 승인 UI)  [P 머지 후 실 e2e; 단위테스트는 Fake로 선행 가능]
```

- Phase P 브랜치: `git -C D:/workspace/dpa/devpath-platform-svc checkout develop && git -C D:/workspace/dpa/devpath-platform-svc pull && git -C D:/workspace/dpa/devpath-platform-svc checkout -b feat/beta-admin-oauth`
- Phase F 브랜치: `feat/beta-admin-approval` (이미 생성됨, 스펙 커밋 포함) — devpath-frontend.

---

## Phase P — devpath-platform-svc (admin OAuth enabler)

### Task P1: resolver에 admin 마커 추가

**Files:**
- Modify: `src/main/java/ai/devpath/platform/auth/MobileAwareAuthorizationRequestResolver.java`
- Test: `src/test/java/ai/devpath/platform/auth/MobileAwareAuthorizationRequestResolverTest.java` (신규)

**Interfaces:**
- Produces: 상수 `ADMIN = "admin"`, `ADMIN_STATE_MARKER = ".admin."`. `client_type=admin`이면 state = `<csrf>.admin.`.

- [ ] **Step 1: 실패 테스트 작성** — `MobileAwareAuthorizationRequestResolverTest.java`

```java
package ai.devpath.platform.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizationRequestResolver;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest;

class MobileAwareAuthorizationRequestResolverTest {

    private OAuth2AuthorizationRequest baseReq() {
        return OAuth2AuthorizationRequest.authorizationCode()
                .authorizationUri("https://p/authorize")
                .clientId("c").redirectUri("https://cb").state("csrf123").build();
    }

    private MobileAwareAuthorizationRequestResolver resolver(OAuth2AuthorizationRequest base) {
        OAuth2AuthorizationRequestResolver delegate = mock(OAuth2AuthorizationRequestResolver.class);
        HttpServletRequest req = mock(HttpServletRequest.class);
        when(delegate.resolve(req)).thenReturn(base);
        // client_type/code_challenge stubbing done per-test via req
        this.req = req;
        return new MobileAwareAuthorizationRequestResolver(delegate);
    }

    private HttpServletRequest req;

    @Test
    void adminClientType_appendsAdminMarker() {
        var base = baseReq();
        var resolver = resolver(base);
        when(req.getParameter("client_type")).thenReturn("admin");
        when(req.getParameter("code_challenge")).thenReturn(null);

        var out = resolver.resolve(req);

        assertThat(out.getState()).isEqualTo("csrf123.admin.");
    }

    @Test
    void noClientType_leavesStateUnchanged() {
        var base = baseReq();
        var resolver = resolver(base);
        when(req.getParameter("client_type")).thenReturn(null);
        when(req.getParameter("code_challenge")).thenReturn(null);

        var out = resolver.resolve(req);

        assertThat(out.getState()).isEqualTo("csrf123");
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.auth.MobileAwareAuthorizationRequestResolverTest"`
Expected: FAIL — admin 마커 미구현(state에 `.admin.` 없음).

- [ ] **Step 3: 구현** — `decorate`에 admin 분기 추가. 기존 모바일 분기 유지, 그 앞에 상수 추가:

```java
	static final String CLIENT_TYPE_PARAM = "client_type";
	static final String CODE_CHALLENGE_PARAM = "code_challenge";
	static final String MOBILE = "mobile";
	static final String MOBILE_STATE_MARKER = ".mobile.";
	static final String ADMIN = "admin";           // 신규
	static final String ADMIN_STATE_MARKER = ".admin.";  // 신규
```

`decorate` 메서드를, 기존 모바일 반환 앞에 admin 분기를 넣어 교체:

```java
	private OAuth2AuthorizationRequest decorate(OAuth2AuthorizationRequest req, HttpServletRequest request) {
		if (req == null) {
			return null;
		}
		String clientType = request.getParameter(CLIENT_TYPE_PARAM);
		// admin 웹 콘솔: challenge 불요. state에 admin 마커만 부여(success handler가 adminUrl로 복귀).
		if (ADMIN.equals(clientType)) {
			return OAuth2AuthorizationRequest.from(req)
					.state(req.getState() + ADMIN_STATE_MARKER)
					.build();
		}
		String challenge = request.getParameter(CODE_CHALLENGE_PARAM);
		// 모바일 + PKCE challenge가 모두 있을 때만 마커를 부여한다(없으면 웹 플로우).
		if (!MOBILE.equals(clientType) || challenge == null || challenge.isBlank()) {
			return req;
		}
		return OAuth2AuthorizationRequest.from(req)
				.state(req.getState() + MOBILE_STATE_MARKER + challenge)
				.build();
	}
```

클래스 javadoc에 "client_type=admin이면 `.admin.` 마커" 한 줄 추가.

- [ ] **Step 4: 통과 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.auth.MobileAwareAuthorizationRequestResolverTest"`
Expected: PASS (2 tests).

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/auth/MobileAwareAuthorizationRequestResolver.java src/test/java/ai/devpath/platform/auth/MobileAwareAuthorizationRequestResolverTest.java
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: OAuth resolver에 client_type=admin 마커 추가"
```

### Task P2: 핸들러 admin 복귀 분기 + adminUrl 설정

**Files:**
- Modify: `src/main/java/ai/devpath/platform/config/AuthProperties.java`
- Modify: `src/main/resources/application.yml`
- Modify: `src/main/java/ai/devpath/platform/auth/OAuth2LoginSuccessHandler.java`
- Test: `src/test/java/ai/devpath/platform/auth/OAuth2LoginSuccessHandlerBetaTest.java` (기존 파일에 케이스 추가)

**Interfaces:**
- Consumes: `MobileAwareAuthorizationRequestResolver.ADMIN_STATE_MARKER` (P1), `BetaGate.admit`(기존).
- Produces: `AuthProperties.getAdminUrl()`. admin 마커 로그인 → refresh 쿠키 + `adminUrl + "/auth/callback"` 리다이렉트.

- [ ] **Step 1: AuthProperties에 adminUrl 추가**

`AuthProperties.java`에 필드/게터/세터 추가(webUrl과 동형):
```java
	private String adminUrl;
	public String getAdminUrl() { return adminUrl; }
	public void setAdminUrl(String v) { this.adminUrl = v; }
```

- [ ] **Step 2: application.yml에 admin-url 추가** (`devpath.auth` 하위, `web-url` 옆)

```yaml
    admin-url: ${APP_ADMIN_URL:http://localhost:5174}
```

- [ ] **Step 3: 실패 테스트 작성** — `OAuth2LoginSuccessHandlerBetaTest.java`에 admin 리다이렉트 케이스 추가(기존 셋업 재사용). state에 `.admin.` 마커가 있을 때 `adminUrl/auth/callback`로 리다이렉트 + refresh 쿠키 설정을 단언:

```java
    @Test
    void adminMarkedLogin_setsRefreshCookie_redirectsToAdminCallback() throws Exception {
        when(betaGate.admit(any())).thenReturn(true);
        when(props.getWebUrl()).thenReturn("https://app.example");
        when(props.getAdminUrl()).thenReturn("https://admin.example");
        when(refreshStore.issue(anyLong())).thenReturn("rt");
        when(cookies.create("rt")).thenReturn(
                org.springframework.http.ResponseCookie.from("refresh_token", "rt").httpOnly(true).path("/").build());
        // request.getParameter("state") → csrf.admin.
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setParameter("state", "csrf.admin.");
        MockHttpServletResponse response = new MockHttpServletResponse();

        handler.onAuthenticationSuccess(request, response, authentication);

        assertEquals("https://admin.example/auth/callback", response.getRedirectedUrl());
        assertNotNull(response.getHeader(HttpHeaders.SET_COOKIE));
    }
```
> 기존 `OAuth2LoginSuccessHandlerBetaTest`의 셋업(`registration.registerOrFind`, `authorizedClients`, `authentication`, `user` mock/id)을 재사용한다. `MockHttpServletRequest`/`MockHttpServletResponse` import 확인.

- [ ] **Step 4: 실패 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.auth.OAuth2LoginSuccessHandlerBetaTest"`
Expected: FAIL — admin 분기 미구현(웹 기본 `/auth/callback`로 감).

- [ ] **Step 5: 핸들러에 admin 분기 추가** — 게이팅 통과 후, 모바일 마커 분기 **뒤**, 웹 기본 분기 **앞**에 삽입:

```java
		// admin 웹 콘솔: 웹과 동일하게 refresh 쿠키를 발급하되 adminUrl 콜백으로 복귀.
		if (state != null && state.contains(MobileAwareAuthorizationRequestResolver.ADMIN_STATE_MARKER)) {
			String refreshAdmin = refreshStore.issue(user.getId());
			response.addHeader(HttpHeaders.SET_COOKIE, cookies.create(refreshAdmin).toString());
			response.sendRedirect(props.getAdminUrl() + "/auth/callback");
			return;
		}
```
> `state`는 기존 코드에서 이미 `request.getParameter("state")`로 읽는 변수. 모바일 분기가 그 아래에서 `state`를 사용하므로, admin 분기는 모바일 분기 계산(`marker = state.indexOf(...)`) 이후·웹 refresh 발급 이전에 둔다. (모바일 마커 `.mobile.`와 admin 마커 `.admin.`는 상호 배타이므로 순서 안전.)

- [ ] **Step 6: 통과 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.auth.OAuth2LoginSuccessHandler*"`
Expected: PASS (기존 + admin 신규).

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add -A && git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: admin 마커 로그인을 adminUrl 콜백으로 복귀(+adminUrl 설정)"
```

### Task P3: BetaGate ADMIN 우회

**Files:**
- Modify: `src/main/java/ai/devpath/platform/beta/BetaGate.java`
- Test: `src/test/java/ai/devpath/platform/beta/BetaGateTest.java` (케이스 추가)

**Interfaces:**
- Produces: `admit`가 `role=ADMIN` 사용자에 대해 무조건 true(allowlist 조회·상태변경·이벤트 없음).

- [ ] **Step 1: 실패 테스트 작성** — `BetaGateTest.java`에 추가:

```java
    @Test
    void adminUser_isAdmittedWithoutAllowlistCheck() {
        User u = user("admin@devpath.ai", "ACTIVE");
        u.setRole("ADMIN");
        assertThat(gate.admit(u)).isTrue();
        verify(allow, never()).existsByEmail(any());
        verify(outbox, never()).save(any());
    }
```
> `user(email,status)` 헬퍼는 기존 테스트에 존재. `verify(allow, never())`용 `import static org.mockito.Mockito.never;`/`any` 확인. `allow`는 기존 `BetaAllowlistRepository` mock 필드명.

- [ ] **Step 2: 실패 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.beta.BetaGateTest"`
Expected: FAIL — 현재는 admin도 allowlist 조회.

- [ ] **Step 3: 구현** — `admit` 최상단에 ADMIN 우회 추가:

```java
	@Transactional
	public boolean admit(User user) {
		if ("ADMIN".equals(user.getRole())) {
			return true; // 관리자는 베타 게이트 우회(allowlist 무관) — 승인 주체이므로 항상 입장.
		}
		boolean allowed = allowlist.existsByEmail(normalize(user.getEmail()));
		// ... 기존 로직 유지
```

- [ ] **Step 4: 통과 확인**

Run: `./gradlew -p D:/workspace/dpa/devpath-platform-svc test --tests "ai.devpath.platform.beta.BetaGateTest"`
Expected: PASS (기존 4 + admin 1).

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add -A && git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat: BetaGate — ADMIN role 베타 게이트 우회"
```

### Task P4: platform PR

- [ ] `feat/beta-admin-oauth` → `develop` PR. CI 녹색 확인 후 머지(merge commit).

```bash
git -C D:/workspace/dpa/devpath-platform-svc push -u origin feat/beta-admin-oauth
gh -R DevPathAi/devpath-platform-svc pr create --base develop --head feat/beta-admin-oauth --title "feat: admin OAuth 복귀 경로 + ADMIN 게이트 우회 (WS-C2a)" --body "WS-C2a Phase P"
```

---

## Phase F — devpath-frontend/apps/admin  (브랜치 `feat/beta-admin-approval`)

> 기준 경로 `D:/workspace/dpa/devpath-frontend/apps/admin`. 테스트: 모노레포 루트에서 `cd apps/admin && flutter test` 또는 `dart pub global run melos run test`. 분석: `flutter analyze`(apps/admin).

### Task F1: OAuth 개시 (런처 + 로그인 리다이렉트)

**Files:**
- Create: `apps/admin/lib/src/features/auth/application/oauth_launcher.dart`
- Create: `apps/admin/lib/src/features/auth/application/oauth_launcher_web.dart`
- Create: `apps/admin/lib/src/features/auth/application/oauth_launcher_stub.dart`
- Modify: `apps/admin/lib/src/features/auth/application/auth_controller.dart` (login→OAuth)
- Modify: `apps/admin/lib/src/features/auth/presentation/login_page.dart` (실 버튼)
- Modify: `apps/admin/lib/src/providers/api_providers.dart` (withCredentials)
- Test: `apps/admin/test/features/auth/oauth_login_test.dart` (신규)

**Interfaces:**
- Produces: `oauthLauncherProvider` (Provider<OAuthLauncher>), `AdminAuthController.login({provider})` → `launcher.launch('{base}/oauth2/authorization/{provider}?client_type=admin')`.

- [ ] **Step 1: 런처 3파일 생성** (web `apps/web/lib/src/features/auth/application/oauth_launcher*.dart` 복제)

`oauth_launcher.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oauth_launcher_web.dart'
    if (dart.library.io) 'oauth_launcher_stub.dart';

abstract interface class OAuthLauncher {
  void launch(String url);
}

final oauthLauncherProvider = Provider<OAuthLauncher>(
  (ref) => createOAuthLauncher(),
);
```
`oauth_launcher_web.dart`:
```dart
import 'package:web/web.dart' as web;

import 'oauth_launcher.dart';

class _WebOAuthLauncher implements OAuthLauncher {
  const _WebOAuthLauncher();
  @override
  void launch(String url) {
    web.window.location.href = url;
  }
}

OAuthLauncher createOAuthLauncher() => const _WebOAuthLauncher();
```
`oauth_launcher_stub.dart`:
```dart
import 'oauth_launcher.dart';

class _StubOAuthLauncher implements OAuthLauncher {
  const _StubOAuthLauncher();
  @override
  void launch(String url) {
    throw UnsupportedError(
      'OAuthLauncher.launch is not supported on non-web platforms. '
      'Override oauthLauncherProvider in tests with a Fake.',
    );
  }
}

OAuthLauncher createOAuthLauncher() => const _StubOAuthLauncher();
```
> `web` 패키지가 admin pubspec에 없으면 web 앱과 동일 버전으로 추가(`apps/web/pubspec.yaml`의 `web:` 버전 확인 후 `apps/admin/pubspec.yaml`에 동일 추가, `melos bootstrap`).

- [ ] **Step 2: 실패 테스트 작성** — `apps/admin/test/features/auth/oauth_login_test.dart`

```dart
import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:devpath_admin/src/app/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  test('login() launches OAuth with client_type=admin', () async {
    final fake = _FakeLauncher();
    final container = ProviderContainer(overrides: [
      oauthLauncherProvider.overrideWithValue(fake),
      appConfigProvider.overrideWithValue(
        const AppConfig(baseUrl: 'https://api.test', useMock: false)),
    ]);
    addTearDown(container.dispose);

    await container.read(adminAuthProvider.notifier).login();

    expect(fake.launched, 'https://api.test/oauth2/authorization/github?client_type=admin');
  });
}
```
> `devpath_admin`는 admin pubspec의 package name(확인: `apps/admin/pubspec.yaml`의 `name:`). `AppConfig` 생성자 시그니처는 `apps/admin/lib/src/app/app_config.dart` 실측 후 맞춘다(baseUrl/useMock).

- [ ] **Step 3: 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/auth/oauth_login_test.dart`
Expected: FAIL — `AdminAuthController.login`이 아직 OAuth 런처를 쓰지 않음(현재 `/admin/auth/login` POST).

- [ ] **Step 4: 구현** — `AdminAuthController.login` 교체:

```dart
import 'oauth_launcher.dart';
// ...
  Future<void> login({String provider = 'github'}) async {
    final base = ref.read(appConfigProvider).baseUrl;
    ref.read(oauthLauncherProvider)
        .launch('$base/oauth2/authorization/$provider?client_type=admin');
  }
```
(기존 mock `POST /admin/auth/login` 로직 제거. `bootstrapFromCallback`은 F2에서 추가.)

`login_page.dart`: 버튼을 GitHub/Google OAuth로. `useMock` 분기 유지(mock이면 기존 즉시 인증은 F2의 bootstrap으로 대체되므로, 여기선 실 버튼 위주로):
```dart
FilledButton(
  onPressed: () => ref.read(adminAuthProvider.notifier).login(),
  child: const Text('GitHub로 관리자 로그인'),
),
const SizedBox(height: DpSpacing.sm),
OutlinedButton(
  onPressed: () => ref.read(adminAuthProvider.notifier).login(provider: 'google'),
  child: const Text('Google로 관리자 로그인'),
),
```

`api_providers.dart`: `apiClientProvider`에 `client.dio.options.extra['withCredentials'] = true;` 추가(web 패턴; HttpOnly refresh 쿠키 전송). refresh 배선은 F2.

- [ ] **Step 5: 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/auth/oauth_login_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/auth/application/oauth_launcher.dart apps/admin/lib/src/features/auth/application/oauth_launcher_web.dart apps/admin/lib/src/features/auth/application/oauth_launcher_stub.dart apps/admin/lib/src/features/auth/application/auth_controller.dart apps/admin/lib/src/features/auth/presentation/login_page.dart apps/admin/lib/src/providers/api_providers.dart apps/admin/test/features/auth/oauth_login_test.dart apps/admin/pubspec.yaml
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): OAuth 개시(client_type=admin) 실 로그인"
```

### Task F2: OAuth 콜백 → 세션 복원

**Files:**
- Modify: `apps/admin/lib/src/features/auth/application/auth_controller.dart` (bootstrapFromCallback)
- Create: `apps/admin/lib/src/features/auth/presentation/auth_callback_page.dart`
- Modify: `apps/admin/lib/src/app/router.dart` (/auth/callback 라우트 + 가드 허용)
- Modify: `apps/admin/lib/src/providers/api_providers.dart` (refresh 배선)
- Test: `apps/admin/test/features/auth/bootstrap_callback_test.dart` (신규)

**Interfaces:**
- Consumes: `apiClientProvider`, `tokenStoreProvider`(save), `dp_core` `User.fromJson`.
- Produces: `AdminAuthController.bootstrapFromCallback()` → `POST /auth/refresh` → `AdminAuthed(User)` | `AdminUnauthed(error)`.

- [ ] **Step 1: 실패 테스트 작성** — `apps/admin/test/features/auth/bootstrap_callback_test.dart`

ApiClient를 Fake로 override해 `/auth/refresh`가 `{access_token, user}`를 반환하면 `AdminAuthed`가 되는지 검증. web `apps/web/test`의 auth 컨트롤러 테스트 패턴을 참조해 ApiClient/tokenStore override를 구성한다(실측). 핵심 단언:
```dart
// refresh success (user.role=ADMIN) → state is AdminAuthed && isAdmin
// refresh 401(ApiException) → state is AdminUnauthed with error
```
> ApiClient를 어떻게 Fake로 주입하는지는 web 테스트(`apps/web/test/.../auth_*test.dart`)에서 확인해 동일 패턴 사용. 없으면 `apiClientProvider`를 Mock dio adapter로 override.

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/auth/bootstrap_callback_test.dart`
Expected: FAIL — `bootstrapFromCallback` 미존재.

- [ ] **Step 3: 구현**

`AdminAuthController`에 추가(web `AuthController.bootstrapFromCallback` 미러):
```dart
  Future<void> bootstrapFromCallback() async {
    try {
      final data = await ref.read(apiClientProvider)
          .post<Map<String, dynamic>>('/auth/refresh');
      await ref.read(tokenStoreProvider)
          .save(access: data['access_token'] as String, refresh: '');
      state = AdminAuthed(
        User.fromJson((data['user'] as Map).cast<String, dynamic>()));
    } on ApiException catch (e) {
      state = AdminUnauthed(error: e.message);
    } catch (_) {
      state = const AdminUnauthed();
    }
  }
```
(`import 'package:dp_core/dp_core.dart';` 확인.)

`auth_callback_page.dart` 생성(web `AuthCallbackPage` 미러):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

class AdminAuthCallbackPage extends ConsumerStatefulWidget {
  const AdminAuthCallbackPage({super.key});
  @override
  ConsumerState<AdminAuthCallbackPage> createState() => _S();
}

class _S extends ConsumerState<AdminAuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminAuthProvider.notifier).bootstrapFromCallback();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

`router.dart`: `/auth/callback` 라우트 추가 + 가드가 미인증 시에도 통과시키도록 수정:
```dart
String? adminGuard(AdminAuthState auth, String location) {
  final atLogin = location == '/login';
  final atCallback = location == '/auth/callback';
  if (auth is! AdminAuthed) return (atLogin || atCallback) ? null : '/login';
  if (!auth.isAdmin) return location == '/forbidden' ? null : '/forbidden';
  if (atLogin || atCallback) return '/dashboard';
  return null;
}
```
routes에 추가(ShellRoute 밖, /login 옆): `GoRoute(path: '/auth/callback', builder: (_, _) => const AdminAuthCallbackPage()),` + import.

`api_providers.dart`: AuthInterceptor의 `refresh`를 web 패턴으로 교체:
```dart
      refresh: (refreshToken) async {
        final data = await client.post<Map<String, dynamic>>('/auth/refresh');
        return TokenPair(access: data['access_token'] as String, refresh: '');
      },
```
(기존 `refresh: (refreshToken) async => null` 대체. `TokenPair` import는 dp_core.)

- [ ] **Step 4: 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/auth/bootstrap_callback_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/auth/application/auth_controller.dart apps/admin/lib/src/features/auth/presentation/auth_callback_page.dart apps/admin/lib/src/app/router.dart apps/admin/lib/src/providers/api_providers.dart apps/admin/test/features/auth/bootstrap_callback_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): OAuth 콜백→/auth/refresh 세션 복원"
```

### Task F3: UsersController 승인/사전승인

**Files:**
- Modify: `apps/admin/lib/src/features/users/application/users_controller.dart`
- Test: `apps/admin/test/features/users/approve_test.dart` (신규)

**Interfaces:**
- Produces: `UsersController.approve(String userId)` → `POST /admin/users/{id}/approve` 후 `load()`; `UsersController.preApprove(String email)` → `POST /admin/allowlist {email}`.

- [ ] **Step 1: 실패 테스트 작성** — `approve_test.dart`: apiClient를 Fake로 override, `approve('1')` 호출 시 `POST /admin/users/1/approve`가 나가고 이후 `load()`가 재호출(목록 fetch)됨을 검증; `preApprove('x@y.com')`가 `POST /admin/allowlist` body `{email:'x@y.com'}`를 보냄을 검증. (F1/F2 테스트의 ApiClient override 패턴 재사용.)

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/approve_test.dart`
Expected: FAIL — `approve`/`preApprove` 미존재.

- [ ] **Step 3: 구현** — `UsersController`에 추가(기존 `sanction` 패턴 참조):

```dart
  Future<void> approve(String userId) async {
    await ref.read(apiClientProvider)
        .post<void>('/admin/users/$userId/approve');
    await load();
  }

  Future<void> preApprove(String email) async {
    await ref.read(apiClientProvider)
        .post<void>('/admin/allowlist', body: {'email': email});
  }
```
> `ApiClient.post`의 `void` 제네릭·`body` 파라미터 시그니처는 기존 `sanction`(`post<Map<String,dynamic>>(..., body: {...})`)과 동일 형태를 따른다. 204 No Content이므로 반환 무시 — 기존 post가 빈 바디를 어떻게 다루는지 확인 후 `post<void>` 또는 `post<Map<String,dynamic>?>` 선택(실측).

- [ ] **Step 4: 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/approve_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/users/application/users_controller.dart apps/admin/test/features/users/approve_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): UsersController 승인/사전승인 호출"
```

### Task F4: 승인 UI (BETA_PENDING 필터 + 승인 버튼 + 사전승인 폼)

**Files:**
- Modify: `apps/admin/lib/src/features/users/presentation/users_page.dart`
- Test: `apps/admin/test/features/users/users_page_beta_test.dart` (신규)

**Interfaces:**
- Consumes: `UsersController.approve/preApprove`(F3), `setStatusFilter`(기존).

- [ ] **Step 1: 실패 테스트 작성** — 위젯 테스트: (a) 상태 필터에 `BETA_PENDING` 칩이 존재하고 탭하면 `setStatusFilter('BETA_PENDING')` 호출; (b) BETA_PENDING 행 선택 시 상세 패널에 "승인" 버튼이 뜨고 탭하면 `approve(row.id)` 호출; (c) 사전승인 이메일 필드+버튼이 존재. (UsersController를 spy/override로 주입해 호출 검증. `theme: DpTheme.light()` 부여, `tester.view.physicalSize` 설정.)

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/users_page_beta_test.dart`
Expected: FAIL — BETA_PENDING 칩·승인 버튼·사전승인 폼 미존재.

- [ ] **Step 3: 구현** — `users_page.dart` 수정:
  1. 상태 필터 칩 목록에 `'BETA_PENDING'` 추가: `for (final st in ['BETA_PENDING', 'ACTIVE', 'WARNED', 'SUSPENDED', 'BANNED'])`.
  2. `_SanctionPanel`을 상태별 액션 분기로 확장: 선택 행 status가 `BETA_PENDING`이면 "승인" `FilledButton`(→ `n.approve(r.id)` 후속 `DpEmpty`/목록 갱신은 controller의 `load()`가 처리), 아니면 기존 제재 버튼. 패널에 콜백 `onApprove` 추가.
  3. 화면 상단(AppBar `bottom` 아래 또는 body 상단)에 사전승인 폼: `TextField`(이메일) + `FilledButton('허용리스트 추가')` → `n.preApprove(email)` + 성공 스낵바. `TextEditingController` 상태 보관(StatefulWidget 이미 사용 중).

구체 위젯 코드는 기존 `users_page.dart` 구조(DataTable + `_SanctionPanel`)를 유지하며 위 3점을 최소 추가한다. 승인 버튼 예:
```dart
if (r.status == 'BETA_PENDING')
  FilledButton(
    onPressed: () => onApprove(r.id),
    child: const Text('승인'),
  )
else
  ...기존 제재 Wrap
```

- [ ] **Step 4: 통과 확인 + 분석**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test test/features/users/users_page_beta_test.dart && flutter analyze`
Expected: 테스트 PASS, analyze 무경고.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/admin/lib/src/features/users/presentation/users_page.dart apps/admin/test/features/users/users_page_beta_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(admin): 베타 대기자 승인 UI(필터·승인 버튼·사전승인 폼)"
```

### Task F5: frontend 검증 + PR

- [ ] **Step 1: 전체 admin 테스트 + 분석**

Run: `cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run analyze && dart pub global run melos run test` (또는 `cd apps/admin && flutter test && flutter analyze`)
Expected: 녹색.

- [ ] **Step 2: PR** — `feat/beta-admin-approval` → `develop`. CI(melos analyze/test) 녹색 후 머지. 스펙·플랜 문서 포함.

```bash
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/beta-admin-approval
gh -R DevPathAi/devpath-frontend pr create --base develop --head feat/beta-admin-approval --title "feat: admin 실 인증 + 베타 승인 UI (WS-C2a)" --body "WS-C2a Phase F. 전제: platform feat/beta-admin-oauth 머지."
```

---

## 통합 스모크 (선택, 배포 전)

- [ ] platform bootRun + admin `flutter run -d chrome --dart-define API_BASE_URL=... --dart-define USE_MOCK=false` + mock-oauth2-server(또는 실 GitHub, admin-email 계정)로: admin 로그인 → `?client_type=admin` → adminUrl/auth/callback 복귀 → /auth/refresh → ADMIN 대시보드. BETA_PENDING 필터→대기자→승인→목록에서 사라짐. 사전승인 폼→allowlist 추가.

---

## Self-Review (플랜↔스펙)

- **스펙 §2.1 admin 마커**: P1 커버. ✅
- **스펙 §2.2 핸들러 admin 복귀 + adminUrl**: P2 커버. ✅
- **스펙 §2.3 ADMIN 게이트 우회**: P3 커버. ✅
- **스펙 §3 admin 실 인증(개시·콜백·refresh·로그인 페이지)**: F1(개시·런처·login page·withCredentials) + F2(콜백·bootstrap·router·refresh 배선) 커버. ✅
- **스펙 §4 승인/사전승인 UI**: F3(컨트롤러) + F4(필터·승인 버튼·폼) 커버. ✅
- **스펙 §6 테스트**: 각 태스크 실패테스트 선행. ✅
- **타입 일관성**: `login({provider})`·`bootstrapFromCallback()`·`approve(String)`·`preApprove(String)`·`AdminAuthed(User)`·`ADMIN_STATE_MARKER=".admin."`·`getAdminUrl()` — 전 태스크 참조 일치. ✅
- **오픈 이슈(실측 필요, 구현 중 확인)**: (a) admin pubspec `name`·`web` 패키지 버전·`AppConfig` 생성자 시그니처, (b) web 테스트의 ApiClient Fake 주입 패턴, (c) `ApiClient.post` void/204 처리 방식. 각 태스크에 "실측" 문구로 명시.
- **비범위 확인**: C2b(web /beta-pending + pending-redirect 변경)는 이 플랜에 없음(별도). ✅
