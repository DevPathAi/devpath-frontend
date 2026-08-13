# 진단 트랙 선택 배선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 진단 시작 화면에서 트랙을 고를 수 있게 하고, 고른 트랙이 프로필에 반영되게 하며, 이 배선이 드러내는 인접 결함(고아 진단 세션)을 함께 고친다.

**Architecture:** 새 API도 새 스키마도 만들지 않는다. `POST /assessments`는 이미 `track`을 받고, `AssessmentCompletedEvent`에는 이미 `track`이 실려 있으며, platform-svc에는 그 이벤트를 받는 컨슈머가 이미 있다. 화면에 선택기를 넣고, 컨슈머에 프로필 갱신 한 줄을 더하고, 진단 시작 시 옛 세션을 정리한다.

**Tech Stack:** Flutter/Riverpod + flutter_test (frontend) · Spring Boot + JUnit 5 (platform-svc · learning-svc)

**설계 문서:** `devpath-frontend/docs/superpowers/specs/2026-08-13-diagnostic-track-selection-design.md`

## Global Constraints

이 절의 값은 모든 Task 의 요구사항에 암묵적으로 포함된다.

- 트랙 값(키)은 **서버 계약**이다. `assessments.track`·`user_profiles.target_track`·`question_bank.track`의 CHECK 제약이 같은 문자열을 쓴다. 다섯 값은 정확히 `BACKEND_SPRING` · `FRONTEND_REACT` · `MOBILE_FLUTTER` · `DEVOPS` · `FULLSTACK` 이다. **철자를 바꾸거나 값을 늘리지 않는다.**
- **트랙을 늘리는 작업은 이 계획의 범위가 아니다.** 신규 트랙(Python·Node/TS·데이터/AI)은 별도 스펙이다.
- 테스트에서 **기본값 트랙(`BACKEND_SPRING`)으로 단언하지 않는다.** 다시 하드코딩돼도 green 이 되기 때문이다. 화면 테스트는 `DEVOPS` 를 쓴다.
- 각 레포에서 작업은 지정된 브랜치에서 진행하고 해당 레포의 `develop` 으로 PR 한다. `main` 직접 push 금지.
- 커밋 메시지는 Conventional Commits, 본문은 한국어.
- 모든 git·파일 명령에 **절대경로** 또는 `git -C <레포 절대경로>` 를 쓴다. `cd` 후 상대경로로 후속 명령을 내지 않는다.
- frontend 검증은 레포 루트에서 `melos run analyze` · `melos run test` · `melos run format`. **`melos run format` 은 어긋난 파일을 고치면서 exit 1 을 낸다** — 한 번 실패했다면 재실행해 `0 changed` 를 눈으로 확인한다.
- `flutter test` 에는 `-n` 이 없다. `--plain-name` 이다.

---

## File Structure

| 레포 | 파일 | 책임 |
|---|---|---|
| frontend | `apps/web/lib/src/features/common/application/track_catalog.dart` (신설) | 트랙 값↔라벨 단일 출처 |
| frontend | `apps/web/lib/src/features/mypage/presentation/mypage_page.dart` | private `_trackLabels` 제거 → 공용 카탈로그 사용 |
| frontend | `apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart` | `_StartView` 에 트랙 선택 |
| frontend | `apps/web/test/features/diagnostic/diagnostic_page_test.dart` | 선택·비활성·호출 인자 검증 |
| frontend | `apps/web/test/golden_path_onboarding_test.dart` · `apps/web/test/golden_path_test.dart` | 통합 흐름에 트랙 선택 삽입(5곳) |
| platform-svc | `src/main/java/ai/devpath/platform/onboarding/AssessmentCompletedConsumer.java` | 진단 완료 시 `target_track` 갱신 |
| platform-svc | `src/test/java/ai/devpath/platform/onboarding/AssessmentTargetTrackSyncTest.java` (신설) | 갱신·생성 검증 |
| learning-svc | `src/main/java/ai/devpath/learning/assessment/AssessmentRepository.java` | `ABANDONED` 일괄 전이 쿼리 |
| learning-svc | `src/main/java/ai/devpath/learning/assessment/AssessmentService.java` | `start()` 에서 옛 세션 정리 |
| learning-svc | `src/test/java/ai/devpath/learning/assessment/AssessmentStartAbandonsPreviousTest.java` (신설) | 고아 세션 정리 검증 |
| learning-svc | `src/test/java/ai/devpath/learning/path/LearningPathArchiveOnSwitchTest.java` (신설) | 갈아타기 회귀 가드 |

---

### Task 1: 트랙 카탈로그 단일 출처 (frontend)

트랙 라벨이 마이페이지 안 private 상수로만 있어, 진단 화면이 쓰려면 복제해야 한다. 복제하면 트랙을 늘릴 때 한쪽만 고치는 사고가 난다. 먼저 공용 카탈로그로 옮긴다.

**Files:**
- Create: `apps/web/lib/src/features/common/application/track_catalog.dart`
- Modify: `apps/web/lib/src/features/mypage/presentation/mypage_page.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `const Map<String, String> trackLabels` — Task 2 의 진단 화면이 이것을 읽는다.

- [ ] **Step 1: 브랜치를 확인한다**

브랜치는 이미 있다. **새로 만들지 않는다.**

```bash
git -C /d/workspace/dpa/devpath-frontend branch --show-current
```

Expected: `feat/diagnostic-track-selection`

- [ ] **Step 2: 카탈로그를 만든다**

`apps/web/lib/src/features/common/application/track_catalog.dart`

```dart
/// 진단 화면과 마이페이지가 함께 쓰는 트랙 카탈로그.
///
/// **키는 서버 계약이다.** `assessments.track`·`user_profiles.target_track`·
/// `question_bank.track` 의 CHECK 제약이 이 문자열을 그대로 쓴다. 값(라벨)만 표시용이다.
///
/// 트랙을 늘릴 때는 이 파일 한 곳만 고친다 — 두 화면이 함께 따라온다.
const trackLabels = <String, String>{
  'BACKEND_SPRING': '백엔드 (Spring)',
  'FRONTEND_REACT': '프론트엔드 (React)',
  'MOBILE_FLUTTER': '모바일 (Flutter)',
  'DEVOPS': 'DevOps',
  'FULLSTACK': '풀스택',
};
```

- [ ] **Step 3: 마이페이지가 카탈로그를 쓰게 한다**

`mypage_page.dart` 에서 세 곳을 고친다.

(a) import 추가 — 파일 상단의 다른 상대 import 들 옆에 넣는다.

```dart
import '../../common/application/track_catalog.dart';
```

(b) 77-83행의 private 상수를 **삭제**한다.

```dart
  static const _trackLabels = <String, String>{
    'BACKEND_SPRING': '백엔드 (Spring)',
    'FRONTEND_REACT': '프론트엔드 (React)',
    'MOBILE_FLUTTER': '모바일 (Flutter)',
    'DEVOPS': 'DevOps',
    'FULLSTACK': '풀스택',
  };
```

(c) 남은 두 참조를 `trackLabels` 로 바꾼다(99행·207행).

```dart
    _targetTrack = trackLabels.containsKey(p.targetTrack)
```

```dart
                    for (final e in trackLabels.entries)
```

- [ ] **Step 4: 참조가 남지 않았는지 확인한다**

```bash
grep -n "_trackLabels" /d/workspace/dpa/devpath-frontend/apps/web/lib/src/features/mypage/presentation/mypage_page.dart
```

Expected: 출력 없음.

- [ ] **Step 5: 분석·테스트·포맷**

```bash
cd /d/workspace/dpa/devpath-frontend && melos run analyze
cd /d/workspace/dpa/devpath-frontend && melos run test
cd /d/workspace/dpa/devpath-frontend && melos run format
```

Expected: analyze·test 통과. `melos run format` 이 `0 changed`. (한 번 실패하면 재실행해 `0 changed` 를 확인한다.)

- [ ] **Step 6: 커밋**

```bash
git -C /d/workspace/dpa/devpath-frontend add apps/web/lib/src/features/common/application/track_catalog.dart apps/web/lib/src/features/mypage/presentation/mypage_page.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "refactor(track): 트랙 라벨을 공용 카탈로그로 옮긴다

마이페이지 안 private 상수로만 있어 진단 화면이 쓰려면 복제해야 했다.
복제하면 트랙을 늘릴 때 한쪽만 고치는 사고가 난다. 키는 서버 계약이므로
카탈로그에 그 사실을 적어 둔다."
```

---

### Task 2: 진단 시작 화면에 트랙 선택 (frontend)

**Files:**
- Modify: `apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart`
- Test: `apps/web/test/features/diagnostic/diagnostic_page_test.dart`

**Interfaces:**
- Consumes: Task 1 의 `trackLabels`
- Produces: 트랙을 고르면 `startAsMember(<선택값>)` / `startAsGuest(<선택값>)` 가 호출되는 화면. 선택 위젯 키는 `ValueKey('diagnostic-track')`, 안내 문구 키는 `ValueKey('diagnostic-track-hint')`.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`diagnostic_page_test.dart` 의 기존 import 아래에 헬퍼를 추가한다. 파일에는 이미 `_UnauthController` · `_FixedController` 가 있다(그대로 둔다).

```dart
/// 시작 호출을 기록하는 컨트롤러. 실제 API 를 부르지 않는다.
class _RecordingController extends DiagnosticController {
  final List<String> memberStarts = <String>[];
  final List<String> guestStarts = <String>[];

  @override
  DiagnosticState build() => const DiagnosticIdle();

  @override
  Future<void> startAsMember(String track) async => memberStarts.add(track);

  @override
  Future<void> startAsGuest(String track) async => guestStarts.add(track);
}

/// 인증 상태로 고정.
class _AuthedController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(
    const User(
      id: 'u',
      email: 'e@x.com',
      nickname: 'n',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.pending,
      consentStatus: ConsentStatus.done,
    ),
  );
}

```

각 테스트는 `ProviderScope` 를 직접 구성한다(공용 호스트 헬퍼를 만들지 않는다 — 인증/미인증이
테스트마다 달라 분기 헬퍼가 오히려 읽기 어려워진다).

`void main()` 안에 아래 네 테스트를 추가한다.

```dart
  testWidgets('트랙 미선택이면 시작할 수 없고 이유가 화면에 보인다', (tester) async {
    final rec = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(() => rec),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );

    // 조용한 비활성 버튼 금지 — 왜 못 누르는지 화면에 있어야 한다.
    expect(find.byKey(const ValueKey('diagnostic-track-hint')), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('게스트: 고른 트랙으로 시작한다', (tester) async {
    final rec = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(() => rec),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );

    // 기본값(BACKEND_SPRING)이 아닌 트랙을 고른다 — 다시 하드코딩되면 red 가 된다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DevOps').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(rec.guestStarts, ['DEVOPS']);
    expect(rec.memberStarts, isEmpty);
  });

  testWidgets('회원: 고른 트랙으로 시작한다', (tester) async {
    final rec = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthedController.new),
          diagnosticControllerProvider.overrideWith(() => rec),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DevOps').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(rec.memberStarts, ['DEVOPS']);
    expect(rec.guestStarts, isEmpty);
  });

  testWidgets('선택 후에는 안내 문구가 사라진다', (tester) async {
    final rec = _RecordingController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
          diagnosticControllerProvider.overrideWith(() => rec),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const DiagnosticPage(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DevOps').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('diagnostic-track-hint')), findsNothing);
  });
```

import 가 부족하면 파일 상단에 더한다(`package:dp_core/dp_core.dart` 는 이미 있다).

- [ ] **Step 2: red 를 눈으로 확인한다**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/diagnostic/diagnostic_page_test.dart
```

Expected: FAIL. 네 테스트가 모두 실패한다 — `ValueKey('diagnostic-track')` 위젯이 없다.

> 기존 테스트(`DiagnosticIdle: 시작 안내 + 진단 시작하기 CTA 렌더`)는 계속 통과해야 한다. 그것까지 깨지면 화면 구조를 잘못 건드린 것이다.

- [ ] **Step 3: `_StartView` 를 상태 위젯으로 바꾼다**

`diagnostic_page.dart` 상단에 import 를 더한다.

```dart
import '../../common/application/track_catalog.dart';
```

118-144행의 `_StartView` 전체를 아래로 교체한다.

```dart
class _StartView extends StatefulWidget {
  const _StartView({required this.auth, required this.notifier});
  final AuthState auth;
  final DiagnosticController notifier;

  @override
  State<_StartView> createState() => _StartViewState();
}

class _StartViewState extends State<_StartView> {
  /// 기본값을 두지 않는다. 트랙은 문항뿐 아니라 학습 경로와 콘텐츠 매칭까지
  /// 결정하므로, 조용한 기본값이 바로 이 화면이 냈던 결함의 형태다.
  String? _track;

  @override
  Widget build(BuildContext context) {
    final isMember = widget.auth is AuthAuthenticated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      // 헤더(DpPageHeader)가 좌측 정렬이므로 본문도 같은 축에 세운다.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('실력 진단 15문항', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DpSpacing.lg),
        DropdownButtonFormField<String>(
          key: const ValueKey('diagnostic-track'),
          initialValue: _track,
          decoration: const InputDecoration(labelText: '진단할 트랙'),
          items: [
            for (final e in trackLabels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _track = v),
        ),
        if (_track == null) ...[
          const SizedBox(height: DpSpacing.sm),
          Text(
            '트랙을 먼저 골라주세요. 고른 트랙의 문항이 나오고 학습 경로도 그 트랙으로 만들어집니다.',
            key: const ValueKey('diagnostic-track-hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: DpSpacing.lg),
        FilledButton(
          onPressed: _track == null
              ? null
              : () => isMember
                    ? widget.notifier.startAsMember(_track!)
                    : widget.notifier.startAsGuest(_track!),
          child: const Text('진단 시작하기'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: green 을 확인한다**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/diagnostic/diagnostic_page_test.dart
```

Expected: PASS (파일 전체).

- [ ] **Step 4b: 골든패스 통합 테스트를 복구한다**

트랙을 고르기 전에는 시작 버튼이 비활성이므로, **「진단 시작하기」를 바로 탭하던 통합 테스트가 깨진다.** 실측 결과 5곳이다.

| 파일 | 탭 지점(행) |
|---|---|
| `apps/web/test/golden_path_onboarding_test.dart` | 127 · 167 · 204 · 229 |
| `apps/web/test/golden_path_test.dart` | 85 |

**다섯 곳 모두** `await tester.tap(find.text('진단 시작하기'));` **바로 앞에** 아래 네 줄을 넣는다.

```dart
    // 트랙을 고르기 전에는 시작 버튼이 비활성이다.
    await tester.tap(find.byKey(const ValueKey('diagnostic-track')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백엔드 (Spring)').last);
    await tester.pumpAndSettle();
```

> **여기서 `백엔드 (Spring)`(=`BACKEND_SPRING`)을 쓰는 것은 전역 제약과 충돌하지 않는다.** 그 제약은 「화면이 어떤 트랙으로 시작했는가」를 **단언**할 때 기본값을 쓰지 말라는 것이다. 이 다섯 곳은 단언이 아니라 **입력**이며, 하드코딩 시절 이 흐름이 실제로 보내던 값이다. 같은 값을 넣어야 목 픽스처와 이후 단언이 원래 의미 그대로 유지된다.

들여쓰기는 각 지점의 주변 코드에 맞춘다. **그 밖의 줄을 바꾸지 않는다.**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/golden_path_onboarding_test.dart test/golden_path_test.dart`
Expected: PASS (5개 전부)

- [ ] **Step 5: 하드코딩이 사라졌는지 확인한다**

```bash
grep -n "BACKEND_SPRING" /d/workspace/dpa/devpath-frontend/apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart
```

Expected: 출력 없음.

- [ ] **Step 6: 전체 스위트와 포맷 게이트**

```bash
cd /d/workspace/dpa/devpath-frontend && melos run analyze
cd /d/workspace/dpa/devpath-frontend && melos run test
cd /d/workspace/dpa/devpath-frontend && melos run format
```

Expected: 전부 통과, `melos run format` 이 `0 changed`.

- [ ] **Step 7: 커밋하고 PR 을 올린다**

```bash
git -C /d/workspace/dpa/devpath-frontend add apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart apps/web/test/features/diagnostic/diagnostic_page_test.dart apps/web/test/golden_path_onboarding_test.dart apps/web/test/golden_path_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(diagnostic): 진단 시작 화면에서 트랙을 고른다

트랙이 'BACKEND_SPRING' 으로 하드코딩돼, 어떤 스택을 쓰든 백엔드 문항만
나왔다. 문항은 이미 5트랙 × 100개가 있고 POST /assessments 도 track 을
받는다 — 화면이 선택지를 주지 않았을 뿐이다.

기본값을 두지 않는다. 트랙은 학습 경로와 콘텐츠 매칭까지 결정하므로
조용한 기본값이 이 결함의 형태였다. 고르기 전에는 시작 버튼을 비활성화
하되 이유를 화면에 적는다.

테스트는 기본값이 아닌 DEVOPS 로 단언한다 — BACKEND_SPRING 으로 단언하면
다시 하드코딩돼도 green 이 된다."
git -C /d/workspace/dpa/devpath-frontend push -u origin feat/diagnostic-track-selection
cd /d/workspace/dpa/devpath-frontend && gh pr create --base develop --title "feat(diagnostic): 진단 트랙 선택" --body "설계: docs/superpowers/specs/2026-08-13-diagnostic-track-selection-design.md

진단 시작 화면이 트랙을 하드코딩해 어떤 스택을 쓰든 백엔드 문항만 나왔다. 문항·API는 이미 5트랙을 지원한다.

- 트랙 라벨을 공용 카탈로그로 추출(마이페이지와 단일 출처)
- 진단 시작 화면에 선택기 추가, 기본값 없음, 미선택 사유를 화면에 표기
- 테스트는 기본값이 아닌 \`DEVOPS\` 로 단언 — 재하드코딩 시 red

백엔드(프로필 동기화·고아 세션 정리)는 platform-svc·learning-svc PR 로 따로 올린다."
```

---

### Task 3: 진단 완료 시 프로필 트랙 동기화 (platform-svc)

**Files:**
- Modify: `src/main/java/ai/devpath/platform/onboarding/AssessmentCompletedConsumer.java`
- Test: `src/test/java/ai/devpath/platform/onboarding/AssessmentTargetTrackSyncTest.java` (신설)

**Interfaces:**
- Consumes: `AssessmentCompletedEvent{ userId(long), track(String), ... }` — 이미 존재
- Produces: `user_profiles.target_track` 이 진단 트랙으로 갱신된 상태

- [ ] **Step 1: 브랜치를 만든다**

```bash
git -C /d/workspace/dpa/devpath-platform-svc switch develop
git -C /d/workspace/dpa/devpath-platform-svc pull
git -C /d/workspace/dpa/devpath-platform-svc switch -c feat/sync-target-track
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`src/test/java/ai/devpath/platform/onboarding/AssessmentTargetTrackSyncTest.java`

기존 `AssessmentStatusConsumerUnitTest` 와 같은 방식(`@SpringBootTest` + `@ActiveProfiles("test")`)을 따른다.

```java
package ai.devpath.platform.onboarding;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import ai.devpath.platform.user.User;
import ai.devpath.platform.user.UserProfile;
import ai.devpath.platform.user.UserProfileRepository;
import ai.devpath.platform.user.UserRepository;
import ai.devpath.shared.event.AssessmentCompletedEvent;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import tools.jackson.databind.json.JsonMapper;

/**
 * 진단에서 고른 트랙이 프로필에 반영되는지 본다.
 *
 * <p>이전에는 user_profiles.target_track 을 읽는 로직이 한 곳도 없었다 —
 * 이용자가 마이페이지에서 고를 수는 있지만 아무 일도 하지 않는 값이었다.
 * 이제 진단이 출처이고 프로필이 그것을 따라간다.
 */
@SpringBootTest
@ActiveProfiles("test")
class AssessmentTargetTrackSyncTest {

  @Autowired AssessmentCompletedConsumer consumer;
  @Autowired UserRepository users;
  @Autowired UserProfileRepository profiles;
  @Autowired JsonMapper jsonMapper;

  private long newUser() {
    User u = new User();
    u.setEmail("track-" + System.nanoTime() + "@example.com");
    u.setNickname("트랙");
    u.setRole("LEARNER");
    u.setStatus("ACTIVE");
    u.setOnboardingStatus("PENDING");
    return users.save(u).getId();
  }

  private String payload(long userId, String track) throws Exception {
    return jsonMapper.writeValueAsString(
        new AssessmentCompletedEvent(
            UUID.randomUUID(),
            Instant.now(),
            1L,
            userId,
            track,
            "BEGINNER",
            Map.of(),
            Instant.now()));
  }

  @Test
  void createsProfileWhenMissing() throws Exception {
    long userId = newUser();
    assertTrue(profiles.findById(userId).isEmpty(), "사전조건: 프로필 행이 없어야 한다");

    consumer.onAssessmentCompleted(payload(userId, "DEVOPS"));

    UserProfile p = profiles.findById(userId).orElseThrow();
    assertEquals("DEVOPS", p.getTargetTrack());
  }

  @Test
  void overwritesExistingTargetTrack() throws Exception {
    long userId = newUser();
    UserProfile seed = new UserProfile();
    seed.setUserId(userId);
    seed.setTargetTrack("BACKEND_SPRING");
    profiles.save(seed);

    consumer.onAssessmentCompleted(payload(userId, "FRONTEND_REACT"));

    assertEquals("FRONTEND_REACT", profiles.findById(userId).orElseThrow().getTargetTrack());
  }
}
```

- [ ] **Step 3: red 를 확인한다**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AssessmentTargetTrackSyncTest*'
```

Expected: FAIL — 두 테스트 모두. 컨슈머가 프로필을 건드리지 않으므로 `createsProfileWhenMissing` 은 `orElseThrow` 에서, `overwritesExistingTargetTrack` 은 값이 `BACKEND_SPRING` 그대로라 실패한다.

> Redis 가 없으면 이 레포의 다른 테스트가 무더기로 깨진다. 이 Task 와 무관한 실패가 나오면 Redis 기동 여부를 먼저 확인한다.

- [ ] **Step 4: 컨슈머에 프로필 갱신을 더한다**

`AssessmentCompletedConsumer.java` 를 고친다.

(a) import 추가

```java
import ai.devpath.platform.user.UserProfile;
import ai.devpath.platform.user.UserProfileRepository;
```

(b) 필드와 생성자

```java
  private final UserRepository users;
  private final UserProfileRepository profiles;
  private final JsonMapper jsonMapper;

  public AssessmentCompletedConsumer(
      UserRepository users, UserProfileRepository profiles, JsonMapper jsonMapper) {
    this.users = users;
    this.profiles = profiles;
    this.jsonMapper = jsonMapper;
  }
```

(c) 리스너 본문의 `users.markAssessmentStartedIfPending(...)` **다음에** 아래를 넣는다.

```java
    // 진단에서 고른 트랙을 프로필에 반영한다. 프로필 행은 아직 없을 수 있다.
    UserProfile profile =
        profiles
            .findById(event.userId())
            .orElseGet(
                () -> {
                  UserProfile p = new UserProfile();
                  p.setUserId(event.userId());
                  return p;
                });
    profile.setTargetTrack(event.track());
    profiles.save(profile);
```

- [ ] **Step 5: green 을 확인한다**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test --tests '*AssessmentTargetTrackSyncTest*'
```

Expected: PASS

- [ ] **Step 6: 전체 스위트**

```bash
cd /d/workspace/dpa/devpath-platform-svc && ./gradlew test
```

Expected: PASS

- [ ] **Step 7: 커밋하고 PR 을 올린다**

```bash
git -C /d/workspace/dpa/devpath-platform-svc add src/main/java/ai/devpath/platform/onboarding/AssessmentCompletedConsumer.java src/test/java/ai/devpath/platform/onboarding/AssessmentTargetTrackSyncTest.java
git -C /d/workspace/dpa/devpath-platform-svc commit -m "feat(onboarding): 진단 트랙을 프로필에 반영한다

user_profiles.target_track 은 마이페이지에서 고를 수는 있지만 읽는 로직이
한 곳도 없어 아무 일도 하지 않는 값이었다. 반대로 실제로 문항·학습경로·
콘텐츠 매칭을 결정하는 assessments.track 은 이용자가 바꿀 수 없었다.

진단이 출처가 되고 프로필이 그것을 따라간다. AssessmentCompletedEvent 에
track 이 이미 실려 있어 새 배선은 없다. 프로필 행은 아직 없을 수 있으므로
upsert 한다."
git -C /d/workspace/dpa/devpath-platform-svc push -u origin feat/sync-target-track
cd /d/workspace/dpa/devpath-platform-svc && gh pr create --base develop --title "feat(onboarding): 진단 트랙을 프로필에 반영" --body "설계: devpath-frontend/docs/superpowers/specs/2026-08-13-diagnostic-track-selection-design.md

진단 완료 이벤트의 track 으로 user_profiles.target_track 을 갱신한다. 프로필 행이 없으면 만든다.

frontend 의 트랙 선택 PR 과 짝이다."
```

---

### Task 4: 고아 진단 세션 정리 (learning-svc)

**Files:**
- Modify: `src/main/java/ai/devpath/learning/assessment/AssessmentRepository.java` · `src/main/java/ai/devpath/learning/assessment/AssessmentService.java`
- Test: `src/test/java/ai/devpath/learning/assessment/AssessmentStartAbandonsPreviousTest.java` (신설)

**Interfaces:**
- Consumes: 없음
- Produces: `AssessmentRepository.abandonInProgressByUserId(Long)` — Task 5 는 이것을 쓰지 않는다(독립)

- [ ] **Step 1: 브랜치를 만든다**

```bash
git -C /d/workspace/dpa/devpath-learning-svc switch develop
git -C /d/workspace/dpa/devpath-learning-svc pull
git -C /d/workspace/dpa/devpath-learning-svc switch -c fix/abandon-previous-assessments
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`src/test/java/ai/devpath/learning/assessment/AssessmentStartAbandonsPreviousTest.java`

```java
package ai.devpath.learning.assessment;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 진단 시작이 그 이용자의 옛 IN_PROGRESS 세션을 정리하는지 본다.
 *
 * <p>이전에는 start() 가 아무 확인 없이 새 행을 만들어, 시작 버튼을 누를 때마다
 * 옛 세션이 IN_PROGRESS 로 남았다 — 운영 실측 10건 중 7건이 그 상태였다.
 * 트랙 선택이 생기면 「고르다 다시 시작」이 늘어 더 쌓인다.
 */
@SpringBootTest
@ActiveProfiles("test")
class AssessmentStartAbandonsPreviousTest {

  @Autowired AssessmentService service;
  @Autowired AssessmentRepository assessments;

  @Test
  void startAbandonsPreviousInProgressOfSameUser() {
    long userId = System.nanoTime();

    long first = service.start(userId, "BACKEND_SPRING");
    long second = service.start(userId, "DEVOPS");

    assertThat(assessments.findById(first).orElseThrow().getStatus()).isEqualTo("ABANDONED");
    assertThat(assessments.findById(second).orElseThrow().getStatus()).isEqualTo("IN_PROGRESS");
  }

  @Test
  void startDoesNotTouchOtherUsers() {
    long mine = System.nanoTime();
    long other = mine + 1;

    long othersAssessment = service.start(other, "BACKEND_SPRING");
    service.start(mine, "DEVOPS");

    assertThat(assessments.findById(othersAssessment).orElseThrow().getStatus())
        .isEqualTo("IN_PROGRESS");
  }
}
```

- [ ] **Step 3: red 를 확인한다**

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*AssessmentStartAbandonsPreviousTest*'
```

Expected: FAIL — `startAbandonsPreviousInProgressOfSameUser` 가 첫 세션의 상태로 `IN_PROGRESS` 를 받아 실패한다. `startDoesNotTouchOtherUsers` 는 통과한다(아직 아무것도 안 건드리므로).

> learning-svc 로컬 테스트는 **Redis + 전용 DB** 가 필요하다. 무관한 실패가 나오면 먼저 확인한다.

- [ ] **Step 4: 리포지토리에 전이 쿼리를 더한다**

`AssessmentRepository.java` 전체를 아래로 바꾼다.

```java
package ai.devpath.learning.assessment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AssessmentRepository extends JpaRepository<Assessment, Long> {

  /**
   * 새 진단을 시작할 때 그 이용자의 옛 IN_PROGRESS 세션을 정리한다.
   * status CHECK 에 ABANDONED 가 이미 있어 스키마 변경이 없다.
   */
  @Modifying
  @Query(
      "update Assessment a set a.status = 'ABANDONED' "
          + "where a.userId = :userId and a.status = 'IN_PROGRESS'")
  int abandonInProgressByUserId(@Param("userId") Long userId);
}
```

- [ ] **Step 5: `start()` 에서 호출한다**

`AssessmentService.java` 의 `start()` 를 아래로 바꾼다(39-47행).

```java
  public long start(long userId, String track) {
    // 시작 버튼을 다시 눌러도 옛 세션이 IN_PROGRESS 로 쌓이지 않게 한다.
    assessments.abandonInProgressByUserId(userId);

    Assessment a = new Assessment();
    a.setUserId(userId);
    a.setTrack(track);
    a.setStatus("IN_PROGRESS");
    a.setCurrentDifficulty(AdaptiveEngine.START_DIFFICULTY);
    a.setStartedAt(Instant.now());
    return assessments.save(a).getId();
  }
```

> `start()` 에는 **`@Transactional` 이 이미 붙어 있다**(실측 확인). `@Modifying` 쿼리가 트랜잭션 안에서 실행되므로 추가 조치가 없다. 애노테이션을 지우지 않는다.

- [ ] **Step 6: green 을 확인한다**

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*AssessmentStartAbandonsPreviousTest*'
```

Expected: PASS (두 테스트 모두)

- [ ] **Step 7: 전체 스위트**

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test
```

Expected: PASS

- [ ] **Step 8: 커밋**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add src/main/java/ai/devpath/learning/assessment/AssessmentRepository.java src/main/java/ai/devpath/learning/assessment/AssessmentService.java src/test/java/ai/devpath/learning/assessment/AssessmentStartAbandonsPreviousTest.java
git -C /d/workspace/dpa/devpath-learning-svc commit -m "fix(assessment): 새 진단 시작 시 옛 IN_PROGRESS 세션을 정리한다

start() 가 아무 확인 없이 새 행을 만들어 시작 버튼을 누를 때마다 옛 세션이
IN_PROGRESS 로 남았다 — 운영 실측 10건 중 7건이 그 상태였다. 트랙 선택이
생기면 「고르다 다시 시작」이 늘어 더 쌓인다.

status CHECK 에 ABANDONED 가 이미 있어 스키마 변경은 없다."
```

---

### Task 5: 갈아타기 회귀 가드 (learning-svc)

트랙을 바꿔 재진단하면 옛 학습 경로가 `ARCHIVED` 가 되고 새 경로가 생긴다. **이 동작은 이미 구현돼 있다** — `LearningPathPersistenceService.persist()` 가 `paths.archiveActiveByUserId(userId)` 를 먼저 부른다. 다만 이를 지키는 테스트가 없어, 누가 그 한 줄을 지우면 아무도 모른 채 재진단이 깨진다. 트랙 선택이 열리면 이 경로가 처음으로 실제로 쓰인다.

> **2026-08-14 정정 — 아래 Step 1 이 만드는 테스트는 「그 한 줄」을 지키지 않는다.** 리포지토리 쿼리만 검증하고 `persist()` 를 호출하지 않아, 호출을 지워도 green 이다(최종 리뷰 I-1). 호출은 수정 웨이브에서 더한 `LearningPathPersistenceServiceTest` 의 `persistArchivesActivePathBeforeInsertingNewOne` 이 지킨다. 아래 코드블록의 javadoc 사본도 그 시점의 옛 문구이며, 실제 파일은 정정됐다. 완료 조건 아래 정정 노트를 함께 볼 것.

**Files:**
- Test: `src/test/java/ai/devpath/learning/path/LearningPathArchiveOnSwitchTest.java` (신설)

**Interfaces:**
- Consumes: `LearningPathRepository.archiveActiveByUserId(Long)` — 이미 존재
- Produces: 없음(테스트 전용)

- [ ] **Step 1: 회귀 테스트를 쓴다**

`src/test/java/ai/devpath/learning/path/LearningPathArchiveOnSwitchTest.java`

리포지토리 수준에서 검증한다 — `persist()` 는 AI 생성 결과(`GeneratedLearningPath`)를 요구해 단위 테스트에서 조립 비용이 크다. 지켜야 할 계약은 「같은 이용자의 ACTIVE 는 아카이브된다」이므로 그것을 직접 단언한다.

> **⚠️ 벌크 JPQL 과 1차 캐시.** `archiveActiveByUserId` 는 `@Modifying` 벌크 UPDATE 라 **영속성
> 컨텍스트를 건너뛰고 DB 를 직접** 고친다. 같은 트랜잭션에서 `findById()` 로 다시 읽으면 Hibernate
> 1차 캐시의 **옛 값**이 돌아온다. 그래서 각 단언 전에 `em.clear()` 로 캐시를 비운다.
>
> 이것은 미관 문제가 아니다. `doesNotTouchOtherUsers` 는 캐시를 비우지 않으면 **쿼리가 잘못돼
> 남의 행까지 아카이브해도 통과**한다 — 판별력이 0인 테스트가 된다.
>
> 운영 코드는 이 문제를 겪지 않는다. `persist()` 도 `start()` 도 벌크 업데이트 뒤에 그 행들을
> **다시 읽지 않고** 새 행만 넣기 때문이다. 따라서 `clearAutomatically = true` 를 붙일 이유가 없다.

```java
package ai.devpath.learning.path;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.persistence.EntityManager;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * 트랙을 바꿔 재진단할 때 옛 학습 경로가 아카이브되는지 본다.
 *
 * <p>이 동작은 이미 LearningPathPersistenceService.persist() 안에 있다
 * (새 경로를 만들기 전에 archiveActiveByUserId 호출). 지키는 테스트가 없어
 * 그 한 줄이 지워지면 uq_learning_paths_active_user 위반으로 재진단이 깨진다.
 * 트랙 선택이 열리면서 이 경로가 처음으로 실제로 쓰인다.
 */
@SpringBootTest
@ActiveProfiles("test")
class LearningPathArchiveOnSwitchTest {

  @Autowired LearningPathRepository paths;
  @Autowired EntityManager em;

  private LearningPath activePath(long userId, String track) {
    LearningPath p = new LearningPath();
    p.setUserId(userId);
    p.setTrack(track);
    p.setStatus("ACTIVE");
    p.setGeneratedAt(Instant.now());
    p.setTotalWeeks(12);
    return p;
  }

  @Test
  @Transactional
  void archivesActivePathOfSameUser() {
    long userId = System.nanoTime();
    long pathId = paths.saveAndFlush(activePath(userId, "BACKEND_SPRING")).getId();

    int archived = paths.archiveActiveByUserId(userId);

    assertThat(archived).isEqualTo(1);
    // 벌크 UPDATE 는 영속성 컨텍스트를 건너뛴다 — 비우지 않으면 캐시의 옛 값을 읽는다.
    em.clear();
    assertThat(paths.findById(pathId).orElseThrow().getStatus()).isEqualTo("ARCHIVED");
  }

  @Test
  @Transactional
  void doesNotTouchOtherUsers() {
    long mine = System.nanoTime();
    long other = mine + 1;
    long othersPath = paths.saveAndFlush(activePath(other, "DEVOPS")).getId();
    paths.saveAndFlush(activePath(mine, "BACKEND_SPRING"));

    paths.archiveActiveByUserId(mine);

    // ★비우지 않으면 이 테스트는 판별력이 0이다 — 쿼리가 남의 행을 아카이브해도
    //  캐시가 ACTIVE 를 돌려줘 통과해 버린다.
    em.clear();
    assertThat(paths.findById(othersPath).orElseThrow().getStatus()).isEqualTo("ACTIVE");
  }

  @Test
  @Transactional
  void archiveMakesRoomForANewActivePath() {
    long userId = System.nanoTime();
    paths.saveAndFlush(activePath(userId, "BACKEND_SPRING"));

    paths.archiveActiveByUserId(userId);
    em.clear();

    // uq_learning_paths_active_user 는 ACTIVE 만 본다 — 아카이브 후에는 새 ACTIVE 가 들어간다.
    long newId = paths.saveAndFlush(activePath(userId, "DEVOPS")).getId();
    assertThat(paths.findById(newId).orElseThrow().getStatus()).isEqualTo("ACTIVE");
  }
}
```

> 위 헬퍼가 채우는 다섯 필드가 `learning_paths` 의 `NOT NULL` 전부다(실측 확인:
> `user_id`·`generated_at`·`track`·`total_weeks`·`status`). `gen_prompt_version`·
> `source_embedding_version`·`ai_rationale` 은 nullable 이라 비워도 저장된다.
> `track` 값은 `chk_lp_track` CHECK 를 통과해야 하므로 5트랙 중에서만 쓴다.

- [ ] **Step 2: 테스트를 돌린다**

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*LearningPathArchiveOnSwitchTest*'
```

Expected: PASS. **이 테스트는 처음부터 green 이다** — 기존 동작을 고정하는 회귀 가드이기 때문이다.

- [ ] **Step 3: 판별력을 실증한다**

green 인 테스트는 아무것도 검증하지 않을 수 있다. 실제로 결함을 잡는지 확인한다.

`LearningPathRepository.archiveActiveByUserId` 의 `@Query` 에서 `and p.status = 'ACTIVE'` 를 잠깐
`and p.status = 'NOPE'` 로 바꿔 아무 행도 맞지 않게 만든다. 그 상태로 테스트를 돌려 **red 를 눈으로
확인**한 뒤 되돌린다.

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test --tests '*LearningPathArchiveOnSwitchTest*'
git -C /d/workspace/dpa/devpath-learning-svc checkout -- src/main/java/ai/devpath/learning/path/LearningPathRepository.java
git -C /d/workspace/dpa/devpath-learning-svc status --porcelain
```

Expected: 훼손 상태에서 FAIL(적어도 `archivesActivePathOfSameUser` 가 `archived` 를 0 으로 받아 실패),
되돌린 뒤 `git status --porcelain` 에 그 파일이 나오지 않는다. **되돌리는 것을 잊지 않는다.**

- [ ] **Step 4: 전체 스위트**

```bash
cd /d/workspace/dpa/devpath-learning-svc && ./gradlew test
```

Expected: PASS

- [ ] **Step 5: 커밋하고 PR 을 올린다**

```bash
git -C /d/workspace/dpa/devpath-learning-svc add src/test/java/ai/devpath/learning/path/LearningPathArchiveOnSwitchTest.java
git -C /d/workspace/dpa/devpath-learning-svc commit -m "test(path): 트랙 갈아타기 아카이브를 회귀 가드로 고정한다

persist() 가 새 경로를 만들기 전에 archiveActiveByUserId 를 부르는 덕에
재진단이 동작한다. 그 한 줄을 지켜 주는 테스트가 없어, 지워지면
uq_learning_paths_active_user 위반으로 재진단이 조용히 깨진다.

트랙 선택이 열리면서 이 경로가 처음으로 실제로 쓰인다."
git -C /d/workspace/dpa/devpath-learning-svc push -u origin fix/abandon-previous-assessments
cd /d/workspace/dpa/devpath-learning-svc && gh pr create --base develop --title "fix(assessment): 고아 세션 정리 + 갈아타기 회귀 가드" --body "설계: devpath-frontend/docs/superpowers/specs/2026-08-13-diagnostic-track-selection-design.md

진단 트랙 선택을 여는 작업의 learning-svc 몫이다.

- 새 진단 시작 시 그 이용자의 옛 \`IN_PROGRESS\` 세션을 \`ABANDONED\` 로 정리(운영에 10건 중 7건이 고아였다)
- 트랙 갈아타기 아카이브를 회귀 테스트로 고정 — 동작은 이미 있었으나 지키는 테스트가 없었다"
```

---

## 완료 조건

- 진단 시작 화면에서 5트랙을 고를 수 있고, 고른 트랙으로 `startAsMember`/`startAsGuest` 가 호출된다.
- `diagnostic_page.dart` 에 `BACKEND_SPRING` 리터럴이 없다.
- 트랙 라벨이 `track_catalog.dart` 한 곳에만 있다.
- 진단 완료 이벤트로 `user_profiles.target_track` 이 갱신된다(프로필 행이 없으면 생성).
- 새 진단 시작 시 그 이용자의 옛 `IN_PROGRESS` 가 `ABANDONED` 가 된다.
- 갈아타기 아카이브 회귀 가드가 있고 **판별력이 실증됐다**.
- 세 레포 전체 테스트가 통과하고 PR 3건이 `develop` 대상으로 열려 있다.

> **최종 리뷰 후 정정(2026-08-14).** 위 조건은 **신규 온보딩·게스트 이용자** 기준이다.
> Task 5 의 회귀 가드도 처음에는 리포지토리 쿼리만 검증해 「`persist()` 가 그 한 줄을 부른다」를
> 지키지 못했다 — 수정 웨이브에서 `LearningPathPersistenceServiceTest` 의
> `persistArchivesActivePathBeforeInsertingNewOne` 을 더해 호출까지 고정했다(호출 제거 시 red 실증).

## 이 계획의 범위 밖

- **기존 이용자의 재진단 진입점.** `router.dart` 의 온보딩 게이트가 `onboardingStatus == DONE` 인
  이용자를 `/diagnostic` → `/path` 로 되돌리고 앱에 `/diagnostic` 링크가 없어, 「트랙을 바꿔 다시
  진단」은 이 계획 이후에도 **화면으로 도달할 수 없다**(서버·데이터 계약으로만 성립). 진입점
  신설은 별도 스펙 — 설계 문서 「이 스펙 밖」 참조.
- **트랙 3종 확장**(Python 계열 · Node/TypeScript 백엔드 · 데이터/AI) — 별도 스펙. 트랙당 지침 md + 문항 100개 + 학습 콘텐츠 + 임베딩 + DB CHECK 5곳 변경.
- 배포(각 레포 `develop`→`main` 릴리스)는 컨트롤러가 별도로 판단한다.
