import 'dart:async';

import 'package:devpath_mobile/src/features/notifications/application/notification_controller.dart';
import 'package:devpath_mobile/src/features/notifications/presentation/notifications_page.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePush implements PushService {
  _FakePush(this._controller);

  final StreamController<PushMessage> _controller;

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Stream<PushMessage> get incoming => _controller.stream;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const NotificationsPage()),
);

({ProviderContainer container, StreamController<PushMessage> push}) _setup() {
  final ctrl = StreamController<PushMessage>();
  addTearDown(ctrl.close);
  final c = ProviderContainer(
    overrides: [pushServiceProvider.overrideWithValue(_FakePush(ctrl))],
  );
  addTearDown(c.dispose);
  return (container: c, push: ctrl);
}

/// 컨트롤러를 활성화하고 수신을 real-async로 흘려 상태에 반영한다.
/// testWidgets의 fake-async zone에서는 스트림 이벤트가 진행되지 않으므로
/// [WidgetTester.runAsync] 안에서 처리한다.
Future<void> _emit(
  WidgetTester tester,
  ProviderContainer c,
  StreamController<PushMessage> push,
  List<PushMessage> messages,
) async {
  await tester.runAsync(() async {
    c.read(notificationControllerProvider); // build() → incoming 구독 시작
    for (final m in messages) {
      push.add(m);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}

void main() {
  testWidgets('수신 없음 → 빈 상태', (tester) async {
    final (:container, :push) = _setup();

    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    expect(find.byType(DpEmpty), findsOneWidget);
    expect(find.text('알림이 없어요'), findsOneWidget);
  });

  testWidgets('수신 메시지 → 목록에 제목·본문 표시', (tester) async {
    final (:container, :push) = _setup();
    await _emit(tester, container, push, const [
      PushMessage(id: '1', title: '새 멘토 답변', body: '리뷰가 도착했어요'),
    ]);

    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    expect(find.byType(DpEmpty), findsNothing);
    expect(find.text('새 멘토 답변'), findsOneWidget);
    expect(find.text('리뷰가 도착했어요'), findsOneWidget);
  });

  testWidgets('진입 시 미읽음을 읽음 처리(markAllRead) + 목록 유지', (tester) async {
    final (:container, :push) = _setup();
    await _emit(tester, container, push, const [
      PushMessage(id: '1', title: 'A', body: 'a'),
    ]);
    expect(container.read(notificationControllerProvider).unreadCount, 1);

    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    expect(container.read(notificationControllerProvider).unreadCount, 0);
    expect(find.text('A'), findsOneWidget);
  });
}
