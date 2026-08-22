import 'dart:convert';

enum SandboxLanguage {
  java('JAVA'),
  node('NODE'),
  python('PYTHON');

  const SandboxLanguage(this.wireName);

  final String wireName;

  static SandboxLanguage fromWire(String value) =>
      switch (value.trim().toUpperCase()) {
        'JAVA' => SandboxLanguage.java,
        'NODE' ||
        'NODEJS' ||
        'NODE.JS' ||
        'JS' ||
        'JAVASCRIPT' => SandboxLanguage.node,
        'PYTHON' || 'PY' => SandboxLanguage.python,
        _ => throw FormatException('Unsupported Sandbox language: $value'),
      };

  String get genericStarter => switch (this) {
    SandboxLanguage.java =>
      'public class Main {\n'
          '  public static void main(String[] args) {\n'
          '    System.out.println("Hello, Leva!");\n'
          '  }\n'
          '}\n',
    SandboxLanguage.node => "console.log('Hello, Leva!');\n",
    SandboxLanguage.python => 'print("Hello, Leva!")\n',
  };
}

enum SandboxSessionStatus {
  allocating,
  running,
  completed,
  failed,
  killed,
  timedOut;

  bool get isTerminal => switch (this) {
    completed || failed || killed || timedOut => true,
    allocating || running => false,
  };

  static SandboxSessionStatus fromWire(String value) => switch (value) {
    'ALLOCATING' => allocating,
    'RUNNING' => running,
    'COMPLETED' => completed,
    'FAILED' => failed,
    'KILLED' => killed,
    'TIMED_OUT' => timedOut,
    _ => throw FormatException('Unsupported Sandbox status: $value'),
  };
}

final class SandboxRunRequest {
  factory SandboxRunRequest({
    required String code,
    required SandboxLanguage language,
    int? contentId,
    int? codeBlockId,
  }) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', 'must not be blank');
    }
    if (utf8.encode(code).length > maxCodeBytes) {
      throw ArgumentError.value(
        utf8.encode(code).length,
        'code',
        'must not exceed $maxCodeBytes UTF-8 bytes',
      );
    }
    _validateId(contentId, 'contentId');
    _validateId(codeBlockId, 'codeBlockId');
    return SandboxRunRequest._(
      code: code,
      language: language,
      contentId: contentId,
      codeBlockId: codeBlockId,
    );
  }

  const SandboxRunRequest._({
    required this.code,
    required this.language,
    required this.contentId,
    required this.codeBlockId,
  });

  static const maxCodeBytes = 64 * 1024;
  static const maxSafeInteger = 9007199254740991;

  final String code;
  final SandboxLanguage language;
  final int? contentId;
  final int? codeBlockId;

  Map<String, Object?> toJson() => {
    'code': code,
    'language': language.wireName,
    'contentId': contentId,
    'codeBlockId': codeBlockId,
  };

  static void _validateId(int? value, String name) {
    if (value != null && (value <= 0 || value > maxSafeInteger)) {
      throw ArgumentError.value(value, name, 'must be a positive JS-safe ID');
    }
  }
}

final class SandboxTerminalResult {
  const SandboxTerminalResult({
    required this.sessionId,
    required this.status,
    required this.exitCode,
    required this.truncated,
  });

  final int sessionId;
  final SandboxSessionStatus status;
  final int? exitCode;
  final bool truncated;

  factory SandboxTerminalResult.fromJson(Map<String, Object?> json) {
    final sessionId = _positiveInt(json['sessionId']);
    final rawStatus = json['status'];
    final exitCode = json['exitCode'];
    final truncated = json['truncated'];
    if (sessionId == null ||
        rawStatus is! String ||
        (exitCode != null && exitCode is! int) ||
        truncated is! bool) {
      throw const FormatException('Malformed Sandbox terminal result');
    }
    final status = SandboxSessionStatus.fromWire(rawStatus);
    if (!status.isTerminal) {
      throw const FormatException('Sandbox result must be terminal');
    }
    return SandboxTerminalResult(
      sessionId: sessionId,
      status: status,
      exitCode: exitCode as int?,
      truncated: truncated,
    );
  }
}

final class SandboxSession {
  const SandboxSession({
    required this.sessionId,
    required this.language,
    required this.contentId,
    required this.codeBlockId,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.status,
    required this.truncated,
    required this.startedAt,
    required this.finishedAt,
  });

  final int sessionId;
  final SandboxLanguage language;
  final int? contentId;
  final int? codeBlockId;
  final String stdout;
  final String stderr;
  final int? exitCode;
  final SandboxSessionStatus status;
  final bool truncated;
  final DateTime startedAt;
  final DateTime? finishedAt;

  factory SandboxSession.fromJson(Map<String, Object?> json) {
    final sessionId = _positiveInt(json['sessionId']);
    final rawLanguage = json['language'];
    final contentId = _nullablePositiveInt(json['contentId']);
    final codeBlockId = _nullablePositiveInt(json['codeBlockId']);
    final rawStdout = json['stdout'];
    final rawStderr = json['stderr'];
    final exitCode = json['exitCode'];
    final rawStatus = json['status'];
    final truncated = json['truncated'];
    final startedAt = _instant(json['startedAt']);
    final finishedAt = json['finishedAt'] == null
        ? null
        : _instant(json['finishedAt']);
    if (sessionId == null ||
        rawLanguage is! String ||
        contentId == _invalidId ||
        codeBlockId == _invalidId ||
        (rawStdout != null && rawStdout is! String) ||
        (rawStderr != null && rawStderr is! String) ||
        (exitCode != null && exitCode is! int) ||
        rawStatus is! String ||
        truncated is! bool ||
        startedAt == null ||
        (json['finishedAt'] != null && finishedAt == null)) {
      throw const FormatException('Malformed Sandbox session');
    }
    final status = SandboxSessionStatus.fromWire(rawStatus);
    if (status.isTerminal != (finishedAt != null)) {
      throw const FormatException(
        'Sandbox session status and finishedAt are inconsistent',
      );
    }
    if (finishedAt != null && finishedAt.isBefore(startedAt)) {
      throw const FormatException(
        'Sandbox session finishedAt precedes startedAt',
      );
    }
    return SandboxSession(
      sessionId: sessionId,
      language: SandboxLanguage.fromWire(rawLanguage),
      contentId: contentId as int?,
      codeBlockId: codeBlockId as int?,
      stdout: rawStdout as String? ?? '',
      stderr: rawStderr as String? ?? '',
      exitCode: exitCode as int?,
      status: status,
      truncated: truncated,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

const _invalidId = Object();

int? _positiveInt(Object? value) =>
    value is int && value > 0 && value <= SandboxRunRequest.maxSafeInteger
    ? value
    : null;

Object? _nullablePositiveInt(Object? value) {
  if (value == null) return null;
  return _positiveInt(value) ?? _invalidId;
}

DateTime? _instant(Object? value) {
  if (value is! String) return null;
  final match = _rfc3339.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > _daysInMonth(year, month) ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final offsetHour = match.group(7);
  final offsetMinute = match.group(8);
  if (offsetHour != null && offsetMinute != null) {
    final hours = int.parse(offsetHour);
    final minutes = int.parse(offsetMinute);
    if (hours > 18 || minutes > 59 || (hours == 18 && minutes != 0)) {
      return null;
    }
  }
  final parsed = DateTime.tryParse(value);
  return parsed?.isUtc == true ? parsed : null;
}

final _rfc3339 = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
  r'(?:\.\d{1,9})?(?:Z|[+-](\d{2}):(\d{2}))$',
);

int _daysInMonth(int year, int month) => switch (month) {
  2 => (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};
