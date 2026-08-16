import 'dart:io';

Never _fail(String message) {
  stderr.writeln('mobile source guard: $message');
  exit(1);
}

void main(List<String> args) {
  String? sourceOnly;
  for (final argument in args) {
    if (argument.startsWith('--source-only=')) {
      sourceOnly = argument.substring('--source-only='.length);
      break;
    }
  }
  if (sourceOnly != null) {
    _guardDartSource(Directory(sourceOnly));
    stdout.writeln('mobile source guard: OK');
    return;
  }

  final root = Directory.current;
  final lock = File('${root.path}/pubspec.lock');
  final workflow = File('${root.path}/.github/workflows/mobile.yml');
  final gradle = File('${root.path}/apps/mobile/android/app/build.gradle.kts');
  final manifest = File(
    '${root.path}/apps/mobile/android/app/src/main/AndroidManifest.xml',
  );
  final iosProject = File(
    '${root.path}/apps/mobile/ios/Runner.xcodeproj/project.pbxproj',
  );
  final iosFirebaseExample = File(
    '${root.path}/apps/mobile/ios/Runner/GoogleService-Info.plist.example',
  );
  final fcmDocs = File('${root.path}/apps/mobile/docs/FCM_SETUP.md');
  final androidLinkDefault = File(
    '${root.path}/apps/mobile/android/app/src/main/res/values/bools.xml',
  );
  final androidLinkV35 = File(
    '${root.path}/apps/mobile/android/app/src/main/res/values-v35/bools.xml',
  );
  final androidLinkProbe = File(
    '${root.path}/apps/mobile/tools/mobile_android_link_contract.dart',
  );
  final companionReleaseGates = File(
    '${root.path}/apps/mobile/docs/MISSION_COMPANION_RELEASE_GATES.md',
  );
  final mobileLib = Directory('${root.path}/apps/mobile/lib');

  for (final required in [
    lock,
    workflow,
    gradle,
    manifest,
    iosProject,
    iosFirebaseExample,
    fcmDocs,
    androidLinkDefault,
    androidLinkV35,
    androidLinkProbe,
    companionReleaseGates,
  ]) {
    if (!required.existsSync()) _fail('missing ${required.path}');
  }
  for (final forbidden in ['sandbox', 'review', 'mentor']) {
    if (Directory('${mobileLib.path}/src/features/$forbidden').existsSync()) {
      _fail('native $forbidden feature is outside the companion boundary');
    }
  }

  final source = _guardDartSource(mobileLib);
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
  for (final forbiddenLeak in [
    'package:devpath_web/',
    'apps/web/',
    'SandboxPage(',
    'ReviewPage(',
    'MentorPage(',
    'ClaimPage(',
  ]) {
    if (source.contains(forbiddenLeak)) {
      _fail('web-only implementation leaked into mobile: $forbiddenLeak');
    }
  }

  final manifestSource = manifest.readAsStringSync();
  if (!manifestSource.contains('android:host="app.leva.ai.kr"') ||
      !manifestSource.contains(
        'android:enabled="@bool/enable_exact_app_links"',
      ) ||
      !manifestSource.contains(
        'android:pathAdvancedPattern="/path/[1-9][0-9]{0,14}/today"',
      ) ||
      !manifestSource.contains(
        'android:pathAdvancedPattern="/mission/[1-9][0-9]{0,14}/content/[1-9][0-9]{0,14}"',
      ) ||
      !manifestSource.contains('android:queryPattern=".*"') ||
      !manifestSource.contains('android:fragmentPattern=".*"') ||
      !manifestSource.contains(
        '<uri-relative-filter-group android:allow="false">',
      ) ||
      manifestSource.contains('android:pathPattern=') ||
      manifestSource.contains('android:pathPrefix="/mission/"')) {
    _fail(
      'Android verified links are not exact canonical Today/Content filters',
    );
  }
  if (!androidLinkDefault.readAsStringSync().contains(
        '<bool name="enable_exact_app_links">false</bool>',
      ) ||
      !androidLinkV35.readAsStringSync().contains(
        '<bool name="enable_exact_app_links">true</bool>',
      )) {
    _fail('Android exact-link alias does not fail closed before API 35');
  }
  if (Directory(
    '${root.path}/apps/mobile/android/app/src/main/res/values-v31',
  ).existsSync()) {
    _fail('Android exact-link alias must not activate before API 35');
  }
  final linkProbeResult = Process.runSync(Platform.resolvedExecutable, [
    androidLinkProbe.path,
  ]);
  if (linkProbeResult.exitCode != 0) {
    _fail('Android link source probe failed: ${linkProbeResult.stderr}');
  }
  final releaseGateSource = companionReleaseGates.readAsStringSync();
  for (final marker in [
    'API 35',
    '999999999999999',
    'query',
    'fragment',
    '--adb',
  ]) {
    if (!releaseGateSource.contains(marker)) {
      _fail('mobile link release gate is missing: $marker');
    }
  }

  final workflowSource = workflow.readAsStringSync();
  if (!workflowSource.contains("flutter-version: '3.44.1'")) {
    _fail('Flutter toolchain is not pinned to 3.44.1');
  }
  for (final requiredMarker in [
    '"dartSdkVersion": "3.12.1"',
    "java-version: '17'",
    'platforms/android-36/android.jar',
    "xcode-version: '26.4'",
    'xcodebuild -version',
    '--dart-define=USE_MOCK=true',
    '--dart-define=USE_MOCK=false',
    '--dart-define=API_BASE_URL=https://api.leva.ai.kr',
  ]) {
    if (!workflowSource.contains(requiredMarker)) {
      _fail('mobile CI is missing exact contract: $requiredMarker');
    }
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
  final xcodeSource = iosProject.readAsStringSync();
  final entitlements = _runnerEntitlements(xcodeSource);
  const expectedEntitlements = {
    'Debug': 'Runner/RunnerDebug.entitlements',
    'Release': 'Runner/RunnerRelease.entitlements',
    'Profile': 'Runner/RunnerRelease.entitlements',
  };
  if (entitlements.length != expectedEntitlements.length ||
      expectedEntitlements.entries.any(
        (entry) => entitlements[entry.key] != entry.value,
      )) {
    _fail('iOS APNs entitlements are not split by build configuration');
  }
  for (final source in [
    iosFirebaseExample.readAsStringSync(),
    fcmDocs.readAsStringSync(),
  ]) {
    if (!source.contains('ai.devpath.devpathMobile')) {
      _fail('FCM setup does not match the actual iOS bundle identifier');
    }
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

String _guardDartSource(Directory directory) {
  if (!directory.existsSync()) _fail('missing ${directory.path}');
  final source = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
  for (final forbidden in [
    'dart:html',
    'dart:js_interop',
    'dart:js',
    'localStorage',
    'sessionStorage',
  ]) {
    if (source.contains(forbidden)) {
      _fail('browser-only API leaked into mobile: $forbidden');
    }
  }
  return source;
}

Map<String, String> _runnerEntitlements(String project) {
  final sections = project.split('/* Begin XCBuildConfiguration section */');
  if (sections.length < 2) return const {};
  final section = sections[1].split(
    '/* End XCBuildConfiguration section */',
  )[0];
  final result = <String, String>{};
  final blocks = RegExp(
    r'/\* (Debug|Release|Profile) \*/ = \{(.*?)\n\s*\};',
    dotAll: true,
  ).allMatches(section);
  for (final block in blocks) {
    final body = block.group(2)!;
    if (!body.contains(
      'PRODUCT_BUNDLE_IDENTIFIER = ai.devpath.devpathMobile;',
    )) {
      continue;
    }
    final entitlement = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = ([^;]+);',
    ).firstMatch(body);
    result[block.group(1)!] = entitlement?.group(1) ?? '';
  }
  return result;
}
