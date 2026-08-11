import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('section·badgeCount는 생략 가능하고 기본값을 갖는다', () {
    const d = DpDestination(icon: Icons.dashboard, label: '대시보드');
    expect(d.section, isNull);
    expect(d.badgeCount, 0);
  });

  test('section을 주면 그룹 레이블로 보존된다', () {
    const d = DpDestination(
      icon: Icons.map,
      label: '학습 경로',
      section: '학습',
      badgeCount: 3,
    );
    expect(d.section, '학습');
    expect(d.badgeCount, 3);
  });
}
