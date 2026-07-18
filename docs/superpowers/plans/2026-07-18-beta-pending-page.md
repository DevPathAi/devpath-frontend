# 베타 대기 페이지(/beta-pending) + 승인 폴링 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 미승인(BETA_PENDING) 사용자가 착지하는 `/beta-pending` 페이지를 신설하고, 30분 단명 조회 쿠키 기반 `GET /beta/status` 폴링으로 승인 감지 시 자동 재-OAuth 진입시킨다.

**Architecture:** platform은 refresh 토큰과 동일한 Redis opaque 패턴(별도 `beta-status:` 네임스페이스, 조회 전용)으로 status 토큰을 발급하고 공개 `GET /beta/status`를 제공한다. `OAuth2LoginSuccessHandler`가 admit=false 시 status 쿠키를 심고 `/beta-pending`으로 리다이렉트한다. frontend는 `/beta-pending` 라우트를 신설하고 `gateRedirect`에 미인증 통과 예외를 두며, 페이지가 5초 주기로 폴링해 APPROVED 시 `login(provider)`로 재진입한다.

**Tech Stack:** platform = Spring Boot 4.0.7 · Java 21 · Redis(StringRedisTemplate) · JUnit5/Mockito/MockMvc. frontend = Flutter · Riverpod · go_router · dio(ApiClient) · dp_core(순수 Dart 모델).

## Global Constraints

- 브랜치: platform = `feat/beta-pending-backend`(develop에서 분기). frontend = `feat/beta-pending-page`(이미 존재, spec 커밋 53e134a).
- **머지 순서**: platform PR을 **먼저** develop 머지(백엔드 계약 확정) → frontend가 실계약에 정합. Task 1~3(platform) 완료·머지 후 Task 4~5(frontend).
- status 조회 토큰은 **Redis opaque**(JWT 금지 — `oauth2ResourceServer.jwt` 오인 방지). 쿠키명 `beta_status`, HttpOnly, 30분.
- 폴링 주기 5초. status 값은 `PENDING` | `APPROVED` | `EXPIRED`.
- platform: 모든 기능은 실패 테스트 우선(TDD). `@SpringBootTest` 통합테스트는 **Redis/DB 필요** — 로컬 도커 부재 시 `./gradlew build -x test`로 컴파일 확인하고 **CI에서 통과 검증**([[devpath-svc-test-context-connection-flake]] 계열 교훈).
- platform: `@MockBean` 금지(Boot4) → `@MockitoBean`. 통합테스트 body는 DB CHECK 제약과 정합.
- frontend: 커밋 전 `dart format .`(CI `melos run format` 게이트). BetaStatus는 **freezed 아닌 순수 Dart 모델**(단순 응답, build_runner 회피).
- Conventional Commits. 각 커밋 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: platform — BetaStatusTokens + BetaStatusCookies + statusTtl

**Files:**
- Create: `src/main/java/ai/devpath/platform/beta/BetaStatusTokens.java`
- Create: `src/main/java/ai/devpath/platform/beta/BetaStatusCookies.java`
- Modify: `src/main/java/ai/devpath/platform/config/BetaProperties.java`
- Test: `src/test/java/ai/devpath/platform/beta/BetaStatusTokensTest.java`

**Interfaces:**
- Produces: `BetaStatusTokens.issue(long userId) -> String`, `BetaStatusTokens.validate(String token) -> Optional<Long>`; `BetaStatusCookies.create(String tokenValue) -> ResponseCookie`(쿠키명 `beta_status`); `BetaProperties.getStatusTtl() -> Duration`(기본 30분).

- [ ] **Step 0: 브랜치 분기**

```bash
git -C D:/workspace/dpa/devpath-platform-svc fetch origin --prune
git -C D:/workspace/dpa/devpath-platform-svc checkout -b feat/beta-pending-backend origin/develop
```

- [ ] **Step 1: `BetaProperties`에 statusTtl 추가**

`BetaProperties.java` — `import java.time.Duration;` 추가하고 필드/게터/세터 추가:

```java
import java.time.Duration;
// ...
    private Duration statusTtl = Duration.ofMinutes(30);
    // (기존 필드 아래)
    public Duration getStatusTtl() { return statusTtl; }
    public void setStatusTtl(Duration v) { this.statusTtl = v; }
```

- [ ] **Step 2: 실패 테스트 작성** — `BetaStatusTokensTest.java`

```java
package ai.devpath.platform.beta;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import ai.devpath.platform.config.BetaProperties;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class BetaStatusTokensTest {

    @Autowired StringRedisTemplate redis;

    private BetaStatusTokens store() {
        BetaProperties props = new BetaProperties();
        props.setStatusTtl(Duration.ofMinutes(30));
        return new BetaStatusTokens(redis, props);
    }

    @Test
    void issueThenValidate() {
        BetaStatusTokens s = store();
        String t = s.issue(42L);
        assertEquals(42L, s.validate(t).orElseThrow());
        assertFalse(s.validate("bogus-token").isPresent(), "무효 토큰은 empty");
    }
}
```

- [ ] **Step 3: 컴파일 실패 확인**

Run: `./gradlew compileTestJava`
Expected: FAIL — `BetaStatusTokens` 심볼 없음.

- [ ] **Step 4: `BetaStatusTokens` 구현** (RefreshTokenStore 패턴, `beta-status:` prefix)

```java
package ai.devpath.platform.beta;

import ai.devpath.platform.config.BetaProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Optional;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 미승인자 승인여부 조회 전용 단명 토큰(Redis opaque). refresh 토큰과 완전 분리된
 * 네임스페이스(beta-status:)를 쓰며, 실 API 인증에는 사용되지 않는다.
 */
@Component
public class BetaStatusTokens {

    private static final String PREFIX = "beta-status:";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final StringRedisTemplate redis;
    private final BetaProperties props;

    public BetaStatusTokens(StringRedisTemplate redis, BetaProperties props) {
        this.redis = redis;
        this.props = props;
    }

    public String issue(long userId) {
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        redis.opsForValue().set(PREFIX + hash(token), String.valueOf(userId), props.getStatusTtl());
        return token;
    }

    public Optional<Long> validate(String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        String v = redis.opsForValue().get(PREFIX + hash(token));
        return v == null ? Optional.empty() : Optional.of(Long.parseLong(v));
    }

    private static String hash(String token) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(d);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
```

- [ ] **Step 5: `BetaStatusCookies` 구현** (RefreshCookies 패턴, 쿠키명 `beta_status`, maxAge=statusTtl)

```java
package ai.devpath.platform.beta;

import ai.devpath.platform.config.AuthProperties;
import ai.devpath.platform.config.BetaProperties;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

/**
 * beta_status 쿠키 빌더. 쿠키 정책(domain/SameSite/secure)은 refresh 쿠키와 동일하게
 * AuthProperties에서 취하되, 수명은 BetaProperties.statusTtl(기본 30분)을 쓴다.
 */
@Component
public class BetaStatusCookies {

    static final String COOKIE_NAME = "beta_status";

    private final AuthProperties auth;
    private final BetaProperties beta;

    public BetaStatusCookies(AuthProperties auth, BetaProperties beta) {
        this.auth = auth;
        this.beta = beta;
    }

    public ResponseCookie create(String tokenValue) {
        ResponseCookie.ResponseCookieBuilder b = ResponseCookie.from(COOKIE_NAME, tokenValue)
                .httpOnly(true)
                .path("/")
                .maxAge(beta.getStatusTtl().toSeconds())
                .sameSite(auth.getCookieSameSite())
                .secure(auth.isCookieSecure());
        String domain = auth.getCookieDomain();
        if (domain != null && !domain.isBlank()) {
            b.domain(domain);
        }
        return b.build();
    }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run(로컬 Redis 있으면): `./gradlew test --tests 'ai.devpath.platform.beta.BetaStatusTokensTest'`
Expected: PASS. 로컬 도커/Redis 부재 시 `./gradlew build -x test`로 컴파일만 확인하고 CI에 위임.

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add -A
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat(beta): status 조회 토큰(Redis opaque) + beta_status 쿠키 + statusTtl"
```

---

## Task 2: platform — GET /beta/status + SecurityConfig permitAll

**Files:**
- Create: `src/main/java/ai/devpath/platform/beta/BetaStatusController.java`
- Create: `src/main/java/ai/devpath/platform/beta/dto/BetaStatusResponse.java`
- Modify: `src/main/java/ai/devpath/platform/user/UserOauthIdentityRepository.java` (조회 메서드 추가)
- Modify: `src/main/java/ai/devpath/platform/config/SecurityConfig.java` (permitAll)
- Test: `src/test/java/ai/devpath/platform/beta/BetaStatusControllerTest.java`

**Interfaces:**
- Consumes: `BetaStatusTokens.validate` (Task 1).
- Produces: `GET /beta/status` → JSON `{ "status": "PENDING"|"APPROVED"|"EXPIRED", "provider": <string|null> }`.

> **주의(추측 금지):** Step 1 전에 `UserOauthIdentityRepository.java`를 열어 인터페이스명·기존 메서드를 확인하라. 파일명이 다르거나 부재하면 멈추고 `NEEDS_CONTEXT` 보고(플랜은 `ai.devpath.platform.user.UserOauthIdentityRepository`가 `JpaRepository<UserOauthIdentity, Long>`임을 가정).

- [ ] **Step 1: `UserOauthIdentityRepository`에 파생 쿼리 추가**

```java
import java.util.List;
// interface 본문에:
    List<UserOauthIdentity> findByUserIdOrderByLinkedAtAsc(Long userId);
```

- [ ] **Step 2: `BetaStatusResponse` DTO 생성**

```java
package ai.devpath.platform.beta.dto;

public record BetaStatusResponse(String status, String provider) {}
```

- [ ] **Step 3: 실패 테스트 작성** — `BetaStatusControllerTest.java`

```java
package ai.devpath.platform.beta;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import ai.devpath.platform.user.User;
import ai.devpath.platform.user.UserRepository;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BetaStatusControllerTest {

    @Autowired MockMvc mvc;
    @Autowired UserRepository userRepository;
    @Autowired BetaStatusTokens tokens;

    private User saveUser(String status) {
        User u = new User();
        u.setEmail("beta-" + System.nanoTime() + "@example.com");
        u.setNickname("t");
        u.setStatus(status);
        return userRepository.save(u);
    }

    @Test
    void pendingUser_returnsPending() throws Exception {
        User u = saveUser("BETA_PENDING");
        String t = tokens.issue(u.getId());
        mvc.perform(get("/beta/status").cookie(new Cookie("beta_status", t)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void activeUser_returnsApproved() throws Exception {
        User u = saveUser("ACTIVE");
        String t = tokens.issue(u.getId());
        mvc.perform(get("/beta/status").cookie(new Cookie("beta_status", t)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void noCookie_returnsExpired() throws Exception {
        mvc.perform(get("/beta/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EXPIRED"));
    }
}
```

- [ ] **Step 4: 컴파일/테스트 실패 확인**

Run: `./gradlew compileTestJava`
Expected: FAIL — `BetaStatusController` 미존재(빈 없어 컨텍스트 로딩 시 404 → 테스트 실패).

- [ ] **Step 5: `BetaStatusController` 구현**

```java
package ai.devpath.platform.beta;

import ai.devpath.platform.beta.dto.BetaStatusResponse;
import ai.devpath.platform.user.User;
import ai.devpath.platform.user.UserOauthIdentity;
import ai.devpath.platform.user.UserOauthIdentityRepository;
import ai.devpath.platform.user.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Optional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 미승인자 대기 페이지의 승인여부 폴링 엔드포인트(공개 — beta_status 쿠키로 자체 검증).
 * 실 인증(JWT)과 무관하며 조회 결과는 PENDING/APPROVED/EXPIRED 뿐이다.
 */
@RestController
public class BetaStatusController {

    private final BetaStatusTokens tokens;
    private final UserRepository users;
    private final UserOauthIdentityRepository identities;

    public BetaStatusController(BetaStatusTokens tokens, UserRepository users,
            UserOauthIdentityRepository identities) {
        this.tokens = tokens;
        this.users = users;
        this.identities = identities;
    }

    @GetMapping("/beta/status")
    public BetaStatusResponse status(HttpServletRequest request) {
        Optional<Long> userId = tokens.validate(readCookie(request, "beta_status"));
        if (userId.isEmpty()) return new BetaStatusResponse("EXPIRED", null);
        Optional<User> user = users.findById(userId.get());
        if (user.isEmpty()) return new BetaStatusResponse("EXPIRED", null);
        if ("ACTIVE".equals(user.get().getStatus())) {
            return new BetaStatusResponse("APPROVED", firstProvider(userId.get()));
        }
        return new BetaStatusResponse("PENDING", null);
    }

    private String firstProvider(long userId) {
        List<UserOauthIdentity> list = identities.findByUserIdOrderByLinkedAtAsc(userId);
        return list.isEmpty() ? null : list.get(0).getProvider().toLowerCase();
    }

    private static String readCookie(HttpServletRequest request, String name) {
        if (request.getCookies() == null) return null;
        for (var c : request.getCookies()) {
            if (name.equals(c.getName())) return c.getValue();
        }
        return null;
    }
}
```

- [ ] **Step 6: `SecurityConfig` permitAll에 `/beta/status` 추가**

`SecurityConfig.java` — 기존 `.requestMatchers("/oauth2/**", ...).permitAll()` 줄에 `"/beta/status"`를 추가:

```java
.requestMatchers("/oauth2/**", "/login/**", "/auth/refresh", "/auth/logout", "/auth/oauth/token", "/actuator/health", "/beta/status").permitAll()
```

- [ ] **Step 7: 테스트 통과 확인**

Run(로컬 인프라 있으면): `./gradlew test --tests 'ai.devpath.platform.beta.BetaStatusControllerTest'`
Expected: PASS. 부재 시 `./gradlew build -x test` 컴파일 확인 후 CI 위임.

- [ ] **Step 8: 커밋**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add -A
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat(beta): GET /beta/status 승인여부 폴링 API(공개, 쿠키 검증)"
```

---

## Task 3: platform — SuccessHandler 쿠키 발급 + pending-redirect 기본값 전환

**Files:**
- Modify: `src/main/java/ai/devpath/platform/auth/OAuth2LoginSuccessHandler.java`
- Modify: `src/main/java/ai/devpath/platform/config/BetaProperties.java` (pendingRedirect 기본값)
- Modify: `src/main/resources/application.yml`
- Test: `src/test/java/ai/devpath/platform/auth/OAuth2LoginSuccessHandlerBetaTest.java`

**Interfaces:**
- Consumes: `BetaStatusTokens.issue`, `BetaStatusCookies.create` (Task 1).
- Produces: admit=false 경로가 `Set-Cookie: beta_status=...` + `Location: <webUrl>/beta-pending`.

- [ ] **Step 1: 실패하도록 기존 테스트 수정** — `OAuth2LoginSuccessHandlerBetaTest.java`

`@Mock` 2개 추가, 생성자 인자 확장, admit=false 테스트를 쿠키+`/beta-pending` 검증으로 변경:

```java
// 필드에 추가
@Mock ai.devpath.platform.beta.BetaStatusTokens betaStatusTokens;
@Mock ai.devpath.platform.beta.BetaStatusCookies betaStatusCookies;

// setUp()의 handler 생성 부분 교체
handler = new OAuth2LoginSuccessHandler(
        registration, refreshStore, cookies, props, authorizedClients, authCodeStore,
        betaGate, betaProps, betaStatusTokens, betaStatusCookies);

// unlistedUser 테스트 본문 교체
@Test
void unlistedUser_setsBetaStatusCookie_redirectsToBetaPending() throws Exception {
    when(betaGate.admit(any())).thenReturn(false);
    when(betaProps.getPendingRedirect()).thenReturn("/beta-pending");
    when(betaStatusTokens.issue(anyLong())).thenReturn("st");
    when(betaStatusCookies.create("st")).thenReturn(
            ResponseCookie.from("beta_status", "st").httpOnly(true).path("/").build());

    MockHttpServletRequest request = new MockHttpServletRequest();
    MockHttpServletResponse response = new MockHttpServletResponse();

    handler.onAuthenticationSuccess(request, response, authentication);

    String setCookie = response.getHeader(HttpHeaders.SET_COOKIE);
    org.junit.jupiter.api.Assertions.assertNotNull(setCookie, "beta_status 쿠키 설정");
    org.junit.jupiter.api.Assertions.assertTrue(setCookie.contains("beta_status"), "beta_status 쿠키명");
    verifyNoInteractions(refreshStore);
    assertEquals("https://app.example/beta-pending", response.getRedirectedUrl());
}
```

> `user.getId()`가 admit=false 경로에서도 호출되므로 setUp의 `lenient().when(user.getId())...`는 유지(이미 lenient).

- [ ] **Step 2: 컴파일 실패 확인**

Run: `./gradlew compileTestJava`
Expected: FAIL — 생성자 인자 불일치(8 vs 10).

- [ ] **Step 3: `OAuth2LoginSuccessHandler` 구현 변경**

필드·생성자에 2개 주입 추가, admit=false 분기(현 75~78행) 교체:

```java
// 필드
private final ai.devpath.platform.beta.BetaStatusTokens betaStatusTokens;
private final ai.devpath.platform.beta.BetaStatusCookies betaStatusCookies;

// 생성자 파라미터 끝에 2개 추가 + 대입
public OAuth2LoginSuccessHandler(UserRegistrationService registration, RefreshTokenStore refreshStore,
        RefreshCookies cookies, AuthProperties props,
        OAuth2AuthorizedClientService authorizedClients, AuthCodeStore authCodeStore,
        BetaGate betaGate, BetaProperties betaProps,
        ai.devpath.platform.beta.BetaStatusTokens betaStatusTokens,
        ai.devpath.platform.beta.BetaStatusCookies betaStatusCookies) {
    // ... 기존 대입 ...
    this.betaStatusTokens = betaStatusTokens;
    this.betaStatusCookies = betaStatusCookies;
}

// admit=false 분기 교체
if (!betaGate.admit(user)) {
    String statusToken = betaStatusTokens.issue(user.getId());
    response.addHeader(HttpHeaders.SET_COOKIE, betaStatusCookies.create(statusToken).toString());
    response.sendRedirect(props.getWebUrl() + betaProps.getPendingRedirect());
    return;
}
```

- [ ] **Step 4: `BetaProperties` 기본값 + `application.yml` 전환**

`BetaProperties.java`: `private String pendingRedirect = "/beta-pending";`
`application.yml`(현 65행): `pending-redirect: ${BETA_PENDING_REDIRECT:/beta-pending}`

- [ ] **Step 5: 테스트 통과 확인**

Run(로컬): `./gradlew test --tests 'ai.devpath.platform.auth.OAuth2LoginSuccessHandlerBetaTest'`
Expected: PASS(3개 — unlisted/admitted-web/admin). 부재 시 `./gradlew build -x test` 후 CI 위임.

- [ ] **Step 6: 커밋 + PR**

```bash
git -C D:/workspace/dpa/devpath-platform-svc add -A
git -C D:/workspace/dpa/devpath-platform-svc commit -m "feat(beta): 미승인자에 beta_status 쿠키 발급 + /beta-pending 리다이렉트 전환"
git -C D:/workspace/dpa/devpath-platform-svc push -u origin feat/beta-pending-backend
gh pr create --repo DevPathAi/devpath-platform-svc --base develop --head feat/beta-pending-backend \
  --title "feat: 베타 대기 폴링 백엔드 (WS-C2b)" \
  --body "beta_status 조회 토큰(Redis opaque) + GET /beta/status + /beta-pending 리다이렉트. spec: devpath-frontend/docs/superpowers/specs/2026-07-18-beta-pending-page-design.md"
```

> **게이트: platform PR CI 녹색 확인 후 develop 머지.** 머지 완료까지 Task 4~5 착수 금지(프론트가 실계약에 정합해야 함).

---

## Task 4: frontend — dp_core BetaStatus 모델

**Files:**
- Create: `packages/dp_core/lib/src/models/beta_status.dart`
- Modify: `packages/dp_core/lib/dp_core.dart` (export 추가)
- Test: `packages/dp_core/test/models/beta_status_test.dart`

**Interfaces:**
- Produces: `enum BetaStatusKind { pending, approved, expired }`; `class BetaStatus { BetaStatusKind status; String? provider; BetaStatus.fromJson(Map) }`.

- [ ] **Step 1: 실패 테스트 작성** — `packages/dp_core/test/models/beta_status_test.dart`

```dart
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('APPROVED + provider 파싱', () {
    final s = BetaStatus.fromJson({'status': 'APPROVED', 'provider': 'github'});
    expect(s.status, BetaStatusKind.approved);
    expect(s.provider, 'github');
  });

  test('PENDING 파싱(provider 없음)', () {
    final s = BetaStatus.fromJson({'status': 'PENDING'});
    expect(s.status, BetaStatusKind.pending);
    expect(s.provider, isNull);
  });

  test('EXPIRED 및 알 수 없는 값 → expired', () {
    expect(BetaStatus.fromJson({'status': 'EXPIRED'}).status, BetaStatusKind.expired);
    expect(BetaStatus.fromJson({'status': '???'}).status, BetaStatusKind.expired);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd packages/dp_core && dart test test/models/beta_status_test.dart`
Expected: FAIL — `BetaStatus` 미정의.

- [ ] **Step 3: `BetaStatus` 모델 구현** (순수 Dart, 수동 fromJson)

```dart
/// 베타 승인 상태(GET /beta/status). 서버 status 문자열을 enum으로 매핑한다.
enum BetaStatusKind { pending, approved, expired }

class BetaStatus {
  const BetaStatus({required this.status, this.provider});

  final BetaStatusKind status;

  /// 승인 시 자동 재-OAuth에 쓸 대표 provider(소문자, 예: 'github'/'google'). 없으면 null.
  final String? provider;

  factory BetaStatus.fromJson(Map<String, dynamic> json) => BetaStatus(
        status: _kindFromString(json['status'] as String?),
        provider: json['provider'] as String?,
      );

  static BetaStatusKind _kindFromString(String? raw) {
    switch (raw) {
      case 'APPROVED':
        return BetaStatusKind.approved;
      case 'PENDING':
        return BetaStatusKind.pending;
      default:
        return BetaStatusKind.expired;
    }
  }
}
```

- [ ] **Step 4: export 추가** — `dp_core.dart`에 한 줄:

```dart
export 'src/models/beta_status.dart';
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd packages/dp_core && dart test test/models/beta_status_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend && dart format packages/dp_core/lib/src/models/beta_status.dart packages/dp_core/test/models/beta_status_test.dart
git -C D:/workspace/dpa/devpath-frontend add -A
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(beta): dp_core BetaStatus 모델 + fromJson"
```

---

## Task 5: frontend — gateRedirect 예외 + /beta-pending 라우트 + 폴링 페이지

**Files:**
- Modify: `apps/web/lib/src/app/router.dart` (gateRedirect + 라우트)
- Create: `apps/web/lib/src/features/beta/presentation/beta_pending_page.dart`
- Test: `apps/web/test/app/gate_redirect_test.dart` (케이스 추가)
- Test: `apps/web/test/features/beta/beta_pending_page_test.dart`

**Interfaces:**
- Consumes: `BetaStatus`(Task 4), `apiClient.get('/beta/status')`(Task 2 계약), `authControllerProvider.notifier.login(provider:)`.

- [ ] **Step 1: gateRedirect 실패 테스트 추가** — `gate_redirect_test.dart`의 `group('gateRedirect')` 안에:

```dart
test('미인증 + /beta-pending → 통과(null) — 미승인자 대기 허용', () {
  expect(gateRedirect(const AuthUnauthenticated(), '/beta-pending'), isNull);
});
test('인증(완료) + /beta-pending → /dashboard 흡수', () {
  expect(
    gateRedirect(AuthAuthenticated(_user(OnboardingStatus.done)), '/beta-pending'),
    '/dashboard',
  );
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd apps/web && flutter test test/app/gate_redirect_test.dart`
Expected: FAIL — 미인증 `/beta-pending`이 `/login`을 반환(현재 로직).

- [ ] **Step 3: `gateRedirect` 수정** — `router.dart`

`atDiagnostic` 선언 아래에 `atBetaPending` 추가하고, 미인증 통과 목록과 인증 흡수 처리:

```dart
final atLogin = location == '/login';
final atDiagnostic = location == '/diagnostic';
final atBetaPending = location == '/beta-pending';

if (auth is! AuthAuthenticated) {
  if (atLogin || atDiagnostic || atBetaPending) return null;
  return '/login';
}
// 인증(토큰 보유=승인)된 유저가 대기 페이지에 오면 정상 게이트로 흡수.
if (atBetaPending) return '/dashboard';
```

- [ ] **Step 4: `/beta-pending` 라우트 추가** — `router.dart` routes(=`/login` 옆, ShellRoute 밖):

```dart
import '../features/beta/presentation/beta_pending_page.dart';
// routes 목록에:
GoRoute(path: '/beta-pending', builder: (_, _) => const BetaPendingPage()),
```

- [ ] **Step 5: gateRedirect 테스트 통과 확인**

Run: `cd apps/web && flutter test test/app/gate_redirect_test.dart`
Expected: PASS(신규 2 포함 전체).

- [ ] **Step 6: `BetaPendingPage` 위젯 실패 테스트** — `apps/web/test/features/beta/beta_pending_page_test.dart`

> fake ApiClient는 `dashboard_controller_test.dart`의 `implements ApiClient` 패턴을 복제(모든 멤버 UnimplementedError, `get`만 구현). login 리다이렉트 검증은 `oauthLauncherProvider`를 Fake로 override(기존 `auth_controller` 테스트의 FakeOAuthLauncher 패턴 참조 — 없으면 인라인 Fake 작성: `OAuthLauncher`를 implements 하고 `launch(url)`에서 호출 URL 저장).

```dart
import 'dart:async';
import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_web/src/features/beta/presentation/beta_pending_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusApiClient implements ApiClient {
  _StatusApiClient(this.responses);
  final List<Map<String, dynamic>> responses;
  int _i = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    final r = responses[_i < responses.length - 1 ? _i++ : _i];
    return r as T;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();
  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();
  @override
  Future<T> delete<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();
  @override
  Stream<SseEvent> sse(String path, {Object? body}) => throw UnimplementedError();
  @override
  Future<T> postMultipart<T>(String path,
          {required List<int> bytes,
          required String filename,
          String field = 'file',
          String? contentType}) =>
      throw UnimplementedError();
  @override
  Dio get dio => throw UnimplementedError();
}

class _CapturingLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  testWidgets('APPROVED 수신 시 login(provider) 재-OAuth 트리거', (tester) async {
    final api = _StatusApiClient([
      {'status': 'PENDING'},
      {'status': 'APPROVED', 'provider': 'github'},
    ]);
    final launcher = _CapturingLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          oauthLauncherProvider.overrideWithValue(launcher),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'http://x', useMock: false),
          ),
        ],
        child: const MaterialApp(home: BetaPendingPage()),
      ),
    );

    // 첫 폴링(5s) → PENDING, 둘째(10s) → APPROVED
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(launcher.launched, contains('/oauth2/authorization/github'));
  });
}
```

> `AppConfig` 생성자 시그니처는 `app_config.dart`를 열어 확인(위 `const AppConfig(baseUrl:, useMock:)`가 다르면 정합). `oauthLauncherProvider` 노출 여부도 확인 — 미노출이면 `apps/web/lib/src/features/auth/application/oauth_launcher.dart` 확인 후 provider override 경로 정합. 불명확하면 `NEEDS_CONTEXT`.

- [ ] **Step 7: 테스트 실패 확인**

Run: `cd apps/web && flutter test test/features/beta/beta_pending_page_test.dart`
Expected: FAIL — `BetaPendingPage` 미정의.

- [ ] **Step 8: `BetaPendingPage` 구현** — `apps/web/lib/src/features/beta/presentation/beta_pending_page.dart`

```dart
import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';

/// 미승인(BETA_PENDING) 사용자 대기 페이지. 5초 주기로 GET /beta/status를 폴링해
/// APPROVED면 자동 재-OAuth(login(provider)), EXPIRED면 재로그인 버튼을 노출한다.
class BetaPendingPage extends ConsumerStatefulWidget {
  const BetaPendingPage({super.key});

  @override
  ConsumerState<BetaPendingPage> createState() => _BetaPendingPageState();
}

class _BetaPendingPageState extends ConsumerState<BetaPendingPage> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final data =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>('/beta/status');
      if (!mounted) return;
      final status = BetaStatus.fromJson(data);
      switch (status.status) {
        case BetaStatusKind.approved:
          _timer?.cancel();
          final p = status.provider;
          if (p != null) {
            ref.read(authControllerProvider.notifier).login(provider: p);
          } else {
            context.go('/login');
          }
        case BetaStatusKind.expired:
          _timer?.cancel();
          setState(() => _expired = true);
        case BetaStatusKind.pending:
          break;
      }
    } catch (_) {
      // 일시 오류는 무시하고 다음 주기 재시도.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DevPath AI')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expired ? Icons.lock_clock : Icons.hourglass_top, size: 48),
                const SizedBox(height: 16),
                Text('베타 대기 중', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  _expired
                      ? '대기 세션이 만료되었어요. 승인 여부는 이메일로 안내됩니다. 다시 로그인해 확인하세요.'
                      : '베타 대기자 명단에 등록되었어요. 승인되면 이메일로 알려드리고, 이 화면에서 자동으로 입장합니다.',
                  textAlign: TextAlign.center,
                ),
                if (_expired) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('다시 로그인'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: 테스트 통과 확인**

Run: `cd apps/web && flutter test test/features/beta/beta_pending_page_test.dart test/app/gate_redirect_test.dart`
Expected: PASS.

- [ ] **Step 10: 포맷 + 전체 검증 + 커밋 + PR**

```bash
cd D:/workspace/dpa/devpath-frontend && dart format .
melos run analyze
melos run test
git -C D:/workspace/dpa/devpath-frontend add -A
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(beta): /beta-pending 대기 페이지 + 승인 폴링 자동 재진입 (WS-C2b)"
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/beta-pending-page
gh pr create --repo DevPathAi/devpath-frontend --base develop --head feat/beta-pending-page \
  --title "feat: 베타 대기 페이지 + 승인 폴링 (WS-C2b)" \
  --body "spec/plan: docs/superpowers/{specs,plans}/2026-07-18-beta-pending-page*. platform 백엔드(GET /beta/status) 계약 정합. platform PR 머지 후 진행."
```

---

## 완료 정의

- platform: `feat/beta-pending-backend` PR develop 머지(CI 녹색). `GET /beta/status` 계약 확정.
- frontend: `feat/beta-pending-page` PR develop 머지(CI 녹색). 미승인자 `/beta-pending` 착지 → 승인 시 자동 진입.
- 수동 검증(런북): 실배포(WS-D) 이후 미승인 계정 로그인 → 대기 페이지 → admin 승인 → 자동 입장 e2e.
