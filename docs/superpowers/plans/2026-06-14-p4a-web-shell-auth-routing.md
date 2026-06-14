# P4a — web 셸 + 인증 게이트 + 라우팅 (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`(Flutter Web)에 반응형 AppShell(<840 하단탭 / ≥840 내비 레일), go_router 인증·온보딩 redirect 게이트, OAuth(목) 로그인, 전역 라이트/다크 토글을 TDD로 구축해 — 이후 모든 web feature(P4b~P4d)가 올라설 **인증된 셸 토대**를 만든다.

**Architecture:** feature-first. `dp_core`(ApiClient·TokenStore·목 어댑터·User)와 `dp_design`(테마·아이콘·상태위젯)을 소비. 상태는 **Riverpod**(`Notifier`/`NotifierProvider`), 라우팅은 **go_router**(`redirect` 게이트 + `refreshListenable`로 auth 변화 재평가). 백엔드 없이 동작(`ApiConfig.useMock=true` + `MockHttpAdapter`). SSE·Monaco·실데이터 화면은 후속 플랜.

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · go_router(14.x+) · dp_core · dp_design · flutter_test.

---

## P4 분할 안내 (이 문서 = P4a)

스펙 §4 web 골든패스 전체는 단일 플랜으로 과대 → **P4a~P4d로 분할**(writing-plans Scope Check). 각 서브플랜은 독립적으로 동작·테스트 가능한 산출물을 낸다.

| 서브플랜 | 범위 | 산출 |
|---|---|---|
| **P4a (본 문서)** | web 셸 + go_router 인증·온보딩 게이트 + OAuth(목) 로그인 + 다크 토글 | 인증된 반응형 셸 |
| P4b | 온보딩·진단(ONB-001/002) + 학습경로 SSE 생성(PATH-001, DD8 이어하기/재연결) | 1st Aha |
| P4c | 콘텐츠 뷰어(CNT-001) + Sandbox+Monaco(SBX-001, DD5) + AI 리뷰(REV-001) | 2nd Aha |
| P4d | AI 멘토 SSE(MEN-001) + 대시보드(DASH-001) + 커뮤니티(COM-001/003) | 골든패스 완성 |

> **선행:** P1(모노레포 골격, `apps/web`=`devpath_web` 패키지)·P2(dp_core)·P3(dp_design) **구현 완료**. 본 플랜은 그 위에서 실행.
> **참조:** 스펙 §2(구조·스택)·§3(데이터흐름·게이트·에러)·§4(web 골든패스)·§9.1~9.3(DD1·DD5·DD6·반응형). DESIGN.md(토큰). 샘플(스펙 §7): `Flutter_GoRouter_인증_리다이렉트_라우팅`·`Flutter_Riverpod_비동기_상태관리`·`Flutter_Sealed_AuthState_Riverpod_KeepAlive_인증`. **구현 시 해당 .md를 읽어 정렬**.
> **착수 전 게이트(스펙 VERDICT):** DD5(반응형)·DD6(다크 전역 토글)은 아키텍처 영향 → **P4 실행 전 `/plan-eng-review` 권장.** 본 플랜은 그 리뷰 입력 문서다.
> **YAGNI 경계:** P4a는 셸+인증+라우팅+테마까지. 온보딩/대시보드/경로/멘토/커뮤니티 화면은 **플레이스홀더**(DpEmpty 기반)로 두고 P4b~P4d에서 실구현. `AuthInterceptor`(401 큐잉)·`GET /users/me`·토큰 영속화는 인증 데이터 호출이 처음 생기는 P4b에서 결선.

---

## File Structure (P4a에서 생성/수정)

```
packages/dp_core/lib/src/api/api_client.dart      # (수정) post<T> 헬퍼 추가 — Task 2
packages/dp_design/lib/src/icons/dp_icons.dart    # (수정) 테마 토글 아이콘 추가 — Task 2

apps/web/
├─ pubspec.yaml                                    # (수정) deps: dp_core·dp_design·riverpod·go_router — Task 1
├─ lib/
│  ├─ main.dart                                    # (교체) ProviderScope + 앱 루트 — Task 9
│  └─ src/
│     ├─ app/
│     │  ├─ app_config.dart                        # baseUrl·useMock(env) — Task 3
│     │  ├─ app.dart                               # MaterialApp.router + themeMode — Task 9
│     │  └─ router.dart                            # GoRouter + gateRedirect 게이트 — Task 8
│     ├─ data/
│     │  └─ web_mock_fixtures.dart                 # 목 REST 픽스처(로그인 등) — Task 3
│     ├─ providers/
│     │  ├─ api_providers.dart                     # appConfig·tokenStore·apiClient — Task 3
│     │  └─ theme_provider.dart                    # ThemeMode 토글(DD6) — Task 4
│     └─ features/
│        ├─ auth/
│        │  ├─ state/auth_state.dart               # sealed AuthState — Task 5
│        │  ├─ application/auth_controller.dart    # 목 로그인/로그아웃 — Task 5
│        │  └─ presentation/login_page.dart        # 로그인 화면 — Task 6
│        ├─ shell/presentation/app_shell.dart      # 반응형 셸(AppShell + AppShellView) — Task 7
│        ├─ onboarding/presentation/onboarding_placeholder.dart  # 플레이스홀더 — Task 8
│        └─ common/presentation/placeholder_page.dart            # 공용 플레이스홀더 — Task 8
└─ test/                                           # 각 모듈 *_test.dart (+ 골든패스 스모크 Task 10)
```

> 패키지명은 P1 산출 `devpath_web`(스펙 §2 / P1 Task 5 `--project-name devpath_web`). 모든 web 임포트는 `package:devpath_web/...`.

---

## Task 1: `apps/web` 의존성 추가 + 카운터 데모 정리

**Files:**
- Modify: `apps/web/pubspec.yaml`
- Delete: `apps/web/lib/main.dart`(카운터), `apps/web/test/widget_test.dart`(카운터 테스트 — lib 교체로 고아됨, P1 F8과 동일 사유)

- [ ] **Step 1: `pubspec.yaml` 의존성 추가**

`apps/web/pubspec.yaml`의 `dependencies:`/`dev_dependencies:`를 다음으로 정렬(나머지 `flutter create` 기본 키는 유지):
```yaml
dependencies:
  flutter:
    sdk: flutter
  dp_core:
    path: ../../packages/dp_core
  dp_design:
    path: ../../packages/dp_design
  flutter_riverpod: ^3.3.0
  go_router: ^14.6.0          # 하한 가이드 — bootstrap 결과로 확정

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0       # P1 E1: Flutter 멤버 4개 lints 버전 정렬값과 동일하게
```
> `dp_core`/`dp_design`은 workspace 멤버라 `path:`로 결선(P1에서 `resolution: workspace` 적용됨). 버전은 하한 가이드 — `melos bootstrap` 후 `pubspec.lock`으로 확정. go_router/riverpod 메이저는 **설치 결과로 핀**(API 드리프트 시 Context7 재확인).

- [ ] **Step 2: 카운터 데모 제거**

```bash
rm apps/web/lib/main.dart apps/web/test/widget_test.dart
```
> P1의 `apps/web/test/workspace_link_test.dart`(cross-import 스모크)는 **유지**한다. `main.dart`는 Task 9에서 새로 생성하므로 일시적으로 부재 — Task 9까지 `apps/web`는 빌드 불가 상태이며 중간 검증은 각 Task의 단위 테스트로 수행한다.

- [ ] **Step 3: bootstrap**

Run (레포 루트):
```bash
melos bootstrap
```
Expected: 충돌 없이 해석 성공(`devpath_web`에 riverpod·go_router·dp_core·dp_design 결선).

- [ ] **Step 4: 커밋**
```bash
git add apps/web/pubspec.yaml pubspec.lock
git commit -m "build(web): riverpod·go_router·dp_core·dp_design 의존성 + 카운터 데모 제거"
```

---

## Task 2: 공유 패키지 후속 — `ApiClient.post` + `DpIcons` 테마 아이콘

> P2는 post/put/delete 헬퍼를 "P4에서 추가"로 명시 보류. web 로그인이 첫 POST 소비처이므로 여기서 dp_core에 `post<T>`를 추가(web이 dio에 직접 의존하지 않도록). 테마 토글 아이콘도 DD3(단일 Symbols 셋) 준수 위해 `dp_design`에 추가.

**Files:**
- Modify: `packages/dp_core/lib/src/api/api_client.dart`
- Test: `packages/dp_core/test/api/api_client_test.dart`(append)
- Modify: `packages/dp_design/lib/src/icons/dp_icons.dart`
- Test: `packages/dp_design/test/icons/dp_icons_test.dart`(append)

- [ ] **Step 1: dp_core 실패 테스트(post 성공/실패)**

Append to `packages/dp_core/test/api/api_client_test.dart`(`main()` 내부에 추가):
```dart
  test('post는 성공 시 JSON map을 반환한다', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://api.test/api/v1'));
    client.dio.httpClientAdapter = MockHttpAdapter({
      'POST /auth/login': (200, {'accessToken': 'a', 'refreshToken': 'r'}),
    });
    final data = await client.post<Map<String, dynamic>>('/auth/login');
    expect(data['accessToken'], 'a');
  });

  test('post 실패는 ApiException으로 변환된다', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://api.test/api/v1'));
    client.dio.httpClientAdapter = MockHttpAdapter({
      'POST /x': (503, {'error': {'code': 'AI_KILL_SWITCH_ACTIVE', 'message': '점검'}}),
    });
    expect(
      () => client.post('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.aiKillSwitchActive)),
    );
  });
```
파일 상단 import에 `import 'package:dp_core/src/mock/mock_http_adapter.dart';`가 없으면 추가.

- [ ] **Step 2: 실패 확인** — Run: `cd packages/dp_core && dart test test/api/api_client_test.dart ; cd ../..` → FAIL(post 미정의)

- [ ] **Step 3: dp_core 구현 — `post<T>` 헬퍼 추가**

`packages/dp_core/lib/src/api/api_client.dart`의 `ApiClient` 클래스에 `get` 헬퍼 아래로 추가:
```dart
  /// POST 후 JSON 반환. 실패 시 [ApiException] throw. (get 헬퍼와 동일 규약)
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final res = await dio.post<T>(path, data: body, queryParameters: query);
      return res.data as T;
    } on DioException catch (e) {
      throw (e.error is ApiException) ? e.error as ApiException : ApiException.fromDio(e);
    }
  }
```

- [ ] **Step 4: dp_core 통과 확인** — Run: `cd packages/dp_core && dart test test/api/api_client_test.dart ; cd ../..` → PASS

- [ ] **Step 5: dp_design 실패 테스트(테마 아이콘)**

Append to `packages/dp_design/test/icons/dp_icons_test.dart`(`main()` 내부):
```dart
  test('테마 토글 아이콘이 IconData로 노출된다', () {
    expect(DpIcons.lightMode, isA<IconData>());
    expect(DpIcons.darkMode, isA<IconData>());
  });
```

- [ ] **Step 6: 실패 확인** — Run: `cd packages/dp_design && flutter test test/icons/dp_icons_test.dart ; cd ../..` → FAIL

- [ ] **Step 7: dp_design 구현 — 테마 아이콘 추가**

`packages/dp_design/lib/src/icons/dp_icons.dart`의 `DpIcons`에 추가:
```dart
  // 테마 토글(P4a — DD3 단일 Symbols 셋 유지)
  static const IconData lightMode = Symbols.light_mode_rounded;
  static const IconData darkMode = Symbols.dark_mode_rounded;
```

- [ ] **Step 8: dp_design 통과 확인** — Run: `cd packages/dp_design && flutter test test/icons/dp_icons_test.dart ; cd ../..` → PASS

- [ ] **Step 9: 커밋**
```bash
git add packages/dp_core/lib/src/api/api_client.dart packages/dp_core/test/api/api_client_test.dart packages/dp_design/lib/src/icons/dp_icons.dart packages/dp_design/test/icons/dp_icons_test.dart
git commit -m "feat(dp_core,dp_design): ApiClient.post 헬퍼 + DpIcons 테마 아이콘(P4a 토대)"
```

---

## Task 3: `AppConfig`(env) + 목 픽스처 + API providers

**Files:**
- Create: `apps/web/lib/src/app/app_config.dart`, `apps/web/lib/src/data/web_mock_fixtures.dart`, `apps/web/lib/src/providers/api_providers.dart`
- Test: `apps/web/test/providers/api_providers_test.dart`

- [ ] **Step 1: 실패 테스트(목 모드에서 apiClient가 픽스처를 서빙)**

Create `apps/web/test/providers/api_providers_test.dart`:
```dart
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 모드 apiClient는 로그인 픽스처를 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final client = container.read(apiClientProvider);
    final data = await client.post<Map<String, dynamic>>('/auth/login');

    expect(data['accessToken'], isNotEmpty);
    expect((data['user'] as Map)['nickname'], '지수');
  });

  test('tokenStore는 InMemory 기본 구현이다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(tokenStoreProvider), isA<InMemoryTokenStore>());
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/providers/api_providers_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `app_config.dart`**

Create `apps/web/lib/src/app/app_config.dart`:
```dart
/// 런타임 설정. `--dart-define`으로 주입(기본=목 프로토).
class AppConfig {
  const AppConfig({required this.baseUrl, required this.useMock});

  factory AppConfig.fromEnvironment() => const AppConfig(
        baseUrl: String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://mock.devpath.ai/api/v1',
        ),
        useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      );

  final String baseUrl;
  final bool useMock;
}
```

- [ ] **Step 4: 구현 — `web_mock_fixtures.dart`**

Create `apps/web/lib/src/data/web_mock_fixtures.dart`:
```dart
import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
/// 로그인 user.onboardingStatus=PENDING → 게이트가 로그인 후 온보딩으로 보냄(시연).
const Map<String, MockFixture> webMockFixtures = {
  'POST /auth/login': (
    200,
    {
      'accessToken': 'mock-access',
      'refreshToken': 'mock-refresh',
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'PENDING',
      },
    },
  ),
  'POST /auth/refresh': (
    200,
    {'accessToken': 'mock-access-2', 'refreshToken': 'mock-refresh-2'},
  ),
};
```
> `MockFixture`(=`(int, Object)` record)·`MockHttpAdapter`는 dp_core(P2) 공개 API. const 맵 안의 record/맵 리터럴은 const 추론됨 — 컴파일 에러 시 `const`를 `final`로 낮춘다.

- [ ] **Step 5: 구현 — `api_providers.dart`**

Create `apps/web/lib/src/providers/api_providers.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_config.dart';
import '../data/web_mock_fixtures.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// 프로토: web 토큰은 메모리(스펙 §3 "web=httpOnly 쿠키/메모리" 중 메모리).
/// localStorage 영속화는 후속(리스크 참조).
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

/// dio 래퍼. 목 모드면 MockHttpAdapter 주입(백엔드 없이 동작).
/// 401 큐잉 AuthInterceptor 결선은 인증 데이터 호출이 생기는 P4b에서 추가.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient.create(ApiConfig(
    baseUrl: config.baseUrl,
    useMock: config.useMock,
  ));
  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});
```

- [ ] **Step 6: 통과 확인** — Run: `cd apps/web && flutter test test/providers/api_providers_test.dart ; cd ../..` → PASS

- [ ] **Step 7: 커밋**
```bash
git add apps/web/lib/src/app/app_config.dart apps/web/lib/src/data apps/web/lib/src/providers/api_providers.dart apps/web/test/providers
git commit -m "feat(web): AppConfig + 목 픽스처 + API providers(목 모드 결선)"
```

---

## Task 4: 테마 모드 프로바이더 (라이트/다크 토글 — DD6)

**Files:**
- Create: `apps/web/lib/src/providers/theme_provider.dart`
- Test: `apps/web/test/providers/theme_provider_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/providers/theme_provider_test.dart`:
```dart
import 'package:devpath_web/src/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('초기값은 system, toggle은 dark→light로 순환한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);

    final ctrl = container.read(themeModeProvider.notifier);
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark); // system→dark
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.light); // dark→light
    ctrl.toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark); // light→dark
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/providers/theme_provider_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/providers/theme_provider.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 전역 라이트/다크 토글(DD6). 기본 system, 토글 시 dark↔light.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = switch (state) {
      ThemeMode.dark => ThemeMode.light,
      _ => ThemeMode.dark, // system/light → dark
    };
  }

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/providers/theme_provider_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/providers/theme_provider.dart apps/web/test/providers/theme_provider_test.dart
git commit -m "feat(web): 전역 라이트/다크 테마 토글 프로바이더(DD6)"
```

---

## Task 5: `AuthState` + `AuthController` (목 로그인/로그아웃)

**Files:**
- Create: `apps/web/lib/src/features/auth/state/auth_state.dart`, `apps/web/lib/src/features/auth/application/auth_controller.dart`
- Test: `apps/web/test/features/auth/auth_controller_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/auth/auth_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('초기 상태는 미인증', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('login 성공 시 Authenticated + 토큰 저장', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).login();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.nickname, '지수');
    expect(state.user.onboardingStatus, OnboardingStatus.pending);
    expect(await container.read(tokenStoreProvider).readAccess(), 'mock-access');
  });

  test('logout은 토큰을 비우고 미인증으로 전환', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ctrl = container.read(authControllerProvider.notifier);
    await ctrl.login();
    await ctrl.logout();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(await container.read(tokenStoreProvider).readAccess(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/auth/auth_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `auth_state.dart`**

Create `apps/web/lib/src/features/auth/state/auth_state.dart`:
```dart
import 'package:dp_core/dp_core.dart';

/// 인증 상태(sealed — 라우터 게이트가 분기).
sealed class AuthState {
  const AuthState();
}

/// 미인증(토큰 없음). [error]는 직전 로그인 실패 메시지(옵션).
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});
  final String? error;
}

/// 인증됨. [user.onboardingStatus]로 온보딩 게이트 판정.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}
```

- [ ] **Step 4: 구현 — `auth_controller.dart`**

Create `apps/web/lib/src/features/auth/application/auth_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/auth_state.dart';

/// 목 OAuth 로그인/로그아웃. 프로토는 메모리 토큰이라 시작 시 항상 미인증.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnauthenticated();

  ApiClient get _client => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  Future<void> login() async {
    try {
      final data = await _client.post<Map<String, dynamic>>('/auth/login');
      await _store.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      state = AuthAuthenticated(
        User.fromJson((data['user'] as Map).cast<String, dynamic>()),
      );
    } on ApiException catch (e) {
      state = AuthUnauthenticated(error: e.message);
    }
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
```
> `_client.post`는 dp_core 헬퍼(Task 2)라 실패 시 `ApiException`을 직접 throw → web은 dio에 의존하지 않는다.

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/auth/auth_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/auth/state apps/web/lib/src/features/auth/application apps/web/test/features/auth
git commit -m "feat(web): AuthState + AuthController(목 로그인/로그아웃)"
```

---

## Task 6: 로그인 화면 (`LoginPage`)

**Files:**
- Create: `apps/web/lib/src/features/auth/presentation/login_page.dart`
- Test: `apps/web/test/features/auth/login_page_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/auth/login_page_test.dart`:
```dart
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인 버튼 탭 → 인증 상태로 전환', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
    ));

    expect(find.text('GitHub로 계속하기 (목)'), findsOneWidget);

    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/auth/login_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/auth/presentation/login_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';
import '../application/auth_controller.dart';
import '../state/auth_state.dart';

/// OAuth(목) 로그인. 우상단 테마 토글, 실패 시 인라인 에러.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final c = context.dpColors;
    final error = auth is AuthUnauthenticated ? auth.error : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DevPath AI'),
        actions: [
          IconButton(
            icon: Icon(mode == ThemeMode.dark ? DpIcons.lightMode : DpIcons.darkMode),
            tooltip: '테마 전환',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('학습을 시작해요',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: DpSpacing.sm),
                Text('GitHub 계정으로 계속하세요',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: c.textSecondary)),
                if (error != null) ...[
                  const SizedBox(height: DpSpacing.lg),
                  Text(error,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.danger)),
                ],
                const SizedBox(height: DpSpacing.xl),
                FilledButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).login(),
                  child: const Text('GitHub로 계속하기 (목)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/auth/login_page_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/auth/presentation apps/web/test/features/auth/login_page_test.dart
git commit -m "feat(web): 로그인 화면(목 OAuth + 테마 토글 + 인라인 에러)"
```

---

## Task 7: 반응형 셸 (`AppShell` / `AppShellView`)

> §9.3: <840 하단탭(NavigationBar) · ≥840 좌측 내비 레일(NavigationRail). 라우터 결합부(`AppShell`)와 표현부(`AppShellView`)를 분리해 표현부를 go_router 없이 단위 테스트.

**Files:**
- Create: `apps/web/lib/src/features/shell/presentation/app_shell.dart`
- Test: `apps/web/test/features/shell/app_shell_view_test.dart`

- [ ] **Step 1: 실패 테스트(폭별 내비 + 선택 콜백)**

Create `apps/web/test/features/shell/app_shell_view_test.dart`:
```dart
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Size size, Widget child) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(theme: DpTheme.light(), home: child),
    );

void main() {
  testWidgets('좁은 폭(<840)은 NavigationBar', (tester) async {
    await tester.pumpWidget(_host(
      const Size(390, 800),
      const AppShellView(
        location: '/dashboard',
        child: Text('본문'),
      ),
    ));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('넓은 폭(≥840)은 NavigationRail', (tester) async {
    await tester.pumpWidget(_host(
      const Size(1200, 800),
      const AppShellView(
        location: '/dashboard',
        child: Text('본문'),
      ),
    ));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('목적지 선택 시 해당 경로로 콜백', (tester) async {
    String? picked;
    await tester.pumpWidget(_host(
      const Size(390, 800),
      AppShellView(
        location: '/dashboard',
        onSelect: (p) => picked = p,
        child: const Text('본문'),
      ),
    ));
    await tester.tap(find.text('멘토'));
    expect(picked, '/mentor');
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/shell/app_shell_view_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/shell/presentation/app_shell.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 셸 목적지(경로·아이콘·라벨).
typedef _Dest = ({String path, IconData icon, String label});

const List<_Dest> kShellDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/path', icon: DpIcons.path, label: '경로'),
  (path: '/mentor', icon: DpIcons.mentor, label: '멘토'),
  (path: '/community', icon: DpIcons.community, label: '커뮤니티'),
];

/// 라우터 결합 셸: 현재 위치를 읽고 표현부에 위임.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return AppShellView(
      location: loc,
      onSelect: (path) => context.go(path),
      child: child,
    );
  }
}

/// 표현부: go_router 비의존 — 폭에 따라 NavigationBar/Rail 전환(§9.3).
class AppShellView extends StatelessWidget {
  const AppShellView({
    super.key,
    required this.location,
    required this.child,
    this.onSelect,
  });

  final String location;
  final Widget child;
  final void Function(String path)? onSelect;

  int get _index {
    final i = kShellDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  void _select(int i) => onSelect?.call(kShellDestinations[i].path);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in kShellDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in kShellDestinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/shell/app_shell_view_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/shell apps/web/test/features/shell
git commit -m "feat(web): 반응형 AppShell(하단탭/내비레일 §9.3)"
```

---

## Task 8: go_router 인증·온보딩 게이트 + 플레이스홀더

> 게이트 판정 로직을 순수 함수 `gateRedirect`로 분리(결정적 단위 테스트). `routerProvider`는 그 함수 + `refreshListenable`로 auth 변화 시 재평가.

**Files:**
- Create: `apps/web/lib/src/app/router.dart`, `apps/web/lib/src/features/common/presentation/placeholder_page.dart`, `apps/web/lib/src/features/onboarding/presentation/onboarding_placeholder.dart`
- Test: `apps/web/test/app/gate_redirect_test.dart`

- [ ] **Step 1: 실패 테스트(게이트 로직 전수)**

Create `apps/web/test/app/gate_redirect_test.dart`:
```dart
import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(OnboardingStatus s) => User(
      id: 'u',
      email: 'e@x.com',
      nickname: 'n',
      role: UserRole.learner,
      onboardingStatus: s,
    );

void main() {
  group('gateRedirect', () {
    test('미인증 + 보호경로 → /login', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/dashboard'), '/login');
    });
    test('미인증 + /login → 그대로(null)', () {
      expect(gateRedirect(const AuthUnauthenticated(), '/login'), isNull);
    });
    test('인증 + 온보딩 미완 + 보호경로 → /onboarding', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.pending)), '/dashboard'),
        '/onboarding',
      );
    });
    test('인증 + 온보딩 미완 + /onboarding → 그대로(null)', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.pending)), '/onboarding'),
        isNull,
      );
    });
    test('인증 + 온보딩 완료 + /login → /dashboard', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.done)), '/login'),
        '/dashboard',
      );
    });
    test('인증 + 온보딩 완료 + 보호경로 → 그대로(null)', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.done)), '/dashboard'),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/app/gate_redirect_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — 플레이스홀더 위젯 2종**

Create `apps/web/lib/src/features/common/presentation/placeholder_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// P4b~P4d에서 실구현될 화면의 임시 자리(빈 상태 카피 규약 준수).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DpEmpty(
        icon: icon,
        title: title,
        message: '곧 제공됩니다.',
      );
}
```

Create `apps/web/lib/src/features/onboarding/presentation/onboarding_placeholder.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

/// 온보딩 자리(실구현=P4b ONB-001/002). 로그아웃으로 게이트 흐름 확인 가능.
class OnboardingPlaceholder extends ConsumerWidget {
  const OnboardingPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('온보딩'), actions: [
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('로그아웃'),
        ),
      ]),
      body: const DpEmpty(
        icon: DpIcons.path,
        title: '진단을 시작해요',
        message: '온보딩·진단 화면은 P4b에서 제공됩니다.',
      ),
    );
  }
}
```

- [ ] **Step 4: 구현 — `router.dart`(게이트 + 라우터)**

Create `apps/web/lib/src/app/router.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/state/auth_state.dart';
import '../features/common/presentation/placeholder_page.dart';
import '../features/onboarding/presentation/onboarding_placeholder.dart';
import '../features/shell/presentation/app_shell.dart';

/// 게이트 판정(순수): 미인증→/login, 인증·온보딩미완→/onboarding, 그 외 통과.
String? gateRedirect(AuthState auth, String location) {
  final atLogin = location == '/login';
  final atOnboarding = location == '/onboarding';

  if (auth is! AuthAuthenticated) {
    return atLogin ? null : '/login';
  }
  final onboardingDone = auth.user.onboardingStatus == OnboardingStatus.done;
  if (!onboardingDone) {
    return atOnboarding ? null : '/onboarding';
  }
  if (atLogin || atOnboarding) return '/dashboard';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // auth 변화 → refreshListenable 발화 → redirect 재평가(GoRouterRefreshStream은 go_router 5.0에서 제거).
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) =>
        gateRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingPlaceholder()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (_, __) =>
                  const PlaceholderPage(title: '대시보드', icon: DpIcons.dashboard)),
          GoRoute(
              path: '/path',
              builder: (_, __) =>
                  const PlaceholderPage(title: '학습 경로', icon: DpIcons.path)),
          GoRoute(
              path: '/mentor',
              builder: (_, __) =>
                  const PlaceholderPage(title: 'AI 멘토', icon: DpIcons.mentor)),
          GoRoute(
              path: '/community',
              builder: (_, __) => const PlaceholderPage(
                  title: '커뮤니티', icon: DpIcons.community)),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/app/gate_redirect_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/app/router.dart apps/web/lib/src/features/common apps/web/lib/src/features/onboarding apps/web/test/app/gate_redirect_test.dart
git commit -m "feat(web): go_router 인증·온보딩 게이트 + 플레이스홀더 라우트"
```

---

## Task 9: 앱 루트 (`DevPathWebApp`) + `main.dart`

**Files:**
- Create: `apps/web/lib/src/app/app.dart`
- Create: `apps/web/lib/main.dart`
- Test: `apps/web/test/app/app_test.dart`

- [ ] **Step 1: 실패 테스트(테마 토글이 MaterialApp.themeMode에 반영)**

Create `apps/web/test/app/app_test.dart`:
```dart
import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('themeMode 토글이 MaterialApp에 반영된다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const DevPathWebApp(),
    ));
    await tester.pumpAndSettle();

    MaterialApp app() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);

    container.read(themeModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/app/app_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `app.dart`**

Create `apps/web/lib/src/app/app.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'router.dart';

/// web 앱 루트: 라우터 + 전역 테마(라이트/다크 토글, DD6).
class DevPathWebApp extends ConsumerWidget {
  const DevPathWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DevPath AI',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 4: 구현 — `main.dart`**

Create `apps/web/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

void main() {
  runApp(const ProviderScope(child: DevPathWebApp()));
}
```

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/app/app_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/app/app.dart apps/web/lib/main.dart apps/web/test/app/app_test.dart
git commit -m "feat(web): 앱 루트(MaterialApp.router + 테마 토글) + main"
```

---

## Task 10: 골든패스 게이트 통합 스모크 + 전체 검증

> 실제 앱(목 모드)을 띄워 게이트 와이어링을 end-to-end 확인: 시작=로그인 → 로그인 → 온보딩(PENDING 픽스처).

**Files:**
- Create: `apps/web/test/golden_path_smoke_test.dart`
- Verify: `apps/web/test/workspace_link_test.dart`(P1) 잔존 시 통과 확인, 깨지면 본 스모크로 대체·삭제

- [ ] **Step 1: 통합 스모크 테스트**

Create `apps/web/test/golden_path_smoke_test.dart`:
```dart
import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('초기에는 로그인, 로그인하면 온보딩으로 게이트된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DevPathWebApp()));
    await tester.pumpAndSettle();

    // 미인증 → 로그인으로 redirect
    expect(find.byType(LoginPage), findsOneWidget);

    // 목 로그인(PENDING 유저) → 온보딩으로 redirect
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPlaceholder), findsOneWidget);
  });
}
```

- [ ] **Step 2: 통과 확인** — Run: `cd apps/web && flutter test test/golden_path_smoke_test.dart ; cd ../..` → PASS

- [ ] **Step 3: 전체 검증**

Run (레포 루트):
```bash
melos run analyze
melos run test
```
Expected: `devpath_web` 포함 `analyze` 이슈 없음, `test` 전 멤버 PASS(골든 제외 — P3-A 스크립트). `workspace_link_test.dart`가 구 카운터를 참조해 깨지면 본 스모크로 검증되므로 삭제(`git rm apps/web/test/workspace_link_test.dart`).

- [ ] **Step 4: 커밋**
```bash
git add apps/web/test/golden_path_smoke_test.dart
git commit -m "test(web): 골든패스 게이트 통합 스모크(로그인→온보딩)"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze` — `devpath_web` 포함 이슈 없음
- [ ] `melos run test` — web 전 테스트 PASS(providers·theme·auth·login·shell·gate·app·smoke)
- [ ] 미인증 진입 → `/login`으로 redirect (게이트)
- [ ] 목 로그인(PENDING) → `/onboarding`으로 redirect, `OnboardingStatus.done`이면 `/dashboard`
- [ ] 셸: <840 `NavigationBar` · ≥840 `NavigationRail`(§9.3), 목적지 선택 시 `context.go`
- [ ] 전역 라이트/다크 토글이 `MaterialApp.themeMode`에 반영(DD6)
- [ ] web이 `dio`에 직접 의존하지 않음(dp_core 헬퍼 경유) · 이모지 0(DpIcons만, DD3)
- [ ] `flutter run -d chrome`(목 모드)로 로그인→온보딩 수동 확인(권장)

## 리스크 / 후속 (명시)

- **토큰 영속화 부재**: `InMemoryTokenStore`라 새로고침 시 로그아웃(게이트가 `/login`으로 되돌림 — 동작은 정상이나 데모 불편). web `localStorage`(`package:web`) 기반 `WebTokenStore`는 후속(P4b 또는 별도 TODO). 스펙 §3 "web=httpOnly 쿠키/메모리"의 메모리안 채택.
- **AuthInterceptor 미결선**: 401 큐잉 갱신(P2)은 인증 데이터 호출이 처음 생기는 **P4b**에서 `apiClientProvider`에 결선(`onRequest` Bearer 주입 + `onError` refresh/retry). P4a는 로그인/로그아웃만이라 불필요(YAGNI).
- **셸 탭 상태보존**: P4a는 단순 `ShellRoute`(탭 전환 시 화면 재생성). 탭별 내비 스택 보존이 필요하면 P4d에서 `StatefulShellRoute`로 승격(스펙 §7 `Flutter_GoRouter_StatefulShellRoute_탭_네비게이션`).
- **`GET /users/me` 미사용**: 로그인 픽스처가 user를 포함하므로 P4a는 별도 조회 불필요. 세션 복원(영속 토큰)이 생기면 P4b에서 `/users/me` 추가.
- **eng-review 게이트**: 스펙 VERDICT상 DD5/DD6 아키텍처 영향 → 본 플랜 실행 전 `/plan-eng-review` 권장.
- **라이브러리 메이저 핀**: go_router/flutter_riverpod 메이저는 `melos bootstrap` 결과로 확정. API 드리프트(예: `Notifier` 시그니처, `redirect` 컨텍스트) 발생 시 Context7로 설치 버전 정렬.
