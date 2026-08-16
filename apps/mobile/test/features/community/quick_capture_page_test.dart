import 'dart:async';

import 'package:devpath_mobile/src/features/community/presentation/quick_capture_page.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/community/data/community_source.dart';
import 'package:devpath_mobile/src/features/community/data/quick_capture_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'POST /community/questions': (
    201,
    {
      'id': 99,
      'title': '새 질문',
      'bodyMd': '본문',
      'solved': false,
      'acceptedAnswerId': null,
      'upvoteCount': 0,
      'downvoteCount': 0,
      'tags': <String>[],
      'answers': <Map<String, dynamic>>[],
    },
  ),
  'GET /community/posts': (200, <Map<String, dynamic>>[]),
};

GoRouter _router() => GoRouter(
  initialLocation: '/community/new',
  routes: [
    GoRoute(
      path: '/community',
      builder: (_, _) => const Scaffold(body: Center(child: Text('목록화면'))),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const QuickCapturePage()),
      ],
    ),
  ],
);

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp.router(theme: DpTheme.light(), routerConfig: _router()),
);

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

void main() {
  testWidgets('빈 입력 제출 → 검증 스낵바', (tester) async {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient(_fx)),
        currentOwnerKeyProvider.overrideWithValue('owner-a'),
        quickCaptureStoreProvider.overrideWithValue(
          QuickCaptureStore(InMemoryOwnerDataStore()),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('게시'));
    await tester.pump();
    expect(find.text('제목과 본문을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('정상 제출 → 게시 후 목록으로 복귀', (tester) async {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient(_fx)),
        currentOwnerKeyProvider.overrideWithValue('owner-a'),
        quickCaptureStoreProvider.overrideWithValue(
          QuickCaptureStore(InMemoryOwnerDataStore()),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '새 질문');
    await tester.enterText(find.byType(TextField).at(1), '본문 내용');
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();

    // pop 되어 목록 화면이 보인다.
    expect(find.text('목록화면'), findsOneWidget);
  });

  testWidgets('mounted page clears A immediately then restores only B draft', (
    tester,
  ) async {
    final store = _ControlledQuickCaptureStore({
      'owner-a': const QuickCaptureDraft(
        title: 'A title',
        body: 'A body',
        tags: ['a'],
      ),
      'owner-b': const QuickCaptureDraft(
        title: 'B title',
        body: 'B body',
        tags: ['b'],
      ),
    });
    final bRead = store.latchRead('owner-b');
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient(_fx)),
        currentOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        quickCaptureStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(_text(tester, 0), 'A title');

    c.read(_ownerProvider.notifier).setOwner('owner-b');
    await tester.pump();
    final bReadStarted = bRead.started.isCompleted;
    bRead.release.complete();
    expect(bReadStarted, isTrue);
    expect(_text(tester, 0), isEmpty);
    expect(_text(tester, 1), isEmpty);
    expect(_text(tester, 2), isEmpty);

    await tester.pumpAndSettle();
    expect(_text(tester, 0), 'B title');
    expect(_text(tester, 1), 'B body');
    expect(_text(tester, 2), 'b');
  });

  testWidgets('late A restore cannot paint or save into B', (tester) async {
    final store = _ControlledQuickCaptureStore({
      'owner-a': const QuickCaptureDraft(title: 'late A', body: 'A body'),
      'owner-b': const QuickCaptureDraft(title: 'B title', body: 'B body'),
    });
    final aRead = store.latchRead('owner-a');
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient(_fx)),
        currentOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        quickCaptureStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await aRead.started.future;
    c.read(_ownerProvider.notifier).setOwner('owner-b');
    await tester.pump();
    await tester.pump();

    aRead.release.complete();
    await tester.pumpAndSettle();
    expect(_text(tester, 0), 'B title');
    expect(_text(tester, 1), 'B body');
    expect(store.writes['owner-b'], isEmpty);
  });

  testWidgets('late A submit cannot clear B draft or pop B page', (
    tester,
  ) async {
    final store = _ControlledQuickCaptureStore({
      'owner-a': const QuickCaptureDraft(title: 'A title', body: 'A body'),
      'owner-b': const QuickCaptureDraft(title: 'B title', body: 'B body'),
    });
    final submitted = Completer<CommunityQuestionDetail>();
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient(_fx)),
        currentOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        quickCaptureStoreProvider.overrideWithValue(store),
        questionCreateProvider.overrideWithValue(
          ({required title, required bodyMd, required tags}) =>
              submitted.future,
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('게시'));
    await tester.pump();

    c.read(_ownerProvider.notifier).setOwner('owner-b');
    await tester.pump();
    await tester.pump();

    submitted.complete(
      const CommunityQuestionDetail(
        id: 99,
        title: 'A submitted',
        bodyMd: 'A body',
        solved: false,
        answers: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuickCapturePage), findsOneWidget);
    expect(_text(tester, 0), 'B title');
    expect(store.clears, isEmpty);
  });
}

String _text(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void setOwner(String? owner) => state = owner;
}

final class _ReadLatch {
  final started = Completer<void>();
  final release = Completer<void>();
}

class _ControlledQuickCaptureStore extends QuickCaptureStore {
  _ControlledQuickCaptureStore(Map<String, QuickCaptureDraft> initial)
    : drafts = Map.of(initial),
      super(InMemoryOwnerDataStore());

  final Map<String, QuickCaptureDraft> drafts;
  final Map<String, List<QuickCaptureDraft>> writes = {};
  final List<String> clears = [];
  final Map<String, _ReadLatch> _readLatches = {};

  _ReadLatch latchRead(String ownerKey) {
    final latch = _ReadLatch();
    _readLatches[ownerKey] = latch;
    return latch;
  }

  @override
  Future<QuickCaptureDraft?> read(String ownerKey) async {
    final latch = _readLatches.remove(ownerKey);
    if (latch != null) {
      latch.started.complete();
      await latch.release.future;
    }
    return drafts[ownerKey];
  }

  @override
  Future<void> write(String ownerKey, QuickCaptureDraft draft) async {
    writes.putIfAbsent(ownerKey, () => []).add(draft);
    if (draft.isEmpty) {
      drafts.remove(ownerKey);
    } else {
      drafts[ownerKey] = draft;
    }
  }

  @override
  Future<void> clear(String ownerKey) async {
    clears.add(ownerKey);
    drafts.remove(ownerKey);
  }
}
