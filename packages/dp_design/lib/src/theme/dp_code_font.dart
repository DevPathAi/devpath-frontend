import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dp_typography.dart';

/// D2Coding 지연 로더.
///
/// D2Coding 은 FontManifest 에서 빠져 있어(시작 시 2 MB 절감) 코드 스타일이
/// 처음 그려질 때 한 번만 [FontLoader] 로 등록한다. 등록 전에는 fallback
/// 폰트로 그려지고, 로드가 끝나면 Flutter 가 텍스트를 다시 배치한다.
abstract final class DpCodeFont {
  static const String assetPath = 'packages/dp_design/fonts/D2Coding.ttf';
  static Future<void>? _loading;
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// 멱등. 같은 Future 를 돌려주며, 실패하면 캐시를 비워 다음 호출이 다시 시도한다.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final loader = FontLoader(DpTypography.codeFamily)
        ..addFont(rootBundle.load(assetPath));
      await loader.load();
      _loaded = true;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _loading = null;
    _loaded = false;
  }
}
