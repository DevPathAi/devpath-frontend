import 'dart:typed_data';

import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/community/presentation/post_detail_page.dart';
import 'package:devpath_web/src/features/community/presentation/post_edit_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 골든패스(상세→수정→저장→상세 복귀→삭제→목록)를 **실제 화면·프로바이더·라우팅**으로
/// 구동한다. 이전 형태는 pumpWidget 0건 — CRUD 프로바이더를 페이크로 갈아끼운 채 페이크의
/// 상태기계만 검증했고, 위젯 콜백을 전부 지워도 통과했다.
///
/// 생성 화면은 post_create_page_test 가 이미 덮으므로 중복하지 않는다(스펙 §3 범위).
class _MineAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '7',
      email: 'me@example.com',
      nickname: '나',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

/// 실제로 나간 요청(순서·본문)을 기록한다 — 라우팅이 옳아도 요청이 안 나가면 잡는다.
class _CapturingAdapter extends MockHttpAdapter {
  _CapturingAdapter(super.fixtures, {super.sequences});
  final List<String> calls = [];
  final Map<String, Object?> bodies = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies[key] = options.data;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Map<String, dynamic> _detailJson(String title, String bodyMd) => {
  'id': 9,
  'boardType': 'FREE',
  'title': title,
  'bodyMd': bodyMd,
  'authorId': 7,
  'upvoteCount': 0,
  'downvoteCount': 0,
  'tags': <dynamic>[],
  'comments': <dynamic>[],
};

void main() {
  testWidgets('골든패스: 상세 → 수정 진입 → 저장(PUT) → 상세 복귀 → 삭제(DELETE) → 목록', (
    tester,
  ) async {
    final adapter = _CapturingAdapter(
      {
        'PUT /community/posts/9': (200, _detailJson('새제목', '원본문')),
        'DELETE /community/posts/9': (204, <String, dynamic>{}),
      },
      sequences: {
        'GET /community/posts/9': [
          (200, _detailJson('원제목', '원본문')), // ① 상세 최초 로드
          (200, _detailJson('원제목', '원본문')), // ② 편집 화면의 초기값 로드
          (200, _detailJson('새제목', '원본문')), // ③ 저장 후 상세 복귀 재조회
        ],
      },
    );
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
    client.dio.httpClientAdapter = adapter;
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authControllerProvider.overrideWith(_MineAuthController.new),
      ],
    );
    addTearDown(c.dispose);

    final router = GoRouter(
      initialLocation: '/community/post/9',
      routes: [
        GoRoute(
          path: '/community',
          builder: (_, _) => const Scaffold(body: Text('커뮤니티 목록 스텁')),
        ),
        GoRoute(
          path: '/community/post/:id',
          builder: (_, state) =>
              PostDetailPage(postId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/community/post/:id/edit',
          builder: (_, state) =>
              PostEditPage(postId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: DpTheme.light(),
          localizationsDelegates: const [
            DefaultCupertinoLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('원제목'), findsOneWidget, reason: '상세가 실제 GET 으로 렌더된다');

    // 수정 진입 — 실제 메뉴와 라우팅을 거친다.
    await tester.tap(find.byKey(const ValueKey('content-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('post-submit')), findsOneWidget,
        reason: '편집 화면(작성 화면의 편집 모드)에 도착했다');
    expect(find.byKey(const ValueKey('post-tags-field')), findsNothing,
        reason: '편집 모드는 태그를 감춘다');

    // 저장 — 실제 PUT 이 나가고 본문이 실려 있다.
    await tester.tap(find.byKey(const ValueKey('post-submit')));
    await tester.pumpAndSettle();
    final put = adapter.bodies['PUT /community/posts/9']! as Map;
    expect(put['title'], '원제목');
    expect(put['bodyMd'], contains('원본문'),
        reason: 'Quill 역·정변환을 거친 본문이 실려 나간다');
    expect(find.text('새제목'), findsOneWidget,
        reason: '상세로 복귀해 저장 후 상태(재조회)를 그린다');

    // 삭제 — 실제 확인 다이얼로그와 DELETE, 목록 라우팅.
    await tester.tap(find.byKey(const ValueKey('content-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('content-delete-confirm')));
    await tester.pumpAndSettle();

    expect(adapter.calls, contains('DELETE /community/posts/9'),
        reason: '삭제 요청이 실제로 나갔다');
    expect(find.text('커뮤니티 목록 스텁'), findsOneWidget,
        reason: '삭제 성공 시 목록으로 이동한다');
  });
}
