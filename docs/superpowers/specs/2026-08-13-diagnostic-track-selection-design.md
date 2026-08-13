# 진단 트랙 선택 배선 설계

**작성일:** 2026-08-13
**대상 레포:** `devpath-frontend`(진단 화면) · `devpath-platform-svc`(프로필 동기화) · `devpath-learning-svc`(경로 갈아타기·세션 정리)

## 문제

이용자가 실력 진단을 시작하면 **언제나 백엔드(Spring) 문항**이 나온다. 홈페이지 신청 폼에서 스택을
여러 개 적을 수 있는데도 진단은 하나뿐이라 입력이 의미가 없다.

원인은 화면에 있다.

```dart
// apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart:137-138
onPressed: () => isMember
    ? notifier.startAsMember('BACKEND_SPRING')
    : notifier.startAsGuest('BACKEND_SPRING'),
```

**문항은 이미 다 있다.** `question_bank`에 5트랙 × 100문항이 있고(`BACKEND_SPRING`·`FRONTEND_REACT`·
`MOBILE_FLUTTER`·`DEVOPS`·`FULLSTACK`), `POST /assessments`는 `track`을 인자로 받는다.
화면이 선택지를 주지 않을 뿐이다.

## 트랙이 두 개로 갈라져 있다

| | 이용자가 바꿀 수 있나 | 실제로 하는 일 |
|---|---|---|
| `assessments.track` | ❌ 하드코딩 | 문항 선택 · **학습 경로 생성** · 콘텐츠 매칭 |
| `user_profiles.target_track` | ✅ 마이페이지 드롭다운 | **없음** — 저장·표시 전용 |

`target_track`을 읽는 로직은 전 레포에 **0건**이다(`UserProfile`·`ProfileView`·`ProfileUpdateRequest`·
`UserProfileService` 밖에서 등장하지 않는다). 학습 경로는 `diagnosis.track()`, 즉 진단의 트랙을 쓴다.

**바꿀 수 있는 값은 아무 일도 안 하고, 실제로 중요한 값은 바꿀 수 없다.** 이용자가 마이페이지에서
「프론트엔드」를 골라도 진단은 계속 Spring 문항을 낸다.

## 범위

이 스펙은 **배선을 잇는 것**만 다룬다. 트랙 자체를 늘리는 작업(Python 계열 · Node/TypeScript 백엔드 ·
데이터/AI 3종 추가)은 **별도 스펙**이다. 신규 트랙은 지침 md + 문항 100개 + 학습 콘텐츠 + 임베딩 +
DB CHECK 5곳 변경이 따라붙어 성격도 크기도 다르다.

순서는 이 스펙이 먼저다. 트랙을 늘려도 화면에서 고를 수 없으면 이용자에게 아무 변화가 없고,
이 배선만으로도 **오늘 당장 5트랙을 고를 수 있게** 된다.

베타 신청 폼의 스택을 앱 계정까지 실어 나르는 배선은 **만들지 않는다.** 이용자가 진단 시작 시
직접 고르므로 필요가 없고, 신청과 가입 사이의 시간차·이메일 불일치 문제를 떠안게 된다.
신청 폼의 스택은 지금처럼 **어떤 트랙을 만들지 판단하는 자료**로만 쓴다.

## 설계

### 화면 — 진단 시작에서 고른다

`diagnostic_page.dart`의 `_StartView`에 트랙 선택을 넣는다. 회원과 게스트가 **같은 위젯에서 분기**하므로
선택기 하나로 둘 다 해결된다.

**기본값을 두지 않는다.** 트랙은 문항뿐 아니라 학습 경로와 콘텐츠 매칭까지 결정한다. 조용한 기본값이
바로 이번 결함의 형태다. 매번 이용자가 직접 고른다.

고르기 전에는 시작 버튼을 비활성화하되 **왜 눌리지 않는지 화면에 적는다.** 조용한 비활성 버튼은
이 레포에서 이미 사고를 낸 적이 있다(2026-07-27 동의 화면).

**프로필 기반 프리필은 하지 않는다.** `UserSummary`(세션)는 `id`·`email`·`nickname`·`role`·
`onboardingStatus`·`consentStatus`만 담아 `targetTrack`이 없다. 프리필하려면 진단 화면이
`GET /users/me/profile`을 따로 부르고 로딩·실패 경로를 다뤄야 하는데, **온보딩으로 처음 들어온
이용자는 프로필이 비어 있어 프리필할 값 자체가 없다.** 값이 있는 경우는 재진단뿐이고, 그때는
트랙을 바꾸려는 의도적 행동이므로 직접 고르는 편이 자연스럽다. 온보딩 임계경로에 네트워크
호출을 더할 이유가 없다.

트랙 라벨은 마이페이지 `_trackLabels`와 **같은 출처**를 쓴다. 두 화면이 각자 리터럴을 들고 있으면
트랙을 늘릴 때 한쪽만 고치는 사고가 난다. 지금 `_trackLabels`는 `mypage_page.dart`의
`_BodyState` 안 private 상수다. 이를 공용 카탈로그로 옮기고 두 화면이 함께 읽는다.

```
apps/web/lib/src/features/common/application/track_catalog.dart
```

`features/common/`은 이미 `application/`·`presentation/` 구조로 존재하며 `external_link_opener`가
같은 자리에 있다. 새 레이어를 만들지 않는다.

트랙을 늘리는 후속 작업(별도 스펙)은 **이 파일 한 곳만** 고치면 두 화면이 함께 따라온다.

| 값 | 라벨 |
|---|---|
| `BACKEND_SPRING` | 백엔드 (Spring) |
| `FRONTEND_REACT` | 프론트엔드 (React) |
| `MOBILE_FLUTTER` | 모바일 (Flutter) |
| `DEVOPS` | DevOps |
| `FULLSTACK` | 풀스택 |

### 데이터 흐름 — 새 배선을 거의 만들지 않는다

```
진단 시작 화면 → POST /assessments {track}        ← 이미 track 을 받는다
      ↓ 완료
AssessmentCompletedEvent {track}                   ← 이미 track 이 실려 있다
      ↓ Kafka
platform-svc AssessmentCompletedConsumer           ← 이미 있다(onboarding_status 갱신)
      ↓ 추가되는 것
user_profiles.target_track = event.track
```

`AssessmentCompletedConsumer`는 현재 `UserRepository`만 주입받는다. 프로필 갱신을 위해 프로필
리포지토리가 추가로 필요하고, **프로필 행이 아직 없을 수 있으므로 upsert**여야 한다.

마이페이지 드롭다운은 그대로 두되, 이제 **사실을 반영**하게 된다.

### 재진단 = 갈아타기 — **이미 동작한다**

다른 트랙으로 진단을 마치면 기존 `ACTIVE` 학습 경로가 `ARCHIVED`가 되고 새 경로가 생긴다.
**이 동작은 이미 구현돼 있다.**

```java
// LearningPathPersistenceService.persist() — 새 경로를 만들기 전에
paths.archiveActiveByUserId(userId);
```

`LearningPathRepository.archiveActiveByUserId()`가 `status='ACTIVE'`인 행을 `ARCHIVED`로 내린다.
`ActivePathConflictException`은 정상 경로가 아니라 **동시 생성 경합용 안전망**이다.

따라서 이 스펙은 갈아타기를 **새로 만들지 않는다.** 다만 트랙 선택을 열면 이 경로가 처음으로
실제로 쓰이므로, 「다른 트랙으로 경로를 만들면 옛 경로가 ARCHIVED가 된다」를 **회귀 테스트로
고정**한다. 지금은 이 동작을 지키는 테스트가 없어, 누가 `archiveActiveByUserId` 호출을 지우면
아무도 모른 채 재진단이 깨진다.

회귀 가드는 **둘로 나뉜다** — 하나만으로는 「그 한 줄」이 지켜지지 않는다.

| 테스트 | 지키는 것 | 지키지 <b>못</b>하는 것 |
|---|---|---|
| `LearningPathArchiveOnSwitchTest` (통합) | 쿼리 — 내 ACTIVE만 ARCHIVED, 그 뒤 새 ACTIVE 삽입 | `persist()`를 호출하지 않으므로 호출 여부 |
| `LearningPathPersistenceServiceTest.persistArchivesActivePathBeforeInsertingNewOne` (mock) | `persist()`가 저장 **전에** 아카이브를 부른다 | 쿼리가 실제로 맞는 행만 내리는지 |

- `learning_paths.status`는 이미 `CHECK (status IN ('ACTIVE','ARCHIVED'))` — 스키마 변경 없음
- `CREATE UNIQUE INDEX uq_learning_paths_active_user ON learning_paths(user_id) WHERE status = 'ACTIVE'`
  는 그대로 산다(이용자당 ACTIVE 1개)
- 과거 경로는 기록으로 남는다

## 인접 결함 — 고아 진단 세션

`AssessmentService.start()`는 아무 확인 없이 새 행을 만든다.

```java
public long start(long userId, String track) {
  Assessment a = new Assessment();
  ...
  a.setStatus("IN_PROGRESS");
```

그래서 시작 버튼을 누를 때마다 옛 세션이 `IN_PROGRESS`로 남는다 — 운영 실측 **10건 중 7건**이 그 상태였다.
트랙 선택을 넣으면 「고르다 다시 시작」이 늘어 더 쌓인다.

새 진단을 시작할 때 그 이용자의 기존 `IN_PROGRESS`를 `ABANDONED`로 내린다.
`assessments.status`는 이미 `CHECK (status IN ('IN_PROGRESS','COMPLETED','ABANDONED'))`다 —
스키마 변경 없음.

## 테스트

**기본값으로 통과하는 테스트를 만들지 않는다.** 이번 결함이 정확히 그 형태였다.

| 대상 | 단언 |
|---|---|
| 진단 화면 | 트랙 미선택이면 시작 불가 **+ 이유가 화면에 보인다** |
| 진단 화면 | **`DEVOPS`를 골라** 시작하면 `startAsMember('DEVOPS')`로 호출된다 |
| 진단 화면 | 게스트도 같다 — `startAsGuest('DEVOPS')` |
| platform-svc | `AssessmentCompletedEvent{track}` 수신 시 `target_track`이 갱신된다(프로필 행 없으면 생성) |
| learning-svc | 다른 트랙으로 경로 생성 시 기존 `ACTIVE`가 `ARCHIVED`, 새 경로가 `ACTIVE` |
| learning-svc | `persist()`가 새 경로를 저장하기 **전에** `archiveActiveByUserId`를 부른다 |
| learning-svc | 새 진단 시작 시 그 이용자의 기존 `IN_PROGRESS`가 `ABANDONED` |

두 번째·세 번째가 핵심이다. `BACKEND_SPRING`으로 단언하면 누군가 다시 하드코딩해도 green이므로
**일부러 기본값이 아닌 트랙**을 쓴다.

## 완료 조건

완료 조건은 **신규 온보딩·게스트 이용자** 기준이다. 온보딩을 마친 이용자는
`router.dart`가 `/diagnostic`을 `/path`로 되돌리고 앱에 그 링크도 없어, 아래 조건을
**UI로 실행할 수 없다**(아래 「이 스펙 밖」 참조).

- 진단 시작 화면에서 5트랙을 고를 수 있고, 고른 트랙의 문항이 나온다.
- 진단을 마치면 마이페이지 트랙이 그 값으로 바뀐다.
- 다른 트랙으로 다시 진단하면 옛 학습 경로가 `ARCHIVED`가 되고 새 경로가 생긴다(오류 없이).
  — 서버 계약으로서 성립하고 회귀 테스트로 고정된다. UI 진입점은 아직 없다.
- 진단을 다시 시작해도 `IN_PROGRESS` 세션이 쌓이지 않는다.
- 위 테스트가 모두 통과한다.

## 이 스펙 밖

- **기존 이용자의 재진단 진입점.** 이 스펙은 트랙 선택을 **신규 온보딩·게스트 경로에만**
  연다. `apps/web/lib/src/app/router.dart`의 온보딩 게이트가 `onboardingStatus == DONE`인
  이용자를 `/diagnostic` → `/path`로 되돌리고, 앱 어디에도 `/diagnostic` 링크가 없다.
  따라서 「트랙을 바꿔 다시 진단」은 서버·데이터 계약으로만 성립하고 **화면으로는 도달
  불가**다. 진입점 신설(게이트 예외 + 마이페이지·경로 화면의 「트랙 바꾸기」 버튼)은
  별도 스펙이다. 그때까지 마이페이지 「목표 트랙」 편집은 여전히 아무것도 바꾸지 않는다.
- **트랙 3종 확장**(Python 계열 · Node/TypeScript 백엔드 · 데이터/AI) — 별도 스펙. 트랙당
  지침 md 1개 + 문항 100개 + 학습 콘텐츠 + 임베딩 + DB CHECK 5곳(`question_bank`·`assessments`·
  `learning_paths`·`contents`·`user_profiles`) 변경. 오프라인 생성 파이프라인
  (`learning-svc/tools/content-gen`, Ollama `qwen2.5:14b`)이 이미 있다.
- 베타 신청 폼 → 앱 계정 스택 전달(위 「범위」 참조).
