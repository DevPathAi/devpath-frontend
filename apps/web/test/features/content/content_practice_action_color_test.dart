import 'dart:convert';
import 'dart:typed_data';

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

/// Step 3c: 헤더로 이관된 「실습」 버튼의 실효 색을 단언한다. 세 토큰
/// (accentSoft/accentLine/primaryText)이 서로 다른 값이므로, 배선을 서로
/// 뒤바꾸면 이 테스트가 반드시 실패한다.
void main() {
  testWidgets(
    'content-practice-action 버튼은 accentSoft 배경·accentLine 보더·primaryText 전경',
    (tester) async {
      final adapter = _StubAdapter();
      final client = ApiClient.create(
        const ApiConfig(baseUrl: 'https://t/api/v1'),
      );
      client.dio.httpClientAdapter = adapter;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const ContentPage(contentId: 'c1'),
          ),
          GoRoute(
            path: '/sandbox',
            builder: (_, _) => const Text('sandbox route'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            adFetchProvider.overrideWithValue((slot) async => null),
          ],
          child: MaterialApp.router(
            theme: DpTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<TextButton>(
        find.byKey(const ValueKey('content-practice-action')),
      );
      final colors = DpColors.light;
      const states = <WidgetState>{};

      // 세 토큰이 서로 다른 값인지 먼저 확인 — 이게 성립해야 아래 단언이
      // "뒤바꾸면 반드시 실패"를 실제로 보장한다.
      expect(colors.accentSoft, isNot(equals(colors.accentLine)));
      expect(colors.accentSoft, isNot(equals(colors.primaryText)));
      expect(colors.accentLine, isNot(equals(colors.primaryText)));

      expect(button.style?.backgroundColor?.resolve(states), colors.accentSoft);
      expect(
        button.style?.foregroundColor?.resolve(states),
        colors.primaryText,
      );
      expect(button.style?.side?.resolve(states)?.color, colors.accentLine);
    },
  );
}

Map<String, dynamic> _contentJson() => {
  'id': 1,
  'slug': 'c1',
  'title': '콘텐츠 제목',
  'track': 'BACKEND',
  'markdown': '# 본문',
  'estimatedMinutes': 5,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': 0.0,
    'dwellSec': 0,
    'completed': false,
    'completedAt': null,
  },
};

class _StubAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_contentJson()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
