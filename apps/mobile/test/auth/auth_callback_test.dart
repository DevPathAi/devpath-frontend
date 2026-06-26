import 'package:devpath_mobile/src/features/auth/application/auth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAuthCallback', () {
    test('query 파라미터 토큰 파싱', () {
      final pair = parseAuthCallback(
        Uri.parse('devpath://callback?access_token=acc&refresh_token=ref'),
      );
      expect(pair, isNotNull);
      expect(pair!.access, 'acc');
      expect(pair.refresh, 'ref');
    });

    test('fragment 토큰 파싱', () {
      final pair = parseAuthCallback(
        Uri.parse('devpath://callback#access_token=acc&refresh_token=ref'),
      );
      expect(pair, isNotNull);
      expect(pair!.access, 'acc');
      expect(pair.refresh, 'ref');
    });

    test('스킴 불일치 → null', () {
      expect(
        parseAuthCallback(
          Uri.parse('https://callback?access_token=a&refresh_token=r'),
        ),
        isNull,
      );
    });

    test('호스트 불일치 → null', () {
      expect(
        parseAuthCallback(
          Uri.parse('devpath://other?access_token=a&refresh_token=r'),
        ),
        isNull,
      );
    });

    test('refresh 누락 → null', () {
      expect(
        parseAuthCallback(Uri.parse('devpath://callback?access_token=a')),
        isNull,
      );
    });

    test('빈 토큰 → null', () {
      expect(
        parseAuthCallback(
          Uri.parse('devpath://callback?access_token=&refresh_token=r'),
        ),
        isNull,
      );
    });
  });
}
