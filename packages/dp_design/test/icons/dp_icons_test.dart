import 'package:dp_design/src/icons/dp_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('탭/상태 아이콘이 IconData로 노출된다(이모지 제거)', () {
    expect(DpIcons.home, isA<IconData>());
    expect(DpIcons.path, isA<IconData>());
    expect(DpIcons.mentor, isA<IconData>());
    expect(DpIcons.community, isA<IconData>());
    expect(DpIcons.notifications, isA<IconData>());
    expect(DpIcons.killSwitch, isA<IconData>());
  });

  test('테마 토글 아이콘이 IconData로 노출된다', () {
    expect(DpIcons.lightMode, isA<IconData>());
    expect(DpIcons.darkMode, isA<IconData>());
  });
}
