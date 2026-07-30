import 'package:dp_design/dp_design.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모션 토큰이 로드맵 §4.3 수치와 일치', () {
    expect(DpDurations.hover, const Duration(milliseconds: 120));
    expect(DpDurations.select, const Duration(milliseconds: 180));
    expect(DpDurations.panelExpand, const Duration(milliseconds: 220));
  });

  test('명령 팔레트·셸 토글 아이콘이 정의됨', () {
    // 컴파일되면 상수 존재. IconData 동일성으로 오탈자 방지.
    expect(DpIcons.search, isA<IconData>());
    expect(DpIcons.menu, isA<IconData>());
    expect(DpIcons.menuOpen, isA<IconData>());
    expect(DpIcons.moreVert, isA<IconData>());
    expect(DpIcons.star, isA<IconData>());
  });
}
