# 전체 앱 상태 matrix 통일(N02) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web` 8개 화면(Login, Diagnostic, Today, Path, Community, Content, Sandbox, Mentor)의 loading / empty / error / success / partial 상태와 복구 행동을 공용 primitive 로 통일하고, 각 상태를 실패하는 위젯 테스트로 먼저 고정한다.

**Architecture:** 전체 화면 상태는 기존 `DpLoading`·`DpEmpty`·`DpError`(+`SupportableError`)를 그대로 쓴다. 다섯 화면이 각자 손으로 만든 "데이터를 유지한 채 보이는 인라인 실패/부분 실패 알림"(login 오류 박스, diagnostic `_FailureBanner`, content `_InlineContentError`, dashboard `_SupportingMetricsError`, mentor `_InlineError`/`_PartialNotice`/`_PartialText`, Today/Path 실패 Text)은 새 primitive `DpInlineNotice` 하나로 대체한다. 새 primitive 는 이 한 개뿐이다(스펙: 두 화면 이상에서 같은 의미일 때만 신설). `DpLoading` 은 접근성 라벨(liveRegion) 을 얻는다.

**Tech Stack:** Flutter 3.44.1 / flutter_riverpod / go_router / melos 7 (`dart run melos run test`). 테스트는 `flutter_test` 위젯 테스트, 폭은 `tester.view.physicalSize`, 테마는 `DpTheme.light()`.

**Spec:** `docs/community-information-architecture/task.md` §5 N02 + `handoff.md` §9.2.

## Global Constraints

- 레포 CLAUDE.md 절대 조건: 추측 금지 · 테스트 우선 · 원인 분석 우선 · 신규 브랜치 · 자화자찬 금지.
- 브랜치: `feat/app-state-matrix-20260917` (이미 `origin/develop` 895e29c 에서 분기, worktree `D:\workspace\dpa\.worktrees\frontend-app-state-matrix-20260917`).
- 커밋은 Conventional Commits, 마지막 줄 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- 모든 명령은 worktree 절대경로에서 실행한다. `cd` 후 상대경로 연쇄 금지.
- 단일 패키지 테스트: `cd <worktree>/apps/web && flutter test <path>`; 전체 게이트: `dart run melos run format && dart run melos run analyze && dart run melos run test`.
- 새 primitive 는 `DpInlineNotice` 하나만 허용. 기존 공개 API(`DpLoading({Key? key, String? label})`, `DpError`, `DpEmpty`) 시그니처는 바꾸지 않는다.
- 카피(한국어) 는 이 문서에 적힌 문자열을 그대로 쓴다. 테스트가 문자열을 잠근다.

---

### Task 1: `DpLoading` 접근성 라벨

**Files:**
- Modify: `packages/dp_design/lib/src/states/dp_loading.dart`
- Test: `packages/dp_design/test/states/base_states_test.dart`

**Interfaces:**
- Produces: `DpLoading` 이 `Semantics(label: label ?? '불러오는 중', liveRegion: true)` 로 감싸진다. 시그니처 불변.

- [ ] **Step 1: 실패하는 테스트 추가** (`base_states_test.dart` 의 `main()` 끝에 추가)

```dart
  testWidgets('DpLoading은 라벨 유무와 무관하게 liveRegion 시맨틱을 가진다', (tester) async {
    await tester.pumpWidget(_host(const DpLoading()));
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    await tester.pumpWidget(_host(const DpLoading(label: '오늘의 미션을 불러오는 중')));
    final node = tester.getSemantics(find.bySemanticsLabel('오늘의 미션을 불러오는 중'));
    expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
  });
```

`import 'package:flutter/semantics.dart';` 를 파일 상단 import 에 추가한다.

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917/packages/dp_design && flutter test test/states/base_states_test.dart`
Expected: FAIL — `find.bySemanticsLabel('불러오는 중')` 0 widgets.

- [ ] **Step 3: 구현** — `dp_loading.dart` 전체를 다음으로 교체

```dart
import 'package:flutter/material.dart';

/// 스켈레톤/진행 표시(간소). 상세 shimmer는 사용처에서 확장.
///
/// 스크린리더는 [label](없으면 '불러오는 중')을 liveRegion 으로 읽는다.
class DpLoading extends StatelessWidget {
  const DpLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? '불러오는 중',
    liveRegion: true,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(label!, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: 통과 확인** — 같은 명령, 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add packages/dp_design/lib/src/states/dp_loading.dart packages/dp_design/test/states/base_states_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(dp_design): give DpLoading a live-region semantics label" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `DpInlineNotice` primitive

**Files:**
- Create: `packages/dp_design/lib/src/states/dp_inline_notice.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가, `export 'src/states/dp_sse_stage.dart';` 다음 줄)
- Test: `packages/dp_design/test/states/inline_notice_test.dart`

**Interfaces:**
- Produces:
```dart
enum DpInlineNoticeTone { danger, warning, info }
class DpInlineNotice extends StatelessWidget {
  const DpInlineNotice({
    super.key,
    required this.message,
    this.tone = DpInlineNoticeTone.danger,
    this.actionLabel,
    this.onAction,
  });
}
```
  - 데이터를 유지한 채 보이는 인라인 알림. 항상 `Semantics(liveRegion: true)`. `actionLabel` 이 있으면 `TextButton` 을 렌더하고 `onAction` 이 null 이면 비활성.
  - 폭 520 미만이면 세로(메시지 → 버튼 우측 정렬), 이상이면 가로(메시지 Expanded + 버튼).
  - 루트 위젯 key: `ValueKey('dp-inline-notice')`.

- [ ] **Step 1: 실패하는 테스트 작성** — `inline_notice_test.dart` 신규

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 800}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: Center(child: SizedBox(width: width, child: child)),
  ),
);

void _noop() {}

void main() {
  testWidgets('DpInlineNotice는 메시지를 liveRegion으로 알린다', (tester) async {
    await tester.pumpWidget(
      _host(const DpInlineNotice(message: '완료를 저장하지 못했어요.')),
    );
    expect(find.text('완료를 저장하지 못했어요.'), findsOneWidget);
    final node = tester.getSemantics(find.byKey(const ValueKey('dp-inline-notice')));
    expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('DpInlineNotice는 행동 라벨이 있을 때만 버튼을 렌더하고 호출한다', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      _host(
        DpInlineNotice(
          message: '보조 학습 지표를 불러오지 못했어요.',
          tone: DpInlineNoticeTone.warning,
          actionLabel: '지표 다시 보기',
          onAction: () => acted = true,
        ),
      ),
    );
    await tester.tap(find.text('지표 다시 보기'));
    expect(acted, isTrue);
  });

  testWidgets('DpInlineNotice는 onAction이 null이면 버튼을 비활성으로 둔다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpInlineNotice(
          message: '진행률을 저장하지 못했어요.',
          actionLabel: '진행률 저장 다시 시도',
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('DpInlineNotice는 좁은 폭에서 세로로 쌓이고 넓은 폭에서 가로로 놓인다', (tester) async {
    Widget notice() => const DpInlineNotice(
      message: '메시지',
      actionLabel: '다시 시도',
      onAction: _noop,
    );
    await tester.pumpWidget(_host(notice(), width: 360));
    final narrowMessage = tester.getTopLeft(find.text('메시지'));
    final narrowButton = tester.getTopLeft(find.text('다시 시도'));
    expect(narrowButton.dy, greaterThan(narrowMessage.dy));

    await tester.pumpWidget(_host(notice(), width: 800));
    final wideMessage = tester.getCenter(find.text('메시지'));
    final wideButton = tester.getCenter(find.text('다시 시도'));
    expect((wideButton.dy - wideMessage.dy).abs(), lessThan(24));
    expect(wideButton.dx, greaterThan(wideMessage.dx));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917/packages/dp_design && flutter test test/states/inline_notice_test.dart`
Expected: 컴파일 실패 — `DpInlineNotice` 미정의.

- [ ] **Step 3: 구현** — `dp_inline_notice.dart` 신규

```dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// 인라인 알림의 의미 톤. 색은 [DpColors] 의 danger/warning/primary 를 따른다.
enum DpInlineNoticeTone { danger, warning, info }

/// 이미 그린 데이터를 유지한 채 보여주는 인라인 알림(부분 실패·저장 실패·경고).
///
/// 전체 화면 상태(`DpError`/`DpEmpty`)와 달리 콘텐츠 흐름 안에 놓이며,
/// 스크린리더는 liveRegion 으로 메시지를 읽는다. 행동은 [actionLabel] 이 있을 때
/// 하나만 렌더되고, [onAction] 이 null 이면 비활성이다(제출 중 등).
class DpInlineNotice extends StatelessWidget {
  const DpInlineNotice({
    super.key,
    required this.message,
    this.tone = DpInlineNoticeTone.danger,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final DpInlineNoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double _stackBelowWidth = 520;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final accent = switch (tone) {
      DpInlineNoticeTone.danger => colors.danger,
      DpInlineNoticeTone.warning => colors.warning,
      DpInlineNoticeTone.info => colors.primary,
    };
    final text = Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
    );
    final action = actionLabel == null
        ? null
        : TextButton(onPressed: onAction, child: Text(actionLabel!));

    return Semantics(
      key: const ValueKey('dp-inline-notice'),
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DpSpacing.md),
          child: action == null
              ? text
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < _stackBelowWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          text,
                          const SizedBox(height: DpSpacing.xs),
                          Align(alignment: Alignment.centerRight, child: action),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: DpSpacing.sm),
                        action,
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
```

`packages/dp_design/lib/dp_design.dart` 에 `export 'src/states/dp_inline_notice.dart';` 추가.

- [ ] **Step 4: 통과 확인** — 같은 명령 4 PASS. `flutter analyze` (dp_design) 0 issues.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add packages/dp_design/lib/src/states/dp_inline_notice.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/states/inline_notice_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(dp_design): add DpInlineNotice for in-flow recoverable failures" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Login — 세션 확인 loading + 오류 인라인 알림

**Files:**
- Modify: `apps/web/lib/src/features/auth/presentation/login_page.dart`
- Test: `apps/web/test/features/auth/login_page_test.dart`

**Interfaces:**
- Consumes: `DpLoading`, `DpInlineNotice` (Task 1·2).
- Produces: `LoginPage` 는 `AuthLoading` 이면 접근 패널 대신 `DpLoading(label: '세션을 확인하는 중')` 을 렌더하고, `AuthUnauthenticated.error` 는 `DpInlineNotice(tone: danger)` 로 표시한다.

- [ ] **Step 1: 실패하는 테스트 추가** (`login_page_test.dart` `main()` 끝)

```dart
  testWidgets('세션 복원 중(AuthLoading)에는 로그인 버튼 대신 확인 중 상태를 보인다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_LoadingAuthController.new),
        appConfigProvider.overrideWithValue(
          const AppConfig(baseUrl: 'https://test.devpath.ai/api/v1', useMock: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    expect(find.bySemanticsLabel('세션을 확인하는 중'), findsOneWidget);
    expect(find.text('GitHub로 계속하기'), findsNothing);
  });

  testWidgets('로그인 오류는 인라인 알림으로 표시되고 버튼은 유지된다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _ErrorAuthController('로그인 세션이 만료됐어요.'),
        ),
        appConfigProvider.overrideWithValue(
          const AppConfig(baseUrl: 'https://test.devpath.ai/api/v1', useMock: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    expect(find.byKey(const ValueKey('dp-inline-notice')), findsOneWidget);
    expect(find.text('로그인 세션이 만료됐어요.'), findsOneWidget);
    expect(find.text('GitHub로 계속하기'), findsOneWidget);
  });
```

파일 상단(기존 `_FakeOAuthLauncher` 아래)에 컨트롤러 두 개 추가:

```dart
class _LoadingAuthController extends AuthController {
  @override
  AuthState build() => const AuthLoading();
}

class _ErrorAuthController extends AuthController {
  _ErrorAuthController(this.message);
  final String message;
  @override
  AuthState build() => AuthUnauthenticated(error: message);
}
```

필요한 import: `package:devpath_web/src/features/auth/application/auth_controller.dart`, `package:devpath_web/src/features/auth/state/auth_state.dart`, `package:dp_design/dp_design.dart`(이미 있으면 생략).

- [ ] **Step 2: 실패 확인**

Run: `cd D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917/apps/web && flutter test test/features/auth/login_page_test.dart`
Expected: 새 테스트 2건 FAIL.

- [ ] **Step 3: 구현**

`login_page.dart` `build()` 의 `final access = _LoginAccessPanel(...)` 를 다음으로 바꾼다:

```dart
    final access = auth is AuthLoading
        ? const _LoginSessionCheck()
        : _LoginAccessPanel(
            error: error,
            useMock: useMock,
            onGithub: () => useMock
                ? ref.read(authControllerProvider.notifier).bootstrapFromCallback()
                : ref.read(authControllerProvider.notifier).login(),
            onGoogle: () => useMock
                ? ref.read(authControllerProvider.notifier).bootstrapFromCallback()
                : ref.read(authControllerProvider.notifier).login(provider: 'google'),
          );
```

`_LoginAccessPanel` 클래스 위에 추가:

```dart
class _LoginSessionCheck extends StatelessWidget {
  const _LoginSessionCheck();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('login-session-check'),
    constraints: const BoxConstraints(maxWidth: 480),
    padding: const EdgeInsets.all(DpSpacing.xl),
    child: const DpLoading(label: '세션을 확인하는 중'),
  );
}
```

`_LoginAccessPanel.build` 의 오류 박스(`if (error != null) ...[ Container(... Text(error!) ...), SizedBox ]`)를 다음으로 교체:

```dart
                if (error != null) ...[
                  DpInlineNotice(message: error!),
                  const SizedBox(height: DpSpacing.lg),
                ],
```

교체 후 `c`(dpColors) 변수를 더 이상 쓰지 않으면 선언을 지운다(analyze 경고 방지).

- [ ] **Step 4: 통과 확인** — 같은 파일 테스트 전체 PASS, analyze 0.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/auth/presentation/login_page.dart apps/web/test/features/auth/login_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): standardize login loading and error states" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Auth callback — 원시 spinner 를 `DpLoading` 으로

**Files:**
- Modify: `apps/web/lib/src/features/auth/presentation/auth_callback_page.dart:87`
- Test: `apps/web/test/features/auth/auth_callback_page_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** (`main()` 끝)

```dart
  testWidgets('callback 진행 중에는 접근 가능한 로딩 상태를 보인다', (tester) async {
    final auth = _PendingAuthController();
    final continuation = _ContinuationController();
    final router = GoRouter(
      initialLocation: '/auth/callback',
      routes: [
        GoRoute(path: '/auth/callback', builder: (_, _) => const AuthCallbackPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          diagnosticControllerProvider.overrideWith(() => continuation),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('로그인을 확인하는 중'), findsOneWidget);
  });
```

상단에 컨트롤러 추가(`import 'dart:async';` 포함):

```dart
class _PendingAuthController extends AuthController {
  @override
  AuthState build() => const AuthLoading();

  @override
  Future<void> bootstrapFromCallback() => Completer<void>().future;
}
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/auth/auth_callback_page_test.dart` → 새 테스트 FAIL.

- [ ] **Step 3: 구현** — 87행 교체:

```dart
    return const Scaffold(body: DpLoading(label: '로그인을 확인하는 중'));
```

`import 'package:dp_design/dp_design.dart';` 가 없으면 추가.

- [ ] **Step 4: 통과 확인** — 같은 명령 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/auth/presentation/auth_callback_page.dart apps/web/test/features/auth/auth_callback_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): use DpLoading for the OAuth callback pending state" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Diagnostic — 단계 loading·실패 배너를 primitive 로

**Files:**
- Modify: `apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart` (`_StageLoading` 811-824, `_FailureBanner` 785-810)
- Test: `apps/web/test/features/diagnostic/diagnostic_page_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** (`main()` 끝). 이 파일의 기존 `_host(controller)` 헬퍼(73행)와, `diagnosticControllerProvider.overrideWith(() => controller)` 에 넘기는 스텁 컨트롤러 타입을 읽고 그 타입으로 상태를 주입한다. 아래의 `_stub(...)` 는 그 타입 생성자 이름으로 바꾼다. `NextQuestion` 생성은 파일에 이미 있는 헬퍼가 있으면 그것을 쓰고, 없으면 `packages/dp_core/lib/src/models/` 의 `NextQuestion.fromJson` 키를 열어 맞춘다(추측 금지).

```dart
  testWidgets('문항 준비 중에는 라벨 있는 접근 가능한 로딩을 보인다', (tester) async {
    final controller = _stub(
      const DiagnosticState(
        phase: DiagnosticContinuationPhase.question,
        track: 'BACKEND_SPRING',
        busy: true,
      ),
    );
    await tester.pumpWidget(_host(controller));
    expect(find.bySemanticsLabel('진단을 준비하고 있어요'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('답변 실패는 인라인 알림으로 표시되고 문항은 유지된다', (tester) async {
    final controller = _stub(
      DiagnosticState(
        phase: DiagnosticContinuationPhase.question,
        track: 'BACKEND_SPRING',
        nextQuestion: _question(),
        failure: const DiagnosticFailure(
          DiagnosticFailureKind.answer,
          '답변을 저장하지 못했어요.',
        ),
      ),
    );
    await tester.pumpWidget(_host(controller));
    expect(find.byKey(const ValueKey('dp-inline-notice')), findsOneWidget);
    expect(find.text('답변을 저장하지 못했어요.'), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/diagnostic/diagnostic_page_test.dart` → 새 테스트 FAIL.

- [ ] **Step 3: 구현**

`_StageLoading` 클래스를 다음으로 교체:

```dart
class _StageLoading extends StatelessWidget {
  const _StageLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DpLoading(label: label);
}
```

`_FailureBanner` 클래스를 다음으로 교체:

```dart
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final DiagnosticFailure failure;

  @override
  Widget build(BuildContext context) => DpInlineNotice(message: failure.message);
}
```

- [ ] **Step 4: 통과 확인** — 같은 파일 전체 PASS, analyze 0.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart apps/web/test/features/diagnostic/diagnostic_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): route diagnostic loading and failure through shared state primitives" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Today — 보조 지표 partial 오류와 미션 실패 알림

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart` (`_SupportingMetricsError` 201-222)
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/today_mission_section.dart` (129-144 failure Text)
- Test: `apps/web/test/features/dashboard/today_dashboard_page_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** (`main()` 끝; `_pumpDashboard`·`_DashboardMissionApi`·`_QueuedDashboardClient`·`_mission` 은 기존 헬퍼. `_QueuedDashboardClient.get` 은 `responses[dashboardCalls]` 를 그대로 반환하므로 `Future.error` 가 그대로 전달된다.)

```dart
  testWidgets('보조 지표 실패는 인라인 알림 + 재시도로 표시되고 Today primary는 유지된다', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: _QueuedDashboardClient([
        Future.error(StateError('metrics down')),
        Future.value({
          'streakDays': 7,
          'progressPercent': 62,
          'nextTaskTitle': 'legacy next task',
          'badges': <String>[],
          'completedContentCount': 12,
        }),
      ]),
    );
    await tester.pump();
    expect(find.text('JPA 트랜잭션 경계 읽기'), findsOneWidget);
    final notice = find.byKey(const ValueKey('dp-inline-notice'));
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text('지표 다시 보기')), findsOneWidget);
    await tester.tap(find.text('지표 다시 보기'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('today-metrics-section')), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/dashboard/today_dashboard_page_test.dart` → 새 테스트 FAIL.

- [ ] **Step 3: 구현**

`dashboard_page.dart` `_SupportingMetricsError` 클래스를 다음으로 교체:

```dart
class _SupportingMetricsError extends StatelessWidget {
  const _SupportingMetricsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DpInlineNotice(
    message: '보조 학습 지표를 불러오지 못했어요. $message',
    tone: DpInlineNoticeTone.warning,
    actionLabel: '지표 다시 보기',
    onAction: onRetry,
  );
}
```

`today_mission_section.dart` 129-144 의 `Semantics(liveRegion: true, child: Text(...))` 블록을 다음으로 교체:

```dart
          if (state.failureMessage != null) ...[
            const SizedBox(height: DpSpacing.sm),
            DpInlineNotice(
              message: completionFailed
                  ? '완료를 저장하지 못했어요. 현재 미션과 진행 상태는 그대로예요.'
                  : '미션을 새로 확인하지 못했어요. 마지막으로 확인한 미션은 유지됩니다.',
            ),
          ],
```

- [ ] **Step 4: 통과 확인** — `flutter test test/features/dashboard` 전체 PASS(문구 불변).

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart apps/web/lib/src/features/dashboard/presentation/widgets/today_mission_section.dart apps/web/test/features/dashboard/today_dashboard_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): show Today partial failures with DpInlineNotice" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Path — 미션 실패·상세 불일치 알림

**Files:**
- Modify: `apps/web/lib/src/features/path/presentation/mission_path_plan_view.dart` (163-192 두 Semantics/Text 블록)
- Test: `apps/web/test/features/path/mission_path_plan_view_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** (`main()` 끝). 189행 테스트 `'NO_ACTIVE_PATH stale 실패는 마지막 결과와 재조회 행동을 명시한다'` 가 `isStale`+`failureMessage` 상태를 만드는 방식을 읽고 그대로 복제하되, AVAILABLE 미션에 `pathId` 가 다른 plan 을 넘겨 상세 불일치를 유도한다. 헬퍼 이름·인자는 파일에서 읽는다(추측 금지).

```dart
  testWidgets('stale 미션 실패와 상세 불일치는 인라인 알림으로 표시된다', (tester) async {
    await tester.pumpWidget(
      _host(/* AVAILABLE + isStale: true + failureMessage: '연결 끊김', plan.pathId != mission.pathId */),
    );
    final notices = find.byKey(const ValueKey('dp-inline-notice'));
    expect(notices, findsNWidgets(2));
    expect(find.text('현재 미션과 경로 상세가 아직 맞지 않아요.'), findsOneWidget);
    expect(find.text('마지막으로 확인한 미션을 표시하고 있어요.'), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/path/mission_path_plan_view_test.dart` → FAIL.

- [ ] **Step 3: 구현** — 163-192 두 블록을 교체:

```dart
          if (!detailMatches && plan != null) ...[
            const SizedBox(height: DpSpacing.sm),
            const DpInlineNotice(
              message: '현재 미션과 경로 상세가 아직 맞지 않아요.',
              tone: DpInlineNoticeTone.warning,
            ),
          ],
          if (missionState.failureMessage != null) ...[
            const SizedBox(height: DpSpacing.sm),
            DpInlineNotice(
              message: completionFailed
                  ? '완료를 저장하지 못했어요. 현재 미션은 그대로예요.'
                  : '마지막으로 확인한 미션을 표시하고 있어요.',
            ),
          ],
```

- [ ] **Step 4: 통과 확인** — `flutter test test/features/path` 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/path/presentation/mission_path_plan_view.dart apps/web/test/features/path/mission_path_plan_view_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): show Path mission failures with DpInlineNotice" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Content — 인라인 로드/진행률 실패를 `DpInlineNotice` 로

**Files:**
- Modify: `apps/web/lib/src/features/content/presentation/content_page.dart` (`_InlineContentError` 632-~690)
- Test: `apps/web/test/features/content/content_page_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** — 기존 41행 테스트(`scroll 후 progress POST와 완료 refresh를 수행한다`)의 어댑터 구성과 스크롤 동작을 읽고, `POST /contents/<같은 slug>/progress` 를 500 으로 등록한 어댑터로 같은 스크롤을 수행한다:

```dart
  testWidgets('진행률 저장 실패는 본문을 유지한 채 인라인 알림과 재시도를 보인다', (tester) async {
    final adapter = /* 41행과 같은 구성, progress POST 만 500 */;
    await tester.pumpWidget(_host(adapter));
    await tester.pumpAndSettle();
    /* 41행과 같은 스크롤 동작 */
    await tester.pumpAndSettle();
    final notice = find.byKey(const ValueKey('dp-inline-notice'));
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text('진행률 저장 다시 시도')), findsOneWidget);
    expect(find.byType(WebContentProjection), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/content/content_page_test.dart` → FAIL.

- [ ] **Step 3: 구현** — `_InlineContentError` 본문을 교체(시그니처 유지):

```dart
class _InlineContentError extends StatelessWidget {
  const _InlineContentError({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DpInlineNotice(
    message: message,
    actionLabel: actionLabel,
    onAction: onRetry,
  );
}
```

- [ ] **Step 4: 통과 확인** — content 테스트 디렉터리 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/content/presentation/content_page.dart apps/web/test/features/content/content_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): use DpInlineNotice for content load and progress failures" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Community Q/A 상세 — 실패 상태에 복구 행동 추가

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/qna_detail_page.dart:68-71`
- Test: `apps/web/test/features/community/qna_detail_page_test.dart` (231행 테스트 확장)

- [ ] **Step 1: 실패하는 테스트** — 231행 `'조회 실패 시 헤더와 에러 안내가 함께 렌더된다'` 의 fetch 오버라이드를 카운팅 버전으로 바꾸고 끝에 재시도 단언을 추가:

```dart
    var calls = 0;
    // ... overrides: qnaDetailFetchProvider.overrideWithValue((id) async {
    //   calls += 1;
    //   throw const ApiException(<기존 235행과 동일 인자>);
    // }),
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(calls, 2);
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/community/qna_detail_page_test.dart` → FAIL (`다시 시도` 0).

- [ ] **Step 3: 구현** — 68-71행 교체:

```dart
            QnaFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: SupportableError(
                message: message,
                onRetry: () =>
                    ref.read(qnaDetailControllerProvider.notifier).load(_id),
              ),
            ),
```

- [ ] **Step 4: 통과 확인** — 같은 파일 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/community/presentation/qna_detail_page.dart apps/web/test/features/community/qna_detail_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "fix(web): give the Q/A detail failure state a retry action" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Mentor — 실패·부분 상태 알림 통일

**Files:**
- Modify: `apps/web/lib/src/features/mentor/presentation/mentor_page.dart` (`_PartialNotice` 685-711, `_PartialText` 713-727, `_InlineError` 729-745)
- Test: `apps/web/test/features/mentor/mentor_page_test.dart` (101행 테스트 확장)

- [ ] **Step 1: 실패하는 테스트** — 101행 테스트 마지막 두 expect 아래에 추가:

```dart
    final notice = find.byKey(const ValueKey('dp-inline-notice'));
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text('다시 시도')), findsOneWidget);
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/mentor/mentor_page_test.dart` → FAIL.

- [ ] **Step 3: 구현** — 세 클래스 교체. 교체 전 `_PartialNotice` 원본(685-711)의 기본 문구를 읽어, 원본 문구가 다르면 그것을 유지한다.

```dart
class _PartialNotice extends StatelessWidget {
  const _PartialNotice({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: DpSpacing.lg,
      vertical: DpSpacing.sm,
    ),
    child: DpInlineNotice(
      message: message ?? '연결이 끊겼어요. 받은 답변은 그대로 두었어요.',
      tone: DpInlineNoticeTone.warning,
      actionLabel: '다시 시도',
      onAction: onRetry,
    ),
  );
}

class _PartialText extends StatelessWidget {
  const _PartialText({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
    child: DpInlineNotice(
      message: message ?? '연결이 끊겼어요. 받은 답변은 그대로 두었어요.',
      tone: DpInlineNoticeTone.warning,
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
    child: DpInlineNotice(message: message),
  );
}
```

- [ ] **Step 4: 통과 확인** — mentor 테스트 디렉터리 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/lib/src/features/mentor/presentation/mentor_page.dart apps/web/test/features/mentor/mentor_page_test.dart
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "feat(web): unify mentor failure and partial notices" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: 상태 matrix 계약 테스트(회귀 방지) + 문서

**Files:**
- Create: `apps/web/test/app/state_matrix_contract_test.dart`
- Create: `docs/design/app-state-matrix.md`

- [ ] **Step 1: 테스트 작성**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pages = <String>[
  'lib/src/features/auth/presentation/login_page.dart',
  'lib/src/features/auth/presentation/auth_callback_page.dart',
  'lib/src/features/diagnostic/presentation/diagnostic_page.dart',
  'lib/src/features/dashboard/presentation/dashboard_page.dart',
  'lib/src/features/dashboard/presentation/widgets/today_mission_section.dart',
  'lib/src/features/path/presentation/path_page.dart',
  'lib/src/features/path/presentation/mission_path_plan_view.dart',
  'lib/src/features/community/presentation/community_home_page.dart',
  'lib/src/features/community/presentation/post_detail_page.dart',
  'lib/src/features/community/presentation/qna_detail_page.dart',
  'lib/src/features/content/presentation/content_page.dart',
  'lib/src/features/sandbox/presentation/sandbox_page.dart',
  'lib/src/features/mentor/presentation/mentor_page.dart',
];

void main() {
  test('화면 소스는 전체화면 원시 spinner 대신 DpLoading 을 쓴다', () {
    for (final path in _pages) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('Center(child: CircularProgressIndicator())'),
        isFalse,
        reason: '$path 는 전체화면 원시 spinner 를 쓰면 안 된다',
      );
    }
  });

  test('화면 소스는 손으로 만든 danger 배너 대신 DpInlineNotice 를 쓴다', () {
    for (final path in _pages) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('danger.withValues(alpha: 0.08)'),
        isFalse,
        reason: '$path 는 인라인 실패를 DpInlineNotice 로 표현해야 한다',
      );
    }
  });

  test('Q/A 상세의 전체화면 실패 상태는 재시도 행동을 가진다', () {
    final source = File(
      'lib/src/features/community/presentation/qna_detail_page.dart',
    ).readAsStringSync();
    expect(source.contains('SupportableError(message: message)'), isFalse);
  });
}
```

- [ ] **Step 2: 실행** — `flutter test test/app/state_matrix_contract_test.dart` → PASS. 실패하면 그 화면의 잔여 원시 패턴을 같은 방식으로 교체한다.

- [ ] **Step 3: 문서** — `docs/design/app-state-matrix.md` 에 8행 표(화면 | loading | empty | error | partial | 복구)와 규칙("전체화면 상태는 DpLoading/DpEmpty/DpError(SupportableError), 데이터를 유지하는 인라인 실패는 DpInlineNotice, 새 primitive 는 두 화면 이상에서 같은 의미일 때만") + 계약 테스트 경로를 적는다. 표 내용은 Task 3~10 에서 실제로 적용한 위젯·문구를 그대로 옮긴다.

- [ ] **Step 4: 전체 게이트**

```bash
cd D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 && dart run melos run format && dart run melos run analyze && dart run melos run test
```
Expected: format 0 changed(변경 시 `dart run melos run fix` 후 재실행), analyze 0 issues, test 전부 PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 add apps/web/test/app/state_matrix_contract_test.dart docs/design/app-state-matrix.md
git -C D:/workspace/dpa/.worktrees/frontend-app-state-matrix-20260917 commit -m "test(web): lock the app state matrix contract and document it" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: PR

- [ ] `git -C <worktree> push -u origin feat/app-state-matrix-20260917`
- [ ] `gh pr create --repo DevPathAi/devpath-frontend --base develop --head feat/app-state-matrix-20260917 --title "feat(web): unify app state matrix with DpInlineNotice" --body-file <요약 파일>` — 본문: 목적(N02), 화면별 변경 표, 검증 명령 결과, 마지막 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- [ ] `gh pr checks <n> --watch` 녹색 확인 후 `gh pr merge <n> --merge`.
