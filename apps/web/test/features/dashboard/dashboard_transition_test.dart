import 'dart:async';

import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// load()가 영원히 완료되지 않는 fake — DashLoading 상태를 결정적으로 고정한다.
class _NeverApiClient implements ApiClient {
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      Completer<T>().future; // never completes

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

GoRouter _router() => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())],
);

void main() {
  testWidgets('대시보드 로딩: Skeletonizer + AnimatedSwitcher 존재', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_NeverApiClient())],
        child: MaterialApp.router(
          theme: DpTheme.light(),
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pump(); // load() 시작(완료 안 됨) → DashLoading 유지

    expect(find.byKey(const ValueKey('dash-switcher')), findsOneWidget);
    // 로딩 골격 = Skeletonizer(key: 'loading'). skeletonizer 2.x는 public
    // Skeletonizer를 내부 _Skeletonizer로 렌더해 byType 매칭 불가 → key로 특정.
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);
  });

  testWidgets('대시보드 로드 완료: DashboardBody(CTA)로 전환', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: DpTheme.light(),
          routerConfig: _router(),
        ),
      ),
    ); // 기본 mock 클라이언트
    await tester.pumpAndSettle(); // load() 완료 → DashLoaded

    expect(find.byKey(const ValueKey('loading')), findsNothing); // 스켈레톤 사라짐
    expect(find.byKey(const ValueKey('loaded')), findsOneWidget);
    expect(find.text('이어서 학습'), findsOneWidget);
  });
}
