import 'package:flutter/material.dart';

import '../theme/dp_theme.dart';
import 'et13_font_asset_ready.dart';
import 'et13_font_ready_stub.dart'
    if (dart.library.js_interop) 'et13_font_ready_web.dart'
    as font_ready;

typedef Et13ReadyWaiter = Future<void> Function();

Future<void> waitForEt13EvidenceFonts() async {
  await loadEt13EvidenceAssetFonts();
  await font_ready.waitForEt13Fonts();
}

/// Strict launch parameters shared by the three ET13 Flutter Web release
/// targets. Capture controls the viewport; the renderer owns every other
/// deterministic input.
final class DpEt13EvidenceLaunchConfig {
  DpEt13EvidenceLaunchConfig({
    required this.fixtureId,
    required this.brightness,
    required this.textScale,
    required this.sourceSha,
  }) {
    if (!_isValidSha(sourceSha)) {
      throw ArgumentError.value(sourceSha, 'sourceSha', 'must be a git SHA-1');
    }
  }

  factory DpEt13EvidenceLaunchConfig.fromUri({
    required Uri uri,
    required Iterable<String> allowedFixtureIds,
    required String sourceSha,
  }) {
    const allowedKeys = {'fixture', 'theme', 'textScalePercent'};
    final unexpected = uri.queryParameters.keys
        .where((key) => !allowedKeys.contains(key))
        .toList(growable: false);
    if (unexpected.isNotEmpty) {
      throw ArgumentError.value(
        unexpected,
        'uri',
        'unexpected ET13 query parameters',
      );
    }

    final fixtureId = uri.queryParameters['fixture'];
    if (fixtureId == null || !allowedFixtureIds.contains(fixtureId)) {
      throw ArgumentError.value(
        fixtureId,
        'fixture',
        'unknown or missing ET13 fixture',
      );
    }
    final brightness = switch (uri.queryParameters['theme'] ?? 'light') {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      final value => throw ArgumentError.value(
        value,
        'theme',
        'must be light or dark',
      ),
    };
    final textScale = switch (uri.queryParameters['textScalePercent'] ??
        '100') {
      '100' => 1.0,
      '200' => 2.0,
      final value => throw ArgumentError.value(
        value,
        'textScalePercent',
        'must be 100 or 200',
      ),
    };
    return DpEt13EvidenceLaunchConfig(
      fixtureId: fixtureId,
      brightness: brightness,
      textScale: textScale,
      sourceSha: sourceSha,
    );
  }

  static final _shaPattern = RegExp(r'^[0-9a-f]{40}$');
  static bool _isValidSha(String value) =>
      _shaPattern.hasMatch(value) &&
      value != '0000000000000000000000000000000000000000';

  final String fixtureId;
  final Brightness brightness;
  final double textScale;
  final String sourceSha;
}

/// Deterministic production-distribution frame used only by the approved ET13
/// release targets.
///
/// The ready marker is withheld until packaged fonts, the surface-specific
/// provider/widget boundary, and two complete Flutter frames have settled.
/// Browser capture must wait for the exact semantics label rather than sleep.
class DpEt13EvidenceFrame extends StatefulWidget {
  const DpEt13EvidenceFrame({
    super.key,
    required this.fixtureId,
    required this.brightness,
    required this.textScale,
    required this.sourceSha,
    required this.child,
    this.waitForFonts = waitForEt13EvidenceFonts,
    this.waitForSurface,
  });

  final String fixtureId;
  final Brightness brightness;
  final double textScale;
  final String sourceSha;
  final Widget child;
  final Et13ReadyWaiter waitForFonts;
  final Et13ReadyWaiter? waitForSurface;

  @override
  State<DpEt13EvidenceFrame> createState() => _DpEt13EvidenceFrameState();
}

class _DpEt13EvidenceFrameState extends State<DpEt13EvidenceFrame> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!DpEt13EvidenceLaunchConfig._isValidSha(widget.sourceSha)) {
      throw ArgumentError.value(
        widget.sourceSha,
        'sourceSha',
        'must be a git SHA-1',
      );
    }
    _settle();
  }

  Future<void> _settle() async {
    await WidgetsBinding.instance.endOfFrame;
    await widget.waitForFonts();
    await widget.waitForSurface?.call();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko', 'KR'),
    theme: widget.brightness == Brightness.light
        ? DpTheme.light()
        : DpTheme.dark(),
    home: Builder(
      builder: (context) {
        final media = MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(widget.textScale),
          disableAnimations: true,
          accessibleNavigation: true,
        );
        final runtimeProfile =
            'ET13_RUNTIME_PROFILE:fixture=${widget.fixtureId}'
            ';width=${media.size.width.round()}'
            ';height=${media.size.height.round()}'
            ';dpr=${media.devicePixelRatio.toStringAsFixed(0)}'
            ';brightness=${widget.brightness.name}'
            ';textScalePercent=${(widget.textScale * 100).round()}';
        return MediaQuery(
          data: media,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'ET13_CAPTURE_SURFACE:flutter_web_release_projection',
                child: widget.child,
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'ET13_SOURCE_SHA:${widget.sourceSha}',
                  child: const SizedBox.square(dimension: 1),
                ),
              ),
              Positioned(
                left: 1,
                top: 0,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: runtimeProfile,
                  child: const SizedBox.square(dimension: 1),
                ),
              ),
              if (_ready)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: 'ET13_READY:${widget.fixtureId}',
                    child: const SizedBox.square(dimension: 1),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
