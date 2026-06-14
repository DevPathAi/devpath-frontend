@Tags(['golden'])
library;

import 'dart:io';

import 'package:dp_design/src/states/dp_kill_switch.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _frame(ThemeData theme) => MaterialApp(
  theme: theme,
  debugShowCheckedModeBanner: false,
  home: const Scaffold(body: DpKillSwitch()),
);

Future<void> _loadFonts() async {
  // P3-D: 위젯테스트는 번들 폰트를 자동 로드하지 않으므로 명시 로드.
  // 실제 배치 파일은 Pretendard=.otf, D2Coding=.ttf.
  for (final entry in {
    'Pretendard': 'fonts/Pretendard-Regular.otf',
    'D2Coding': 'fonts/D2Coding.ttf',
  }.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue; // 미배치 시 fallback로 baseline
    final loader = FontLoader(entry.key)
      ..addFont(
        Future.value(file.readAsBytes().then((b) => b.buffer.asByteData())),
      );
    await loader.load();
  }
  // Material Symbols(Rounded) 번들 폰트 — 미로드 시 아이콘이 box로 degrade.
  // Symbols.*_rounded는 family 'packages/material_symbols_icons/MaterialSymbolsRounded' 사용.
  try {
    final loader =
        FontLoader(
          'packages/material_symbols_icons/MaterialSymbolsRounded',
        )..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
          ),
        );
    await loader.load();
  } catch (_) {
    // 번들 에셋 미존재 시 fallback(box)로 baseline 생성.
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('DpKillSwitch 라이트 골든', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    await tester.pumpWidget(_frame(DpTheme.light()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/kill_switch_light.png'),
    );
  });

  testWidgets('DpKillSwitch 다크 골든', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    await tester.pumpWidget(_frame(DpTheme.dark()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/kill_switch_dark.png'),
    );
  });
}
