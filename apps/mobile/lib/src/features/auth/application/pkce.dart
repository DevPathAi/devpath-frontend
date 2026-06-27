import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE(RFC 7636) verifier/challenge 쌍. 모바일 OAuth 하드닝(트랙 A).
///
/// `code_challenge = BASE64URL-NOPAD(SHA256(ASCII(code_verifier)))` (S256).
/// 백엔드 `Pkce.challengeS256`와 동일 규격(no-padding base64url).
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  final String verifier;
  final String challenge;

  /// 32바이트 난수 → 43자 base64url(no-pad) verifier + 그 S256 challenge.
  /// [random]은 테스트 주입용(미지정 시 [Random.secure]).
  factory PkcePair.generate({Random? random}) {
    final rnd = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final verifier = _b64url(bytes);
    return PkcePair(verifier: verifier, challenge: challengeFor(verifier));
  }

  /// verifier로부터 S256 challenge 계산(순수 함수, 단위테스트 대상).
  static String challengeFor(String verifier) =>
      _b64url(sha256.convert(ascii.encode(verifier)).bytes);

  static String _b64url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');
}
