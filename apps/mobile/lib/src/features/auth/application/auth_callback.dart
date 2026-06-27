/// OAuth 콜백 딥링크(`devpath://callback`) 파서 — 하드닝 트랙 A(일회용 code + PKCE).
///
/// 모바일 OAuth 계약: OAuth 성공 후 백엔드가 토큰 대신 **일회용 code**를 실어
/// `devpath://callback?code=<code>` 로 리다이렉트한다. 앱은 이 code를 보관해 둔
/// `code_verifier`와 함께 `POST /auth/oauth/token`으로 교환해 토큰을 받는다(토큰은
/// URL에 절대 실리지 않는다). code는 query 또는 fragment 어디에 와도 파싱한다.
///
/// 스킴/호스트가 다르거나 code가 비면 null(무시).
String? parseAuthCallbackCode(Uri uri) {
  if (uri.scheme != 'devpath' || uri.host != 'callback') return null;

  final params = <String, String>{
    ...uri.queryParameters,
    ..._parseFragment(uri.fragment),
  };

  final code = params['code'];
  if (code == null || code.isEmpty) return null;
  return code;
}

Map<String, String> _parseFragment(String fragment) {
  if (fragment.isEmpty) return const {};
  return Uri.splitQueryString(fragment);
}
