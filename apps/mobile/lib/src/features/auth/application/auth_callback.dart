import 'package:dp_core/dp_core.dart';

/// OAuth 콜백 딥링크(`devpath://callback`) 파서.
///
/// 모바일 OAuth 계약(프론트 주도, 백엔드 후속 과제):
/// OAuth 성공 후 백엔드가 `devpath://callback?access_token=<jwt>&refresh_token=<token>`
/// 으로 리다이렉트한다. 토큰은 query 또는 fragment(`#a=1&b=2`) 어디에 와도 파싱한다.
///
/// 스킴/호스트가 다르거나 토큰이 비면 null(무시).
TokenPair? parseAuthCallback(Uri uri) {
  if (uri.scheme != 'devpath' || uri.host != 'callback') return null;

  final params = <String, String>{
    ...uri.queryParameters,
    ..._parseFragment(uri.fragment),
  };

  final access = params['access_token'];
  final refresh = params['refresh_token'];
  if (access == null || access.isEmpty) return null;
  if (refresh == null || refresh.isEmpty) return null;
  return TokenPair(access: access, refresh: refresh);
}

Map<String, String> _parseFragment(String fragment) {
  if (fragment.isEmpty) return const {};
  return Uri.splitQueryString(fragment);
}
