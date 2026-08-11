import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('폭 경계가 DESIGN.md §5와 일치', () {
    expect(dpWindowClassOf(599), DpWindowClass.compact);
    expect(dpWindowClassOf(600), DpWindowClass.medium);
    expect(dpWindowClassOf(839), DpWindowClass.medium);
    expect(dpWindowClassOf(840), DpWindowClass.expanded);
    expect(dpWindowClassOf(1239), DpWindowClass.expanded);
    expect(dpWindowClassOf(1240), DpWindowClass.large);
  });
}
