import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 브랜드는 `Leva` 다. 홈페이지(leva.ai.kr)는 전면 교체됐는데 앱에는 옛 브랜드가
/// 남아 사용자 화면에 `DevPath` 가 그대로 보였다(2026-08-11 캡처에서 발견).
///
/// 클래스명·패키지명(`DevPathAdminApp`·`devpath_web`)은 코드 식별자라 대상이
/// 아니다. **따옴표 안에 든 문자열**, 즉 화면에 나갈 수 있는 것만 본다.
void main() {
  final libDirs = [
    Directory('lib'),
    Directory('../admin/lib'),
    Directory('../mobile/lib'),
    Directory('../../packages/dp_design/lib'),
    Directory('../../packages/dp_core/lib'),
  ].where((d) => d.existsSync());

  // 따옴표로 둘러싸인 리터럴 안의 DevPath 만 잡는다.
  final literal = RegExp(r'''['"][^'"]*DevPath[^'"]*['"]''');

  test('사용자에게 보이는 문자열에 옛 브랜드가 남아 있지 않다', () {
    final offenders = <String>[];

    for (final dir in libDirs) {
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
