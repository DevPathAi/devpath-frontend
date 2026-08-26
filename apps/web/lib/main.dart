import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'src/app/app.dart';
import 'src/analytics/journey_handoff.dart';

void main() {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  captureJourneyHandoffFromVisibleUrl();
  runApp(const ProviderScope(child: DevPathWebApp()));
}
