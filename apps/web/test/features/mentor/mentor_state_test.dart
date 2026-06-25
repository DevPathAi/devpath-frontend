import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MentorReference.fromJson 파싱', () {
    final r = MentorReference.fromJson(
      const {'contentId': 7, 'slug': 'async-await', 'title': '비동기 기초'},
    );
    expect(r.contentId, 7);
    expect(r.slug, 'async-await');
    expect(r.title, '비동기 기초');
  });

  test('MentorState references 기본값은 빈 리스트', () {
    const s = MentorState();
    expect(s.references, isEmpty);
    expect(s.status, MentorStatus.idle);
    expect(s.messages, isEmpty);
  });
}
