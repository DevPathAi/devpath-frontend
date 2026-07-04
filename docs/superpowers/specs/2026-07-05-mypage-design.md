# 설계: ② 마이페이지 (본체)

- 날짜: 2026-07-05
- 로드맵: [documents/44_MVP_잔여_로드맵](https://github.com/DevPathAi/documents/blob/develop/44_MVP_잔여_로드맵.md) **②(화면 9)**. ④ 설정/동의(PR #69) 다음, ③③① 이전.
- 선행 의존: **오브젝트 스토리지 인프라**(devpath-shared PR #44, avatar 업로드용). 마이페이지 avatar Phase만 이 발행에 게이팅.
- 영향 레포: **devpath-platform-svc**(프로필·avatar) · **devpath-learning-svc**(완료수) · **devpath-community-svc**(활동수) · **devpath-frontend**(features/mypage). 크로스레포.
- 프론트 브랜치: `feat/mypage`(base develop).

## 배경 / 목표

MVP §3-1 화면 9(마이페이지)가 미구현(`features/mypage` 없음). 사용자 자기정보 허브이자 향후 **결제 UI(구독)가 안착할 뼈대**. platform에 `UserProfile` 엔티티(avatar·bio·learningGoal·targetTrack·experienceYears)와 Repository는 있으나 조회/수정 API가 없다(`GET /users/me`=UserSummary만).

**목표**: 프로필 전체 편집(자기소개·목표·트랙·경력) + avatar 파일 업로드 + 활동 집계(완료 콘텐츠·질문/답변 수) + 진행상황 표시 + 설정 진입을, 각 svc 집계 API를 frontend가 합성하는 구조로 구현한다.

**비목표(후속)**: 구독 섹션 실기능(→ ① 결제 spec), 팔로우/타인 프로필, avatar 리사이즈/썸네일.

## 결정 사항 (브레인스토밍 확정)

- **프로필 전체 편집**: `bio`·`learningGoal`·`targetTrack`·`experienceYears` 모두 편집(targetTrack 포함). avatar는 별도 업로드.
- **avatar = 파일 업로드**: 서버 경유(multipart → shared `ObjectStorage`). 선행 스토리지 인프라(PR #44) 소비.
- **활동 집계 = 각 svc API + frontend 합성**: MSA 경계 준수. platform·learning·community가 각자 노출, frontend가 병렬 호출·합성.
- **구독 섹션 = 이번 범위 제외**: 결제 spec에서 추가.
- **진입점 = 프로필 썸네일/아이콘**(셸 destination 아님).
- **Phase**: P1 프로필 GET/PUT → P2 avatar(스토리지 발행 후) → P3 집계 → P4 frontend.

## 컴포넌트

### P1. platform 프로필 API (devpath-platform-svc)
- `ProfileController`:
  - `GET /users/me/profile` → `ProfileView{avatar, bio, learningGoal, targetTrack, experienceYears}`. UserProfile 없으면 빈 기본값.
  - `PUT /users/me/profile` body `{bio, learningGoal, targetTrack, experienceYears}` → 저장 후 `ProfileView`. avatar는 이 API로 변경하지 않는다.
- `UserProfileService`(조회/upsert), 기존 `UserProfile`·`UserProfileRepository`(JpaRepository) 재사용.
- 검증: `bio` 최대 길이(예: 500자), `experienceYears` 범위(0~50) → 위반 `IllegalArgumentException`(→ 400 VALIDATION_FAILED).

### P2. platform avatar 업로드 (devpath-platform-svc)
- `AvatarController` `POST /users/me/avatar`(multipart/form-data, part=`file`) → shared `StoredFileValidator.validate` → `ObjectStorage.put(key="avatars/<uuid>.<ext>")` → `UserProfile.avatar = StoredObject.url` 저장 → `ProfileView` 반환.
- platform 의존: shared storage 발행분 + `software.amazon.awssdk:s3` 런타임 + `devpath.storage.*`(application.yml) 설정.
- 스토리지 장애 → 503 STORAGE_UNAVAILABLE(shared StorageException), 타입/크기 위반 → 400.

### P3. 활동 집계 (learning + community)
- **learning**: `DashboardSummary`에 `completedContentCount` 추가. `ContentProgressRepository.countCompleted(userId)` 신규(`completed_at IS NOT NULL` count). `/dashboard/me` 응답 확장(기존 소비처 회귀 확인).
- **community**: `ActivityController` `GET /community/me/activity` → `{questionCount, answerCount}`. `CommunityPostRepository.countByAuthorId(userId)`(질문=post 작성자) + `CommunityAnswerRepository.countByAuthorId(userId)`(인간 답변: `countByAuthorIdAndAiGeneratedFalse`) 신규.

### P4. frontend features/mypage (devpath-frontend)
- **dp_core**: `ProfileView`(avatar·bio·learningGoal·targetTrack·experienceYears), `MyActivity`(questionCount·answerCount) 모델.
- **features/mypage**: `mypage_source`(GET/PUT profile·POST avatar·GET dashboard·GET community activity), `mypage_controller`(병렬 로드·합성·부분 실패 내성·프로필 저장·avatar 업로드), `mypage_state`, `mypage_page`(프로필 표시/편집 폼·avatar 업로드 위젯·활동 요약·진행상황·설정 진입 링크).
- **진입**: 앱 셸에 프로필 썸네일/아이콘 → `/mypage` 라우트. avatar 있으면 이미지, 없으면 닉네임 이니셜.
- ApiClient의 multipart 업로드 지원 필요 시 dp_core `ApiClient`에 `postMultipart` 헬퍼 추가.

## 데이터 흐름
```
마이페이지 진입(/mypage) → frontend 병렬 호출:
  GET /users/me(요약: 닉네임·이메일·역할)
  GET /users/me/profile(bio·목표·트랙·경력·avatar)
  GET /dashboard/me(진행률·연속일·배지·completedContentCount)
  GET /community/me/activity(questionCount·answerCount)
  → 합성 렌더(섹션별)
편집: PUT /users/me/profile
avatar: POST /users/me/avatar(multipart) → url → 프로필 반영
설정: /settings 링크(④ 완료분) · 구독: (이번 범위 없음)
```

## 에러 처리
- 프로필 검증(bio 길이·experienceYears 범위) → 400 VALIDATION_FAILED.
- avatar 타입/크기 → 400(StoredFileValidator), 스토리지 장애 → 503 STORAGE_UNAVAILABLE.
- **집계 svc 부분 실패**: 해당 섹션만 에러/스켈레톤 표시, 전체 화면 유지(합성이라 한 svc 실패가 전체를 막지 않음). 프로필(핵심)이 실패하면 전체 에러+재시도.

## 테스트
- **platform**: ProfileController(GET 기본값·PUT 저장·검증 400), AvatarController(업로드→url·타입/크기 400·스토리지 장애 503) MockMvc.
- **learning**: `countCompleted` 단위 + `/dashboard/me` 확장 회귀(기존 필드 유지).
- **community**: ActivityController(countByAuthorId·AI답변 제외) MockMvc.
- **frontend**: mypage_controller(합성·부분 실패 내성·저장·avatar), mypage_page 스모크. `melos run test/analyze/format` 그린.

## 롤아웃 순서
1. **선행**: 스토리지 PR #44 머지 + `publish.yml` 발행(avatar Phase 전제).
2. P1 platform 프로필(스토리지 무관, 선행 가능) → P2 platform avatar(발행 후) → P3 learning/community 집계 → P4 frontend.
3. platform/learning/community 각 develop PR(백엔드), frontend develop PR. ④(PR #69) 머지 후 frontend의 설정 진입 링크 정합.

## 리스크
- **R-M1 스토리지 발행 게이트**: avatar(P2)는 shared storage 발행 후만 구현 가능. P1·P3·P4(avatar 제외)는 무관하게 선행.
- **R-M2 dashboard 확장 회귀**: `/dashboard/me`에 필드 추가 시 기존 소비처(frontend dashboard) 하위호환(추가 필드는 무시되므로 안전) 확인.
- **R-M3 프론트 multipart**: dp_core ApiClient가 multipart 미지원이면 `postMultipart` 헬퍼 추가(스토리지 spec의 put/delete 확장과 유사 파급 — `implements ApiClient` fake 선점검).
- **R-M4 ④ 의존**: 설정 진입(/settings)은 ④(PR #69) 머지 후 정합. 마이페이지 자체는 ④와 독립(링크만).
