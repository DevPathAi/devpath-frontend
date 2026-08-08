import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('title, meta, progress, markdown, sandbox button을 렌더한다', (
    tester,
  ) async {
    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: '# 비동기 기초\n\n본문')),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    expect(find.text('Future/async-await 정리'), findsOneWidget);
    expect(find.textContaining('8분'), findsOneWidget);
    expect(find.text('20% 진행'), findsOneWidget);
    expect(find.textContaining('비동기 기초'), findsWidgets);
    expect(find.text('실습'), findsOneWidget);

    await tester.tap(find.text('실습'));
    await tester.pumpAndSettle();

    expect(find.text('sandbox route'), findsOneWidget);
  });

  testWidgets('scroll 후 progress POST와 완료 refresh를 수행한다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 0.9,
            'dwellSec': 46,
            'completed': true,
            'completedAt': '2026-06-21T10:00:00Z',
          },
        ),
      ],
      'GET /learning-paths/me': [(200, mockLearningPath())],
      'GET /dashboard/me': [
        (
          200,
          {
            'streakDays': 7,
            'progressPercent': 62,
            'nextTaskTitle': '다음 과제',
            'badges': <String>[],
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);
    await tester.pump(const Duration(seconds: 6));
    // 헤더도 함께 스크롤되는 문서형 전환(Task 10)으로 화면 최상위 스크롤
    // 컨테이너가 SingleChildScrollView에서 CustomScrollView로 바뀌었다.
    await tester.dragUntilVisible(
      find.textContaining('문단 70'),
      find.byType(CustomScrollView),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, isNotEmpty);
    expect(adapter.postBodies.last, containsPair('dwellSec', 6));
    expect(adapter.count('GET /learning-paths/me'), 1);
    expect(adapter.count('GET /dashboard/me'), 1);
  });

  testWidgets('스크롤 진행률(scrollPct)은 헤더 높이를 보정해 서버로 전송한다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 0.5,
            'dwellSec': 6,
            'completed': false,
            'completedAt': null,
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    // 헤더도 CustomScrollView의 첫 sliver라 컨트롤러가 헤더+본문 전체
    // 스크롤 범위를 관측한다(Task 10) — 보정 없이 pixels/maxScrollExtent를
    // 쓰면 분모에 헤더 높이가 섞여 진행률이 실제보다 낮게 계산된다.
    final headerHeight = tester.getSize(find.byType(DpPageHeader)).height;
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final bodyMax = controller.position.maxScrollExtent - headerHeight;
    // 80문단짜리 긴 마크다운이 900x700 뷰포트보다 충분히 길어야
    // 아래 "본문 50% 지점" 계산이 의미를 갖는다.
    expect(bodyMax, greaterThan(0));

    await tester.pump(const Duration(seconds: 6)); // dwellSec=6(최소 5초 통과)

    // "본문만 스크롤하던 옛 구조" 기준 정확히 50% 지점 = 지금 구조에서는
    // 헤더 높이만큼 밀린 위치(headerHeight + bodyMax*0.5)로 점프한다.
    // jumpTo는 리스너를 동기 호출해 정확히 이 위치 하나로만 flush를 낸다
    // (드래그 제스처의 중간 프레임에 걸쳐 값이 흔들리는 것을 피한다).
    controller.jumpTo(headerHeight + bodyMax * 0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, isNotEmpty);
    final sentScrollPct = (adapter.postBodies.last as Map)['scrollPct'] as num;
    // 보정 없이(옛 코드) 계산하면 이 값은 0.5보다 뚜렷이 커진다(분모에 헤더
    // 높이가 섞여 pixels/maxScrollExtent > 실제 본문 스크롤 비율이 되므로).
    expect(sentScrollPct.toDouble(), closeTo(0.5, 0.001));
  });

  testWidgets('헤더가 스크롤로 트리에서 걷어내진 뒤에도 scrollPct 보정이 유지된다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 서버가 준 기존 진행률 0.2 — 헤더 높이를 못 재 폴백으로 무너지면
    // 이 값이 그대로 돌아오므로, 0.5 단언이 폴백 경로를 확실히 red로 만든다.
    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0.2)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 0.5,
            'dwellSec': 6,
            'completed': false,
            'completedAt': null,
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    final headerHeight = tester.getSize(find.byType(DpPageHeader)).height;
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final bodyMax = controller.position.maxScrollExtent - headerHeight;
    expect(bodyMax, greaterThan(0));

    await tester.pump(const Duration(seconds: 6)); // dwell 최소 조건 통과

    // 1단계: 본문 30% 지점으로 이동 — 헤더(84px)가 뷰포트+캐시 익스텐트 밖으로
    // 나가 sliver가 컬링된다. 실제 사용자가 글을 읽어 내려간 상태와 같다.
    controller.jumpTo(headerHeight + bodyMax * 0.3);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 전제 확인: 헤더가 정말 트리에서 걷어내졌다(이게 아니면 이 테스트는
    // 위 '헤더 높이를 보정해 전송한다' 테스트와 같은 경로만 재검사하게 된다).
    expect(find.byType(DpPageHeader), findsNothing);

    // 2단계: 헤더가 이미 없는 상태에서 더 스크롤한다 — 이 flush의 scrollPct는
    // 전적으로 "헤더가 트리에 없는 상태의 계산"으로 결정된다.
    controller.jumpTo(headerHeight + bodyMax * 0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, isNotEmpty);
    final sentScrollPct = (adapter.postBodies.last as Map)['scrollPct'] as num;
    expect(sentScrollPct.toDouble(), closeTo(0.5, 0.001));
  });

  testWidgets('끝까지 스크롤해도 scrollPct는 여전히 1.0이다(보정 후에도 완료 판정 불변)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 1.0,
            'dwellSec': 6,
            'completed': false,
            'completedAt': null,
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final maxExtent = controller.position.maxScrollExtent;

    await tester.pump(const Duration(seconds: 6));

    controller.jumpTo(maxExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, isNotEmpty);
    final sentScrollPct = (adapter.postBodies.last as Map)['scrollPct'] as num;
    expect(sentScrollPct.toDouble(), 1.0);
  });

  testWidgets('화면을 떠날 때 마지막 flush 이후의 진행분이 유실되지 않는다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 0.5,
            'dwellSec': 6,
            'completed': false,
            'completedAt': null,
          },
        ),
        (
          200,
          {
            'scrollPct': 0.55,
            'dwellSec': 8,
            'completed': false,
            'completedAt': null,
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    final headerHeight = tester.getSize(find.byType(DpPageHeader)).height;
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final bodyMax = controller.position.maxScrollExtent - headerHeight;
    expect(bodyMax, greaterThan(0));

    await tester.pump(const Duration(seconds: 6));

    // 1) 50%까지 스크롤 — 임계(0.1)를 넘어 flush가 나간다.
    controller.jumpTo(headerHeight + bodyMax * 0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.postBodies, hasLength(1));

    // 2) 55%까지 더 스크롤 — 증분 0.05는 임계 미달이라 **아직 전송되지 않는다.**
    //    이 5%가 화면을 떠날 때 살아남아야 하는 진행분이다.
    controller.jumpTo(headerHeight + bodyMax * 0.55);
    await tester.pump();
    await tester.pump(
      const Duration(seconds: 2),
    ); // dwellSec를 벌려 dispose flush를 유발
    expect(adapter.postBodies, hasLength(1), reason: '임계 미달이라 아직 전송되면 안 된다');

    // 3) 화면을 떠난다 — dispose flush가 남은 진행분을 보내야 한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, hasLength(2), reason: 'dispose에서 한 번 더 보내야 한다');
    final sent = (adapter.postBodies.last as Map)['scrollPct'] as num;
    // 버그(수정 전): dispose 시 hasClients=false라 _scrollPct가 폴백(서버 최종값
    // 0.5)을 돌려주고, 그 값이 tracker의 최신 진행률(0.55)을 **덮어써** 0.5가 나갔다.
    // 정기 flush 임계가 0.1이므로 매번 최대 10%가 이렇게 유실될 수 있고,
    // 완료 임계(0.8) 근처에서는 완료 처리가 지연된다.
    expect(sent.toDouble(), closeTo(0.55, 0.01));
  });

  testWidgets('retry button reloads', (tester) async {
    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (
          500,
          {
            'error': {'code': 'INTERNAL_ERROR', 'message': '일시 오류'},
          },
        ),
        (200, _contentJson(markdown: '# 재시도 성공')),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await _pumpLoad(tester);

    expect(find.text('Future/async-await 정리'), findsOneWidget);
    expect(find.textContaining('재시도 성공'), findsWidgets);
  });
}

Widget _host(_SequenceAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ContentPage(contentId: 'future-async-await'),
      ),
      GoRoute(path: '/sandbox', builder: (_, _) => const Text('sandbox route')),
    ],
  );

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      // 광고 위젯은 이 테스트 범위 밖 — 네트워크 미실행(fail-silent null).
      adFetchProvider.overrideWithValue((slot) async => null),
    ],
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

Future<void> _pumpLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Map<String, dynamic> _contentJson({
  required String markdown,
  double scrollPct = 0.2,
}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': markdown,
  'estimatedMinutes': 8,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': ['future', 'async-await'],
  'progress': {
    'scrollPct': scrollPct,
    'dwellSec': 0,
    'completed': false,
    'completedAt': null,
  },
};

String _longMarkdown() => [
  '# 비동기 기초',
  for (var i = 0; i < 80; i++) '문단 $i: Future와 async/await 흐름을 충분히 길게 설명합니다.',
].join('\n\n');

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.fixtures);

  final Map<String, List<(int, Object)>> fixtures;
  final List<Object?> postBodies = [];
  final Map<String, int> _counts = {};

  int count(String key) => _counts[key] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    _counts[key] = count(key) + 1;
    if (options.method == 'POST') postBodies.add(options.data);

    final sequence = fixtures[key];
    if (sequence == null || sequence.isEmpty) {
      return _json(404, {
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no mock: $key'},
      });
    }
    final fixture = sequence.length == 1
        ? sequence.first
        : sequence.removeAt(0);
    final (status, body) = fixture;
    return _json(status, body);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
