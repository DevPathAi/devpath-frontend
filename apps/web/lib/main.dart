import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/analytics/journey_handoff.dart';

void main() {
  captureJourneyHandoffFromVisibleUrl();
  runApp(const ProviderScope(child: DevPathWebApp()));
}
