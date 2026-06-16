import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'router.dart';

class DevPathAdminApp extends ConsumerWidget {
  const DevPathAdminApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DevPath 운영 콘솔',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(adminRouterProvider),
    );
  }
}
