import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'router.dart';

/// web 앱 루트: 라우터 + 전역 테마(라이트/다크 토글, DD6).
class DevPathWebApp extends ConsumerWidget {
  const DevPathWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DevPath AI',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
