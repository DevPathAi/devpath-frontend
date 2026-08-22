import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Waits for the browser to resolve every packaged font requested by Flutter.
/// No fallback timeout is allowed: a missing font keeps capture unready.
Future<void> waitForEt13Fonts() async {
  final document = globalContext['document'] as JSObject?;
  final fonts = document?['fonts'] as JSObject?;
  final ready = fonts?['ready'] as JSPromise<JSAny?>?;
  if (ready == null) {
    throw StateError('document.fonts.ready is unavailable');
  }
  await ready.toDart;
}
