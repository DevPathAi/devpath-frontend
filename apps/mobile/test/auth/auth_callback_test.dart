import 'package:devpath_mobile/src/features/auth/application/auth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAuthCallbackCode', () {
    test('query code 파싱', () {
      expect(
        parseAuthCallbackCode(Uri.parse('devpath://callback?code=abc123')),
        'abc123',
      );
    });

    test('fragment code 파싱', () {
      expect(
        parseAuthCallbackCode(Uri.parse('devpath://callback#code=abc123')),
        'abc123',
      );
    });

    test('스킴 불일치 → null', () {
      expect(
        parseAuthCallbackCode(Uri.parse('https://callback?code=abc')),
        isNull,
      );
    });

    test('호스트 불일치 → null', () {
      expect(
        parseAuthCallbackCode(Uri.parse('devpath://other?code=abc')),
        isNull,
      );
    });

    test('code 누락 → null', () {
      expect(parseAuthCallbackCode(Uri.parse('devpath://callback')), isNull);
    });

    test('빈 code → null', () {
      expect(
        parseAuthCallbackCode(Uri.parse('devpath://callback?code=')),
        isNull,
      );
    });
  });
}
