import 'dart:io';

const _alias = 'MissionLinkActivity';
const _canonical = <String>[
  'https://app.leva.ai.kr/path/301/today',
  'https://app.leva.ai.kr/mission/302/content/77',
  'https://app.leva.ai.kr/path/999999999999999/today',
];
const _rejected = <String>[
  'https://app.leva.ai.kr/path/9007199254740992/today',
  'https://app.leva.ai.kr/mission/9007199254740992/content/77',
  'https://app.leva.ai.kr/mission/302/content/9007199254740992',
  'https://app.leva.ai.kr/path/301/today?source=push',
  'https://app.leva.ai.kr/mission/302/content/77?source=push',
  'https://app.leva.ai.kr/path/301/today#content',
  'https://app.leva.ai.kr/mission/302/content/77#content',
  'https://app.leva.ai.kr/mission/302/sandbox/content/77',
  'https://app.leva.ai.kr/mission/302/mentor/content/77',
  'https://app.leva.ai.kr/mission/302/content/77/extra',
];

Never _fail(String message) {
  stderr.writeln('Android companion link contract: $message');
  exit(1);
}

void main(List<String> args) {
  for (final uri in _canonical) {
    if (!_isConservativeCompanionUri(uri)) {
      _fail('source contract rejected canonical URI: $uri');
    }
  }
  for (final uri in _rejected) {
    if (_isConservativeCompanionUri(uri)) {
      _fail('source contract claimed rejected URI: $uri');
    }
  }

  if (!args.contains('--adb')) {
    stdout.writeln('Android companion link source contract: OK');
    return;
  }

  for (final uri in _canonical) {
    final resolved = _resolveWithAdb(uri);
    if (!resolved.contains(_alias)) {
      _fail('installed app did not resolve canonical URI: $uri ($resolved)');
    }
  }
  for (final uri in _rejected) {
    final resolved = _resolveWithAdb(uri);
    if (resolved.contains(_alias)) {
      _fail('installed app claimed rejected URI: $uri ($resolved)');
    }
  }
  stdout.writeln('Android companion link adb contract: OK');
}

String _resolveWithAdb(String uri) {
  final result = Process.runSync('adb', [
    'shell',
    'cmd',
    'package',
    'resolve-activity',
    '--brief',
    '-a',
    'android.intent.action.VIEW',
    '-c',
    'android.intent.category.BROWSABLE',
    '-d',
    uri,
  ]);
  if (result.exitCode != 0) {
    _fail('adb resolver failed for $uri: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

bool _isConservativeCompanionUri(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'app.leva.ai.kr' ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  return RegExp(r'^/path/[1-9][0-9]{0,14}/today$').hasMatch(uri.path) ||
      RegExp(
        r'^/mission/[1-9][0-9]{0,14}/content/[1-9][0-9]{0,14}$',
      ).hasMatch(uri.path);
}
