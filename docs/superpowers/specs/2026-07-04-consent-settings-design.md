# ④ 설계: 설정 / 개인정보 동의 (법적 완결)

- 날짜: 2026-07-04
- 로드맵: [documents/44_MVP_잔여_로드맵](https://github.com/DevPathAi/documents/blob/develop/44_MVP_잔여_로드맵.md) 중 **④(첫 항목)**. 순서 ④→②→③→①.
- 영향 레포: **devpath-platform-svc**(동의 도메인·계정삭제·birth_year) · **devpath-frontend**(동의 gate·설정 화면). notification-svc는 기존 알림 prefs API 재사용(신규 없음).
- 프론트 브랜치: `feat/web-consent-settings`(base develop). 백엔드는 platform 별도 브랜치.

## 배경 / 목표

MVP §3-1 화면 10(설정)·법적 필수(약관·개인정보 동의)가 미구현. 라우터는 `onboardingStatus`(진단)로만 게이팅하고 **회원가입 동의 절차·설정 화면이 없다**. 알림 설정 백엔드(notification-svc `/notifications/prefs`·`/notifications/devices`)는 이미 존재. 근거 문서: [34_동의화면_마이크로카피](https://github.com/DevPathAi/documents/blob/develop/34_동의화면_마이크로카피.md)(개인정보보호법 §15-2 4요소), [33_개인정보_처리방침](https://github.com/DevPathAi/documents/blob/develop/33_개인정보_처리방침.md).

**목표(법적 완결)**: 회원가입 필수동의 gate + 동의 이력 저장 + 14세 미만 차단 + 설정 화면(동의 철회·알림·로그아웃·계정삭제) + soft-delete 계정삭제.

**비목표**: 마케팅 실발송. 변호사 최종 검토(외부·게이팅). 알림 prefs 백엔드 신규(기존 재사용). ② 마이페이지(후행).

## 결정 사항

- **동의 gate 위치**: OAuth 로그인 직후·diagnostic 전. 신규 `consentStatus`(user 필드, `onboardingStatus`와 평행)로 라우터 게이팅.
- **계정 삭제**: soft-delete + 30일 유예 후 파기/익명화.

## 컴포넌트

### B1. 동의 도메인 (platform-svc, 신규)
- **스키마**(devpath-shared 마이그레이션): `user_consents(user_id, type, version, agreed, agreed_at, revoked_at)`; `user_profiles.birth_year INT`(신규 컬럼).
- **동의 타입**: 필수 `TERMS`·`PRIVACY`; 선택 `MARKETING`·`LCS_ATTACH`·`ERROR_LOG`. 각 타입 현행 `version` 상수.
- **API**(platform):
  - `POST /consents` — body `{consents:[{type,agreed}], birthYear}`. 14세 미만(현재연도-birthYear<14)이면 `403 VALIDATION_FAILED`(가입 차단). 필수 2종 모두 agreed=true여야 `consentStatus=DONE`, 아니면 저장하되 PENDING 유지. 이력 append.
  - `GET /consents/me` — 현황 `{consentStatus, items:[{type,agreed,version,agreedAt}], birthYear}`.
  - `POST /consents/{type}/revoke` — 선택 동의 철회(revoked_at 기록). 필수 타입 철회는 `409 CONFLICT`(계정 삭제로만).
- **UserSummary 확장**: `consentStatus`(PENDING/DONE) 추가 → 프론트 게이트가 소비. `/auth/refresh`·게이트가 이 값을 읽음.

### B2. 계정 삭제 (platform-svc)
- `DELETE /users/me` — soft-delete: `users.deleted_at` 설정 + 세션(refresh) 무효화 + 로그아웃 쿠키. 30일 후 배치가 파기/익명화(배치 스케줄은 gitops 후속; 이 spec은 soft-delete 표식+API까지).
- 삭제된 계정은 로그인 시 `403`(또는 유예 내 복구 안내 — 유예 복구 UI는 비범위, 표식만).

### F1. 동의 gate 화면 (frontend `features/consent`, 신규)
- 라우터: `AuthAuthenticated` && `consentStatus==PENDING` → `/consent`(diagnostic·기타보다 우선). 기존 `gateRedirect` 확장(onboarding 앞단).
- 화면: 필수 동의 체크(약관·개인정보, 각 [34] 마이크로카피 + 전문 링크), 생년(연도) 입력, 선택 동의 토글. 제출 → `POST /consents` → 성공 시 `consentStatus=DONE`으로 auth 갱신 → 게이트가 diagnostic으로.
- 14세 미만 응답(403) → 차단 안내 화면 + 로그아웃.

### F2. 설정 화면 (frontend `features/settings`, 신규)
- **동의 관리**: `GET /consents/me` 표시, 선택 동의 토글(`POST /consents` 또는 `/revoke`).
- **알림 설정**: 기존 `GET/PUT /notifications/prefs`(이메일/카테고리 토글) 배선 + FCM 토큰은 `/notifications/devices`(웹은 선택).
- **계정**: 로그아웃(`POST /auth/logout` 기존), 계정 삭제(`DELETE /users/me` + 확인 모달).
- 진입: 앱 셸(프로필/설정 아이콘). ② 마이페이지 완성 시 거기서도 진입(후행, 무관).

## 데이터 흐름 (동의 gate)

```
OAuth 로그인 → /auth/refresh → UserSummary{consentStatus:PENDING}
  → gateRedirect: PENDING → /consent
  → 필수동의 체크+생년 제출 → POST /consents
     → 14세 미만? 403 → 차단화면+로그아웃
     → OK → consentStatus=DONE → auth 갱신 → gateRedirect: onboarding(diagnostic)
```

## 테스트

- **platform**: `ConsentController` (필수2종 동의→DONE, 미완→PENDING, 14세 미만→403, 철회, 필수철회→409), 계정삭제(soft-delete 표식+세션무효), `GET /consents/me`. 기존 UserSummary 회귀.
- **frontend**: consent gate 라우팅(PENDING→/consent, DONE→통과), consent 화면 제출·14세 차단, 설정 화면(동의 토글·알림 배선·로그아웃·삭제 모달). 위젯·컨트롤러 테스트 + `melos run test/analyze/format` 그린.

## 롤아웃 순서

1. **platform 선행**: 동의 도메인 + 스키마 + 계정삭제 API + UserSummary.consentStatus. shared 스키마 발행 게이트 주의([[devpath-web-posttier2-roadmap]] 교훈: shared는 main push만 자동발행 → 필요 시 `gh workflow run publish.yml --ref develop`).
2. **frontend**: consent gate + 화면 2개(consent·settings). platform 머지·발행 후 실계약 배선.
3. 기존 유저 마이그레이션: 마이그레이션이 기존 user에 `consentStatus=PENDING` 부여 → 다음 로그인 시 동의 gate 1회(운영 주의).

## 리스크

- **R-④-1 shared 스키마 발행 게이트**: user_consents·birth_year 마이그레이션이 devpath-shared 소관이면 발행 필요(C2 교훈).
- **R-④-2 consentStatus 게이트 우선순위**: consent가 onboarding보다 앞이어야 함(gateRedirect 순서 정확히).
- **R-④-3 기존 유저 재동의**: 마이그레이션으로 전원 PENDING → 로그인 시 동의 1회. 의도된 동작(약관 신규 도입).
- **R-④-4 법적 검토**: 문구·보존기간은 [33]/[34] 반영하되 **변호사 최종 검토는 외부**(배포 전 게이팅, 이 spec 범위 밖).
