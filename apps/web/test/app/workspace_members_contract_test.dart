import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 모바일 앱은 DevPathAi/devpath-mobile 레포가 소유한다(2026-09-19 분리).
/// 이 레포의 workspace 에 모바일이 다시 들어오면 단일 lock 해석과 ET13 증거의
/// `_workspaceLockSha` 가 함께 흔들린다 — 멤버 목록을 계약으로 고정한다.
void main() {
  test('workspace members are exactly the web-side packages', () {
    final pubspec = File(
      '../../pubspec.yaml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final start = pubspec.indexOf('\nworkspace:\n');
    expect(start, greaterThanOrEqualTo(0));
    final members = pubspec
        .substring(start + '\nworkspace:\n'.length)
        .split('\n')
        .takeWhile((line) => line.startsWith('  - '))
        .map((line) => line.substring(4).trim())
        .toList();
    expect(members, [
      'packages/dp_core',
      'packages/dp_design',
      'apps/web',
      'apps/admin',
    ]);
  });

  test('the mobile app, its CI, and its source guard live elsewhere', () {
    expect(Directory('../mobile').existsSync(), isFalse);
    expect(File('../../.github/workflows/mobile.yml').existsSync(), isFalse);
    expect(File('../../tools/mobile_source_guard.dart').existsSync(), isFalse);
    final ignore = File(
      '../../.gitignore',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    expect(ignore, isNot(contains('apps/mobile')));
  });

  test('contributor guides no longer route work into apps/mobile', () {
    for (final name in [
      'CLAUDE.md',
      'AGENTS.md',
      'CODEX.md',
      'README.md',
      'melos_README.md',
    ]) {
      final guide = File('../../$name').readAsStringSync();
      expect(guide, isNot(contains('cd apps/mobile')), reason: name);
      expect(guide, isNot(contains('apps/{web,admin,mobile}')), reason: name);
    }
  });
}
