import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 브랜드는 `Leva` 다. 홈페이지(leva.ai.kr)는 전면 교체됐는데 앱에는 옛 브랜드가
/// 남아 사용자 화면에 `DevPath` 가 그대로 보였다(2026-08-11 캡처에서 발견).
///
/// ★첫 판에서 `lib` 만 검사해 `web/` 디렉터리를 통째로 놓쳤다.★ manifest.json 의
/// 앱 이름이 `devpath_web` 이라 홈 화면에 추가하면 그 이름으로 뜨고,
/// apple-mobile-web-app-title 도 마찬가지였다(외부 리뷰에서 지적). 검사 범위를
/// 넓히지 않으면 가드가 「통과했다」는 사실만 주고 아무것도 지키지 못한다.
void main() {
  final dartDirs = [
    Directory('lib'),
    Directory('../admin/lib'),
    Directory('../mobile/lib'),
    Directory('../../packages/dp_design/lib'),
    Directory('../../packages/dp_core/lib'),
  ].where((d) => d.existsSync());

  // 클래스명·패키지명(`DevPathAdminApp`·`devpath_web`)은 코드 식별자라 대상이
  // 아니다. **따옴표 안에 든 문자열**, 즉 화면에 나갈 수 있는 것만 본다.
  final dartLiteral = RegExp(r'''['"][^'"]*DevPath[^'"]*['"]''');

  test('Dart 소스의 사용자 노출 문자열에 옛 브랜드가 없다', () {
    final offenders = <String>[];

    for (final dir in dartDirs) {
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (dartLiteral.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // web/ 아래는 브라우저와 OS가 직접 읽는다. manifest 의 name 은 홈 화면에
  // 추가했을 때의 앱 이름이고, index.html 의 메타는 링크 미리보기에 쓰인다.
  // 여기는 코드 식별자가 아니라 전부 사용자에게 보이는 값이므로 대소문자를
  // 가리지 않고 옛 브랜드와 Flutter 기본 문구를 모두 막는다.
  final webFiles = [
    File('web/manifest.json'),
    File('web/index.html'),
    File('../admin/web/manifest.json'),
    File('../admin/web/index.html'),
    File('../mobile/web/manifest.json'),
    File('../mobile/web/index.html'),
  ].where((f) => f.existsSync());

  final webForbidden = RegExp(
    'devpath|A new Flutter project',
    caseSensitive: false,
  );

  test('web 자산에 옛 브랜드와 Flutter 기본 문구가 없다', () {
    final offenders = <String>[];

    for (final file in webFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // 외부 스크립트 URL과 JS 함수명(createDevpathEditor 등)은 코드
        // 식별자다. 사용자에게 보이지 않으므로 대상이 아니다.
        if (lines[i].contains('googlesyndication') ||
            lines[i].contains('cdnjs.cloudflare.com') ||
            lines[i].contains('createDevpath')) {
          continue;
        }
        if (webForbidden.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
