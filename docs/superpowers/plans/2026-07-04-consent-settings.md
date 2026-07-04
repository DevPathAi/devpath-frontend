# ④ 설정 / 개인정보 동의 Implementation Plan (크로스레포)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> **크로스레포:** devpath-shared(마이그레이션), devpath-platform-svc(동의 도메인·계정삭제), devpath-frontend(gate·설정). 모든 명령에 절대경로/`-C`. 서브에이전트 위임 시 "이 Task만, 정지, 즉흥 금지" 경계 명시.

**Goal:** 회원가입 필수동의 gate + 동의 이력 저장 + 14세 차단 + 설정 화면(동의철회·알림·로그아웃·계정삭제) + soft-delete를 법적 완결 수준으로 구현한다.

**Architecture:** platform에 동의(consent) 도메인 + `users.consent_status`/`birth_year` + soft-delete를 추가하고(스키마는 devpath-shared 마이그레이션), frontend는 `consentStatus` 게이트 + consent·settings 화면을 추가한다. 롤아웃: shared 마이그레이션 발행 → platform → frontend.

**Tech Stack:** Spring Boot 4·Java 21·Flyway(중앙)·Flutter·Riverpod·dio.

## Global Constraints

- 동의 타입: 필수 `TERMS`·`PRIVACY`; 선택 `MARKETING`·`LCS_ATTACH`·`ERROR_LOG`. 14세 미만(현재연도 − birthYear < 14) → `403`.
- `consentStatus`: `PENDING`(필수 미완)/`DONE`. `onboardingStatus`와 평행, **consent 게이트가 onboarding보다 앞**.
- 계정 삭제 = soft-delete(`users.deleted_at`) + 세션 무효화. 30일 파기 배치는 gitops 후속(범위 밖).
- 마이그레이션은 **devpath-shared** `src/main/resources/db/migration/V<timestamp>__*.sql`. **발행 게이트**: shared는 main push만 자동발행 → 머지 후 `gh workflow run publish.yml --ref develop` 수동 발행 + 중앙 flyway 적용 후 platform `ddl-auto=validate` 통과.
- 브랜치: shared·platform 각 `feat/consent-domain`, frontend `feat/web-consent-settings`(현재). develop 2단계 PR.
- 알림 prefs 백엔드는 기존 재사용(`GET/PUT /notifications/prefs/me`) — 신규 없음.

---

## Phase 1 — 백엔드 (shared 마이그레이션 → platform 도메인)

### Task 1: shared 마이그레이션 (user_consents + users 컬럼)

**Files:**
- Create: `devpath-shared/src/main/resources/db/migration/V202607041001__consent.sql`
- 브랜치: `feat/consent-domain`(devpath-shared, base develop)

- [ ] **Step 1: 마이그레이션 작성**

`V202607041001__consent.sql`:
```sql
ALTER TABLE users ADD COLUMN consent_status varchar(20) NOT NULL DEFAULT 'PENDING';
ALTER TABLE users ADD COLUMN birth_year int;
ALTER TABLE users ADD COLUMN deleted_at timestamptz;

CREATE TABLE user_consents (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  type varchar(20) NOT NULL,
  version varchar(20) NOT NULL,
  agreed boolean NOT NULL,
  agreed_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);
CREATE INDEX idx_user_consents_user ON user_consents(user_id);
```
(기존 유저는 `consent_status=PENDING`으로 시작 → 다음 로그인 시 동의 gate 1회. 의도된 동작.)

- [ ] **Step 2: 빌드 확인 + 커밋 + PR**

Run: `cd /d/workspace/dpa/devpath-shared && ./gradlew build --console=plain 2>&1 | tail -3` → `BUILD SUCCESSFUL`.
커밋 `feat(db): 동의(user_consents)+users consent_status/birth_year/deleted_at 마이그레이션` → develop PR. **머지 후 수동 발행(`gh workflow run publish.yml --ref develop`) + 중앙 flyway 적용 확인**(platform 기동 validate 통과) 후 Task 2 진행.

### Task 2: platform 동의 도메인 (엔티티·리포·서비스·컨트롤러)

**Files:**
- Modify: `devpath-platform-svc/src/main/java/ai/devpath/platform/user/User.java`(consentStatus·birthYear·deletedAt 필드)
- Create: `.../consent/Consent.java`(엔티티), `ConsentRepository.java`, `ConsentType.java`(enum+version), `ConsentService.java`, `ConsentController.java`, `dto/ConsentSubmitRequest.java`, `dto/ConsentStatusView.java`
- Test: `.../consent/ConsentControllerTest.java`
- 브랜치: `feat/consent-domain`(devpath-platform-svc, base develop)

**Interfaces:**
- Produces: `POST /consents`(body `{consents:[{type,agreed}], birthYear}`→14세 403/필수완료 시 consentStatus=DONE), `GET /consents/me`(→`ConsentStatusView{consentStatus, items[], birthYear}`), `POST /consents/{type}/revoke`(선택 철회; 필수 409). `User.getConsentStatus()`.

- [ ] **Step 1: User 엔티티 확장 + 실패 테스트**

`User.java`에 필드 추가(기존 onboardingStatus 패턴):
```java
	@Column(name = "consent_status", nullable = false) private String consentStatus = "PENDING";
	@Column(name = "birth_year") private Integer birthYear;
	@Column(name = "deleted_at") private java.time.Instant deletedAt;
```
+ getter/setter. `ConsentControllerTest`(@SpringBootTest, MockMvc)에 실패 테스트: 필수2종 agreed→`GET /consents/me` consentStatus=DONE; 14세 미만 birthYear→`POST /consents` 403; 필수 철회→409. (기존 platform 테스트 패턴 참조: `AuthController`/`OAuth2LoginSuccessHandlerTest`.)

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*ConsentControllerTest' --console=plain 2>&1 | tail -8`
Expected: 컴파일 실패(Consent* 미존재).

- [ ] **Step 3: 도메인 구현**

`ConsentType.java`:
```java
package ai.devpath.platform.consent;
public enum ConsentType {
  TERMS(true, "v1"), PRIVACY(true, "v1"), MARKETING(false, "v1"),
  LCS_ATTACH(false, "v1"), ERROR_LOG(false, "v1");
  public final boolean required; public final String version;
  ConsentType(boolean r, String v) { this.required = r; this.version = v; }
}
```
`Consent.java`(엔티티 → user_consents), `ConsentRepository.java`(JdbcTemplate 또는 JPA — 레포 관례 따름: platform은 JPA `User`, JdbcTemplate도 사용 → 관례 확인 후 택일), `ConsentService.java`:
- `submit(userId, List<Item> consents, Integer birthYear)`: birthYear로 14세 검사(`Year.now().getValue() - birthYear < 14` → `throw new IllegalArgumentException`(→400 VALIDATION_FAILED, shared advice)). 각 항목 append 저장. `users.birth_year` 갱신. 필수(TERMS·PRIVACY) 둘 다 agreed면 `user.setConsentStatus("DONE")`.
- `statusOf(userId)`: consent_status + 항목 목록 + birthYear.
- `revoke(userId, type)`: `type.required`면 `throw new ConflictException`(→409); 아니면 revoked_at 기록 + agreed=false.
`ConsentController.java`(`@RequestMapping("/consents")`, `@AuthenticationPrincipal Jwt`로 userId). SecurityConfig의 permitAll에 `/consents/**`는 **추가 안 함**(인증 필요).

- [ ] **Step 4: 통과 확인 + 커밋**

Run: `cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*ConsentControllerTest' --console=plain 2>&1 | tail -6` → 통과.
커밋 `feat(consent): 동의 이력 도메인 + 14세 차단 + 철회 API`.

### Task 3: platform UserSummary.consentStatus + 계정 soft-delete

**Files:**
- Modify: `.../auth/dto/UserSummary.java`(consentStatus 추가)
- Modify: `.../user/User.java`(이미 필드 존재) + `UserController` 또는 신규 `.../user/AccountController.java`(`DELETE /users/me`)
- Test: `.../user/AccountControllerTest.java` + 기존 UserSummary 소비처 회귀
- 브랜치: 동일 `feat/consent-domain`

**Interfaces:**
- Produces: `UserSummary{id,email,nickname,role,onboardingStatus,consentStatus}`; `DELETE /users/me`(soft-delete + 세션 무효 + 로그아웃 쿠키).

- [ ] **Step 1: UserSummary 확장**

`UserSummary.java`:
```java
public record UserSummary(String id, String email, String nickname, String role,
    String onboardingStatus, String consentStatus) {
  public static UserSummary of(ai.devpath.platform.user.User u) {
    return new UserSummary(String.valueOf(u.getId()), u.getEmail(), u.getNickname(),
        u.getRole(), u.getOnboardingStatus(), u.getConsentStatus());
  }
}
```
(모든 `UserSummary.of` 호출부는 변경 없음 — 팩토리만 수정. `LoginResponse`·`/auth/refresh`가 자동 반영.)

- [ ] **Step 2: 계정 삭제 실패 테스트 → 구현**

`AccountControllerTest`: `DELETE /users/me`(인증) → `users.deleted_at` 설정 + 204 + refresh 무효화. 삭제된 유저 `/auth/refresh` → 401. 구현: `AccountController`(`@DeleteMapping("/users/me")`) → `AccountService.softDelete(userId)`(deletedAt=now, refreshStore.revokeAll(userId)) + 로그아웃 쿠키. `RefreshTokenStore.rotate`/`AuthController.refresh`가 deletedAt≠null이면 401(User 조회 시 필터 또는 명시 체크).

- [ ] **Step 3: 통과 + build + 커밋 + PR**

Run: `cd /d/workspace/dpa/devpath-platform-svc && ./gradlew build --console=plain 2>&1 | tail -3` → `BUILD SUCCESSFUL`.
커밋 `feat(account): UserSummary.consentStatus + 계정 soft-delete` → **develop PR**(Task 2·3 함께). 머지 후 Phase 2.

---

## Phase 2 — 프론트 (gate + consent·settings 화면)

### Task 4: dp_core User 모델 consentStatus + 게이트

**Files:**
- Modify: `devpath-frontend/packages/dp_core/lib/src/models/user.dart`(consentStatus 필드) + `enums.dart`(ConsentStatus)
- Modify: `apps/web/lib/src/app/router.dart`(gateRedirect consent 우선)
- Test: `apps/web/test/app/gate_redirect_test.dart`(consent gate 케이스)

**Interfaces:**
- Consumes: platform `/auth/refresh` user에 `consentStatus`. Produces: `gateRedirect`가 `consentStatus==pending` → `/consent`(onboarding보다 앞).

- [ ] **Step 1: User 모델·enum 확장 (실패 테스트 먼저)**

`enums.dart`에 `ConsentStatus{ @JsonValue('PENDING') pending, @JsonValue('DONE') done, unknown }`. `user.dart`(freezed)에 `required ConsentStatus consentStatus`. `gate_redirect_test`에 실패 케이스: `AuthAuthenticated(user consentStatus=pending)` → `/consent` 기대.

- [ ] **Step 2: 게이트 구현**

`gateRedirect`(router.dart)에서 `AuthAuthenticated` 분기 **최상단**(onboarding 앞)에:
```dart
  final consentDone = auth.user.consentStatus == ConsentStatus.done;
  final atConsent = location == '/consent';
  if (!consentDone) return atConsent ? null : '/consent';
```
(이후 기존 onboarding 게이트.) `/consent` 라우트 등록. freezed 재생성(`dart run build_runner build`) 필요.

- [ ] **Step 3: 통과 + 커밋**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/app/gate_redirect_test.dart -r compact` → 통과.
커밋 `feat(web): consentStatus 게이트 — 미동의 시 /consent 우선`.

### Task 5: consent 화면 (동의 gate)

**Files:**
- Create: `apps/web/lib/src/features/consent/`(data source·controller·presentation)
- Test: `apps/web/test/features/consent/*`

**Interfaces:**
- Consumes: platform `POST /consents`(body `{consents:[{type,agreed}],birthYear}`→성공 시 auth 갱신 consentStatus=DONE; 403=14세). Produces: 동의 제출 후 `authController` 갱신 → 게이트가 diagnostic으로.

- [ ] **Step 1~4: TDD**

`consent_source.dart`(`ApiClient.post('/consents', ...)`), `consent_controller.dart`(제출·403→차단상태), `consent_page.dart`(필수 체크 2종+생년+선택 토글, [34] 마이크로카피 문구, 제출 버튼). 실패 테스트(제출→DONE 전이, 403→차단) 선작성 → 구현 → 통과. 제출 성공 시 `authController`의 user consentStatus를 done으로 갱신(기존 `onboardingCompleted` 패턴의 consent판 메서드 `markConsentDone(user)` 추가).

- [ ] **Step 5: 커밋** `feat(web/consent): 회원가입 필수동의 gate 화면 + 14세 차단`.

### Task 6: settings 화면 (동의철회·알림·로그아웃·계정삭제)

**Files:**
- Create: `apps/web/lib/src/features/settings/`
- Modify: 앱 셸(설정 진입 아이콘)
- Test: `apps/web/test/features/settings/*`

**Interfaces:**
- Consumes: `GET /consents/me`·`POST /consents/{type}/revoke`(platform), `GET/PUT /notifications/prefs/me`(notification), `POST /auth/logout`·`DELETE /users/me`(platform).

- [ ] **Step 1~4: TDD**

`settings_source.dart`(위 API 배선), `settings_controller.dart`, `settings_page.dart`(동의 현황·선택동의 토글, 알림 토글, 로그아웃 버튼, 계정삭제 확인 모달). 실패 테스트(알림 토글 PUT 호출, 계정삭제→로그아웃 전이) 선작성 → 구현 → 통과.

- [ ] **Step 5: 전체 회귀 + format + 커밋 + PR**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test -r compact
cd /d/workspace/dpa/devpath-frontend && dart format --output=none --set-exit-if-changed .
```
Expected: 그린 / 0 changed. 커밋 `feat(web/settings): 설정 화면 — 동의철회·알림·로그아웃·계정삭제` → **develop PR**(Task 4~6 프론트 묶음).

---

## Self-Review 결과

- **Spec 커버리지**: 동의도메인→Task2, 스키마→Task1, UserSummary·계정삭제→Task3, 게이트→Task4, consent화면→Task5, settings→Task6. 알림 재사용·비범위(마케팅실발송·변호사) 태스크 없음(의도적). ✅
- **플레이스홀더**: 백엔드 도메인·마이그레이션·UserSummary는 실코드. **프론트 화면(Task5·6)은 구조+계약+핵심 배선 지시**로, 위젯 세부 코드는 실행 시 기존 feature(diagnostic·dashboard) 패턴 복제 — 대형 UI 기능의 불가피한 런북 요소로 명시. ⚠️(불가피)
- **타입 일관성**: `consentStatus`(User·UserSummary·dp_core enum·gate) 일관. `ConsentType`(필수 TERMS·PRIVACY) = 14세/필수완료 로직 = 프론트 제출. `POST /consents` body 계약 = Task2 정의 = Task5 소비. ✅
- **의존/게이트**: Task1(shared) 머지·**수동 발행**·중앙 flyway 적용 → Task2·3(platform) → Task4~6(frontend, platform 머지 후). R-④-1(발행)·R-④-2(게이트 순서)·R-④-3(기존유저 재동의) 반영. ✅
- **주의**: birth_year를 `users`(User 엔티티 위치)에 둠(spec의 user_profiles 대신) — User 엔티티가 users 매핑이라 단순화. 기능 동일.
