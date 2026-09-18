// design-sync 입력: DpSemanticTokenManifest 의 CSS 투영(light/dark)에 레이아웃 폭·브레이크포인트를
// 더해 파일로 덤프한다. 값은 전부 코드 상수에서 읽고, 브레이크포인트는 dpWindowClassOf 로 검증한다.
import 'dart:io';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dump css projection for design-sync', () {
    final light = DpSemanticTokenManifest.cssCustomProperties(Brightness.light);
    final dark = DpSemanticTokenManifest.cssCustomProperties(Brightness.dark);

    // 브레이크포인트 SSoT 는 dpWindowClassOf 의 경계다 — 값을 옮겨 적기 전에 코드로 확인한다.
    const breakpoints = {'medium': 600.0, 'expanded': 840.0, 'large': 1240.0};
    expect(dpWindowClassOf(breakpoints['medium']! - 1), DpWindowClass.compact);
    expect(dpWindowClassOf(breakpoints['medium']!), DpWindowClass.medium);
    expect(dpWindowClassOf(breakpoints['expanded']!), DpWindowClass.expanded);
    expect(dpWindowClassOf(breakpoints['large']!), DpWindowClass.large);

    final layout = {
      '--dp-layout-content-max':
          '${AppTokens.standard.contentMaxWidth.toInt()}px',
      '--dp-layout-readable-max':
          '${AppTokens.standard.readableMaxWidth.toInt()}px',
      '--dp-layout-rail': '${AppTokens.standard.railWidth.toInt()}px',
      '--dp-layout-rail-collapsed':
          '${AppTokens.standard.railCollapsedWidth.toInt()}px',
      for (final entry in breakpoints.entries)
        '--dp-breakpoint-${entry.key}': '${entry.value.toInt()}px',
    };

    final buffer = StringBuffer()
      ..writeln(
        '/* Leva semantic design tokens — generated from DpSemanticTokenManifest '
        '${DpSemanticTokenManifest.version} (packages/dp_design), AppTokens.standard and '
        'dpWindowClassOf. Do not edit by hand. */',
      )
      ..writeln(':root {');
    light.forEach((k, v) => buffer.writeln('  $k: $v;'));
    layout.forEach((k, v) => buffer.writeln('  $k: $v;'));
    buffer
      ..writeln('}')
      ..writeln()
      ..writeln('[data-theme="dark"], .dp-theme-dark {');
    dark.forEach((k, v) => buffer.writeln('  $k: $v;'));
    buffer.writeln('}');
    expect(light['--dp-color-primary'], isNotEmpty);
    // 파일 쓰기는 design-sync 가 DP_TOKEN_DUMP 를 줄 때만 한다(일반 CI 실행은 검증만).
    final dumpPath = Platform.environment['DP_TOKEN_DUMP'];
    if (dumpPath == null) return;
    final out = File(dumpPath);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(buffer.toString());
  });
}
