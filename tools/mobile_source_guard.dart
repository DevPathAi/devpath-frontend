import 'dart:io';

Never _fail(String message) {
  stderr.writeln('mobile source guard: $message');
  exit(1);
}

void main() {
  final root = Directory.current;
  final lock = File('${root.path}/pubspec.lock');
  final workflow = File('${root.path}/.github/workflows/mobile.yml');
  final gradle = File('${root.path}/apps/mobile/android/app/build.gradle.kts');
  final mobileLib = Directory('${root.path}/apps/mobile/lib/src');

  for (final required in [lock, workflow, gradle]) {
    if (!required.existsSync()) _fail('missing ${required.path}');
  }
  for (final forbidden in ['sandbox', 'review', 'mentor']) {
    if (Directory('${mobileLib.path}/features/$forbidden').existsSync()) {
      _fail('native $forbidden feature is outside the companion boundary');
    }
  }

  final source = mobileLib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
  if (source.contains("'/onboarding'") || source.contains('"/onboarding"')) {
    _fail('obsolete native onboarding route/API is present');
  }
  for (final forbiddenRoute in [
    '/mission/:taskId/sandbox',
    '/mission/:taskId/mentor',
    '/review',
  ]) {
    if (source.contains(forbiddenRoute)) {
      _fail('native route $forbiddenRoute is outside the companion boundary');
    }
  }

  final workflowSource = workflow.readAsStringSync();
  if (!workflowSource.contains("flutter-version: '3.44.1'")) {
    _fail('Flutter toolchain is not pinned to 3.44.1');
  }
  if (!workflowSource.contains('flutter build apk --release --no-pub') ||
      !workflowSource.contains('apksigner')) {
    _fail('Android CI does not build and verify unsigned evidence');
  }
  if (workflowSource.contains('secrets.')) {
    _fail('build-only mobile CI must not consume signing secrets');
  }
  if (gradle.readAsStringSync().contains('signingConfigs.getByName("debug")')) {
    _fail('release Android build is wired to a debug signing key');
  }

  final expectedSha = Platform.environment['GITHUB_SHA'];
  if (expectedSha != null && expectedSha.isNotEmpty) {
    final result = Process.runSync('git', ['rev-parse', 'HEAD']);
    if (result.exitCode != 0 ||
        (result.stdout as String).trim() != expectedSha) {
      _fail('checkout HEAD does not equal GITHUB_SHA');
    }
  }

  stdout.writeln('mobile source guard: OK');
}
