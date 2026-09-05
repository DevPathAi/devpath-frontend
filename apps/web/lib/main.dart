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
  // 초대 코드가 analytics나 브라우저 주소 기록에 닿기 전에 sessionStorage로 옮긴다.
  captureMentorInviteHandoffFromVisibleUrl();
  captureJourneyHandoffFromVisibleUrl();
  runApp(const ProviderScope(child: DevPathWebApp()));
}
