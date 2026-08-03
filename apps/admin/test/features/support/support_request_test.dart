import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportRequestRow', () {
    test('목록 행을 파싱한다', () {
      final row = SupportRequestRow.fromJson(const {
        'id': 42,
        'type': 'ERROR',
        'title': '경로 화면이 멈춰요',
        'status': 'OPEN',
        'pagePath': '/path',
        'reporterId': 7,
        'failureCount': 3,
        'createdAt': '2026-08-03T10:11:12Z',
      });

      expect(row.id, 42);
      expect(row.failureCount, 3);
      expect(row.typeLabel, '오류');
      expect(row.statusLabel, '접수됨'); // 필터·표기는 명사
    });

    test('상태 라벨 4종이 명사다', () {
      String label(String s) => SupportRequestRow.fromJson({
        'id': 1,
        'type': 'INQUIRY',
        'title': 't',
        'status': s,
        'failureCount': 0,
      }).statusLabel;

      expect(label('OPEN'), '접수됨');
      expect(label('IN_PROGRESS'), '처리중');
      expect(label('RESOLVED'), '처리됨');
      expect(label('WONTFIX'), '보류');
    });
  });

  group('SupportRequestDetail', () {
    test('실패 목록을 seq 순으로 담는다', () {
      final d = SupportRequestDetail.fromJson(const {
        'id': 42,
        'type': 'ERROR',
        'title': '제목',
        'body': '본문',
        'status': 'OPEN',
        'pagePath': '/path',
        'appVersion': '0.1.0+42',
        'userAgent': 'UA',
        'viewport': '1920x1080',
        'occurredAt': '2026-08-03T10:11:12Z',
        'reporterId': 7,
        'createdAt': '2026-08-03T10:11:12Z',
        'failures': [
          {
            'seq': 0,
            'method': 'POST',
            'path': '/learning-paths',
            'statusCode': 500,
            'errorCode': 'INTERNAL_ERROR',
            'message': '문의: [EMAIL]',
            'occurredAt': '2026-08-03T10:11:09Z',
          },
          {
            'seq': 1,
            'method': 'GET',
            'path': '/dashboard',
            'statusCode': null,
            'occurredAt': '2026-08-03T10:11:00Z',
          },
        ],
      });

      expect(d.failures, hasLength(2));
      expect(d.failures.first.seq, 0);
      // 네트워크 실패는 statusCode 가 null 이고, 그 구분 자체가 진단 정보다.
      expect(d.failures.last.statusCode, isNull);
      expect(d.failures.last.statusLabel, '네트워크 실패');
    });
  });
}
