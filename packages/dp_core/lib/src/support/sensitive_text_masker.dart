/// 민감 패턴 마스킹 — 스펙 §6.2. 규칙 순서가 결과를 결정하므로 **순서를 바꾸지 않는다.**
///
/// platform-svc 의 `SensitiveTextMasker`(Java)와 같은 규칙·같은 순서다. 한쪽만 고치면
/// 두 구현이 어긋나고, 스펙 §6.3 케이스 표 테스트가 그 어긋남을 잡는다.
///
/// 패턴에 `(?i)` 인라인 플래그와 lookbehind 를 쓰지 않는다 — Dart RegExp 가 지원하지 않는다.
/// 대소문자 무시는 `caseSensitive: false` 로 준다.
///
/// Dart 는 `replaceAll` 치환 문자열의 `$1` 을 해석하지 않으므로 **replaceAllMapped** 를 쓴다.
class SensitiveTextMasker {
  const SensitiveTextMasker._();

  static final List<(RegExp, String Function(Match))> _rules = [
    // 1. 키=값 형태 비밀. 규칙 2보다 먼저다 — 반대면 'Authorization=[REDACTED] [TOKEN]' 이 남는다.
    //    값 패턴의 (Bearer\s+)? 도 같은 이유(헤더 값이 두 토큰이라 \S+ 하나로는 본체가 남는다).
    (
      RegExp(
        r'(api[_-]?key|authorization|password|secret|token)\s*[:=]\s*(Bearer\s+)?[^\s,;]+',
        caseSensitive: false,
      ),
      (m) => '${m[1]}=[REDACTED]',
    ),
    // 2. 키 없이 노출된 JWT
    (
      RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'),
      (_) => '[TOKEN]',
    ),
    // 3. DB 접속 문자열. 이메일·IP 보다 먼저 — 통째로 지워야 호스트·계정 흔적이 안 남는다.
    (
      RegExp(r'(jdbc:|postgresql://|postgres://|mysql://|redis://)\S+'),
      (_) => '[DSN]',
    ),
    // 4. 이메일
    (RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), (_) => '[EMAIL]'),
    // 5. 카드(16자리). 주민번호(13자리)보다 먼저 — 반대면 구분자 없는 16자리의 중간
    //    13자리가 RRN 으로 잡혀 카드번호를 조각낸다.
    (RegExp(r'\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}'), (_) => '[CARD]'),
    // 6. 주민등록번호
    (RegExp(r'\d{6}-?[1-4]\d{6}'), (_) => '[RRN]'),
    // 7. 휴대전화
    (RegExp(r'01[016789]-?\d{3,4}-?\d{4}'), (_) => '[PHONE]'),
    // 8. 윈도 홈 경로 — 사용자명까지만 지우고 하위 경로는 진단용으로 남긴다.
    (RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+'), (_) => '[PATH]'),
    // 9. POSIX 홈 경로 — 같은 이유.
    (RegExp(r'/(home|Users)/[^/\s]+'), (_) => '[PATH]'),
    // 10. IPv4. 마지막이다 — 앞 규칙이 끝난 뒤 남은 것만 보게 해 오탐을 줄인다.
    (RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b'), (_) => '[IP]'),
  ];

  /// 빈 문자열은 그대로 통과한다.
  static String mask(String input) {
    if (input.isEmpty) return input;
    var out = input;
    for (final (pattern, replace) in _rules) {
      out = out.replaceAllMapped(pattern, replace);
    }
    return out;
  }

  /// 마스킹 후 절단. 절단이 뒤여야 잘린 토큰 조각이 남지 않는다.
  static String? maskAndTruncate(String? input, int max) {
    if (input == null) return null;
    final masked = mask(input);
    return masked.length <= max ? masked : masked.substring(0, max);
  }
}
