import 'package:dp_core/src/api/page.dart';
import 'package:test/test.dart';

void main() {
  test('커서 응답을 파싱하고 hasMore를 계산한다', () {
    final json = {
      'data': [
        {'id': 'a'},
        {'id': 'b'},
      ],
      'nextCursor': 'c2',
      'limit': 20,
    };
    final page = Page.fromJson(json, (o) => (o as Map)['id'] as String);
    expect(page.data, ['a', 'b']);
    expect(page.nextCursor, 'c2');
    expect(page.limit, 20);
    expect(page.hasMore, isTrue);
  });

  test('nextCursor 없으면 hasMore=false, limit 기본 20', () {
    final page = Page.fromJson({'data': []}, (o) => o);
    expect(page.hasMore, isFalse);
    expect(page.limit, 20);
  });
}
