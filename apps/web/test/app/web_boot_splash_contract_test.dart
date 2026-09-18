import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 운영 실측(2026-09-17): 부팅 중 표시가 없어 데이터센터 회선으로도 1초 시점이 흰 화면이다.
/// index.html 이 CSS 만으로 스플래시를 그리고, Flutter 첫 프레임 이벤트에서 치운다.
void main() {
  test('web index paints a boot splash until the first Flutter frame', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('id="leva-boot"'));
    expect(index, contains('role="status"'));
    expect(index, contains("addEventListener('flutter-first-frame'"));
    expect(index, contains('leva-boot__mark'));
    // 스플래시는 Flutter host 아래에 깔리고, 첫 프레임 뒤 DOM 에서 제거된다.
    expect(index, contains('z-index: 0'));
    expect(index, contains('splash.remove()'));
    // ET13 fixture 라우트(외부 요청 금지)에도 영향이 없어야 한다: 외부 URL 없이 인라인.
    final splashBlock = index.substring(
      index.indexOf('id="leva-boot"'),
      index.indexOf('splash.remove()'),
    );
    expect(splashBlock, isNot(contains('http')));
  });
}
