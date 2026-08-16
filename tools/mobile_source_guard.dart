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
  final gradleWrapper = File(
    '${root.path}/apps/mobile/android/gradle/wrapper/gradle-wrapper.properties',
  );
  final manifest = File(
    '${root.path}/apps/mobile/android/app/src/main/AndroidManifest.xml',
  );
  final iosProject = File(
    '${root.path}/apps/mobile/ios/Runner.xcodeproj/project.pbxproj',
  );
  final iosInfo = File('${root.path}/apps/mobile/ios/Runner/Info.plist');
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
    gradleWrapper,
    manifest,
    iosProject,
    iosInfo,
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
  if (source.contains('setAutoInitEnabled(true)')) {
    _fail('FCM auto-init must never be enabled before or after consent');
  }
  if (!source.contains('Future<void> disableAutoInit()')) {
    _fail('push lifecycle must expose a disable-only auto-init boundary');
  }
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
  for (final marker in [
    'android:name="firebase_messaging_auto_init_enabled" '
        'android:value="false"',
    'android:name="firebase_analytics_collection_enabled" '
        'android:value="false"',
    'android:name="flutter_deeplinking_enabled" android:value="false"',
  ]) {
    if (!manifestSource.contains(marker)) {
      _fail('mobile native opt-in boundary is missing: $marker');
    }
  }
  final iosInfoSource = iosInfo.readAsStringSync();
  for (final key in [
    'FirebaseMessagingAutoInitEnabled',
    'FlutterDeepLinkingEnabled',
  ]) {
    if (!RegExp('<key>$key</key>\\s*<false/>').hasMatch(iosInfoSource)) {
      _fail('iOS native opt-in boundary is missing: $key=false');
    }
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
  _guardWorkflowActions(workflowSource);
  final toolchainViolation = mobileWorkflowToolchainViolation(workflowSource);
  if (toolchainViolation != null) _fail(toolchainViolation);
  if (!workflowSource.contains("flutter-version: '3.44.1'")) {
    _fail('Flutter toolchain is not pinned to 3.44.1');
  }
  for (final requiredMarker in [
    'runs-on: ubuntu-24.04',
    'runs-on: macos-26',
    '"dartSdkVersion": "3.12.1"',
    "java-version: '17.0.20+8'",
    'OpenJDK Runtime Environment Temurin-17.0.20+8 '
        '(build 17.0.20+8)',
    'platforms/android-36/android.jar',
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
  if (!gradleWrapper.readAsStringSync().contains(
    'distributionSha256Sum='
    'b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85',
  )) {
    _fail('Gradle distribution is not pinned by SHA-256');
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

String? mobileWorkflowToolchainViolation(String workflowSource) {
  const exactJavaToolchain = [
    "java-version: '17.0.20+8'",
    'OpenJDK Runtime Environment Temurin-17.0.20+8 '
        '(build 17.0.20+8)',
  ];
  for (final marker in exactJavaToolchain) {
    if (!workflowSource.contains(marker)) {
      return 'mobile CI must pin Temurin 17.0.20+8 runtime and build: '
          'missing $marker';
    }
  }
  const exactAppleToolchain = [
    "xcode-version: '26.4.1'",
    "xcodebuild -version | grep -q '^Xcode 26.4.1\$'",
    "xcodebuild -version | grep -q '^Build version 17E202\$'",
    "xcrun --sdk iphoneos --show-sdk-version | grep -q '^26.4\$'",
  ];
  for (final marker in exactAppleToolchain) {
    if (!workflowSource.contains(marker)) {
      return 'mobile CI must pin Xcode 26.4.1 build 17E202 and SDK 26.4: '
          'missing $marker';
    }
  }
  return null;
}

void _guardWorkflowActions(String workflowSource) {
  final violation = mobileWorkflowActionViolation(workflowSource);
  if (violation != null) _fail(violation);
}

const _reviewedMobileActions =
    <String, ({String sha, String version, int count})>{
      'actions/checkout': (
        sha: 'd23441a48e516b6c34aea4fa41551a30e30af803',
        version: 'v6.1.0',
        count: 2,
      ),
      'subosito/flutter-action': (
        sha: '1a449444c387b1966244ae4d4f8c696479add0b2',
        version: 'v2.23.0',
        count: 2,
      ),
      'actions/setup-java': (
        sha: 'cf277c60eb25467037889841efdb72551f06f6c3',
        version: 'v4.9.1',
        count: 1,
      ),
      'actions/upload-artifact': (
        sha: 'ea165f8d65b6e75b540449e92b4886f43607fa02',
        version: 'v4.6.2',
        count: 2,
      ),
      'maxim-lobanov/setup-xcode': (
        sha: 'ed7a3b1fda3918c0306d1b724322adc0b8cc0a90',
        version: 'v1.7.0',
        count: 1,
      ),
    };

String? mobileWorkflowActionViolation(String workflowSource) {
  final uses = RegExp(
    r'^\s*(?:-\s+)?uses: ([^@\s]+)@([^\s#]+)(?:\s+#\s*(\S+))?\s*$',
    multiLine: true,
  ).allMatches(workflowSource).toList();
  final rawUseCount = RegExp(
    r'^\s*(?:-\s+)?uses:',
    multiLine: true,
  ).allMatches(workflowSource).length;
  if (uses.length != rawUseCount) {
    return 'mobile CI contains an unparseable action reference';
  }
  final unknown = uses
      .map((match) => match.group(1)!)
      .where((name) => !_reviewedMobileActions.containsKey(name))
      .toSet();
  if (unknown.isNotEmpty) {
    return 'mobile CI action set contains unreviewed action(s): '
        '${unknown.join(', ')}';
  }
  for (final reviewed in _reviewedMobileActions.entries) {
    final actionUses = uses
        .where((match) => match.group(1) == reviewed.key)
        .toList();
    if (actionUses.length != reviewed.value.count) {
      return '${reviewed.key} must occur exactly '
          '${reviewed.value.count} time(s)';
    }
    for (final use in actionUses) {
      if (use.group(2) != reviewed.value.sha ||
          use.group(3) != reviewed.value.version) {
        return '${reviewed.key} must use reviewed pin '
            '${reviewed.value.sha} # ${reviewed.value.version}';
      }
    }
  }
  return null;
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
