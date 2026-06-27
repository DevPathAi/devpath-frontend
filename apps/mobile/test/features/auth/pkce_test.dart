import 'dart:math';

import 'package:devpath_mobile/src/features/auth/application/pkce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PkcePair', () {
    test('challengeFor: RFC 7636 Appendix B 테스트 벡터', () {
      expect(
        PkcePair.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('generate: verifier 43자 base64url, challenge가 verifier와 일치', () {
      final p = PkcePair.generate(random: Random(42));
      expect(p.verifier.length, 43);
      expect(
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p.verifier),
        isTrue,
        reason: p.verifier,
      );
      expect(p.challenge, PkcePair.challengeFor(p.verifier));
    });

    test('generate: 패딩(=) 없음(base64url no-pad)', () {
      final p = PkcePair.generate(random: Random(1));
      expect(p.verifier.contains('='), isFalse);
      expect(p.challenge.contains('='), isFalse);
    });
  });
}
