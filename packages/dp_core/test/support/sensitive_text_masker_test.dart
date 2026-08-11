import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

/// 마스킹 케이스 표 — 스펙 §6.3.
/// platform-svc 의 SensitiveTextMaskerTest.java 와 **입력·기대 출력이 완전히 같다.**
/// 한쪽만 고치면 두 구현이 어긋난다.
void main() {
  const cases = <(String, String)>[
    ('연락처는 hong@example.com 입니다', '연락처는 [EMAIL] 입니다'),
    (
      'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc',
      'Authorization=[REDACTED]',
    ),
    ('token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc 만료', 'token [TOKEN] 만료'),
    ('연결 실패 jdbc:postgresql://db:5432/devpath?user=x', '연결 실패 [DSN]'),
    ('주민번호 900101-1234567 조회', '주민번호 [RRN] 조회'),
    ('카드 1234-5678-9012-3456 승인', '카드 [CARD] 승인'),
    ('전화 010-1234-5678 로 연락', '전화 [PHONE] 로 연락'),
    (r'파일 C:\Users\deepe\project\a.txt 없음', r'파일 [PATH]\project\a.txt 없음'),
    ('경로 /home/ubuntu/app/x.log 실패', '경로 [PATH]/app/x.log 실패'),
    ('서버 10.0.1.23 응답 없음', '서버 [IP] 응답 없음'),
    ('정상 메시지입니다', '정상 메시지입니다'),
    ('', ''),
  ];

  group('SensitiveTextMasker', () {
    for (var i = 0; i < cases.length; i++) {
      final (input, expected) = cases[i];
      test('case ${i + 1}', () {
        expect(SensitiveTextMasker.mask(input), expected);
      });
    }

    test('절단은 마스킹보다 뒤 — 잘린 토큰 조각이 남지 않는다', () {
      final input = '메일 hong@example.com 그리고 ${'가' * 600}';
      final out = SensitiveTextMasker.maskAndTruncate(input, 500)!;
      expect(out.length, 500);
      expect(out.startsWith('메일 [EMAIL] 그리고'), isTrue);
      expect(out.contains('hong@example.com'), isFalse);
    });

    test('null 은 그대로 통과', () {
      expect(SensitiveTextMasker.maskAndTruncate(null, 500), isNull);
    });
  });
}
