import 'package:flutter/services.dart';

Future<void>? _fontLoad;

/// Explicitly parses every exact ET13 production font through Flutter's
/// renderer before browser capture can publish its READY marker.
///
/// The producer separately verifies these packaged bytes against
/// `evidence/et13/assets.lock.json`; this loader closes the engine fallback
/// gap that `document.fonts.ready` cannot observe for CanvasKit/Skwasm fonts.
Future<void> loadEt13EvidenceAssetFonts() => _fontLoad ??= _load();

Future<void> _load() async {
  final families = <String, List<String>>{
    'packages/dp_design/Pretendard': [
      'packages/dp_design/fonts/Pretendard-Regular.otf',
      'packages/dp_design/fonts/Pretendard-Medium.otf',
      'packages/dp_design/fonts/Pretendard-SemiBold.otf',
      'packages/dp_design/fonts/Pretendard-Bold.otf',
    ],
    'packages/dp_design/D2Coding': ['packages/dp_design/fonts/D2Coding.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    'packages/material_symbols_icons/MaterialSymbolsRounded': [
      'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}
