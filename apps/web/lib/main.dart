import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'src/app/app.dart';
import 'src/analytics/journey_handoff.dart';
import 'src/features/mentor/application/mentor_invite_handoff.dart';

void main() {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  // index.html이 외부 스크립트보다 먼저 처리한다. 이 호출은 비-web 실행과
  // 조기 bootstrap을 우회한 환경에서도 같은 정리 계약을 지키는 fallback이다.
  captureMentorInviteHandoffFromVisibleUrl();
  captureJourneyHandoffFromVisibleUrl();
  runApp(const ProviderScope(child: DevPathWebApp()));
}
