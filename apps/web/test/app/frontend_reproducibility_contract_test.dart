import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _checkout = 'actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803';
const _flutterAction =
    'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2';
const _setupBuildx =
    'docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f';
const _buildPush =
    'docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a';
const _dockerLogin =
    'docker/login-action@dbcb813823bdd20940b903addbd779551569679f';
const _uploadArtifact =
    'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02';
const _downloadArtifact =
    'actions/download-artifact@018cc2cf5baa6db3ef3c5f8a56943fffe632ef53';
const _githubAppToken =
    'actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1';

const _buildkitImage =
    'moby/buildkit:v0.30.0@sha256:0168606be2315b7c807a03b3d8aa79beefdb31c98740cebdffdfeebf31190c9f';
const _flutterBuilder =
    'ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8';
const _nginxRuntime =
    'nginx:alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752';
const _flutterArchiveSha =
    '287937458126a53284ed112c8c7dbc647bea2d09ab65d46e2d5cf94e901aac69';
const _flutterRevision = '924134a44c189315be2148659913dda1671cbe99';
const _kustomizeSha =
    '3669470b454d865c8184d6bce78df05e977c9aea31c30df3c669317d43bcc7a7';
const _gradleDistributionSha =
    'b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85';
const _zeroSha =
    '0000000000000000000000000000000000000000000000000000000000000000';
const _lockInvariant =
    r'''test "$(sha256sum pubspec.lock | awk '{print $1}')" = "${lock_sha256_before}"''';

int _count(String source, String needle) => needle.allMatches(source).length;

List<String> _actionStepBodies(String source, String action) {
  final lines = source.split('\n');
  final bodies = <String>[];

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final trimmedLine = line.trim();
    if (trimmedLine != '- uses: $action' &&
        !trimmedLine.startsWith('- uses: $action #')) {
      continue;
    }

    final indentation = line.length - line.trimLeft().length;
    final body = StringBuffer()..writeln(line);
    for (var next = index + 1; next < lines.length; next++) {
      final candidate = lines[next];
      final trimmed = candidate.trimLeft();
      final candidateIndentation = candidate.length - trimmed.length;
      if (candidateIndentation == indentation && trimmed.startsWith('- ')) {
        break;
      }
      if (trimmed.isNotEmpty && candidateIndentation < indentation) break;
      body.writeln(candidate);
    }
    bodies.add(body.toString());
  }

  return bodies;
}

List<String> _workflowPinErrors(String source) {
  final errors = <String>[];
  final uses =
      RegExp(
        r'^\s*(?:-\s+)?uses:\s+(\S+)(?:\s+#\s+(\S+))?\s*$',
        multiLine: true,
      ).allMatches(source).map((match) {
        final version = match.group(2);
        return version == null
            ? match.group(1)!
            : '${match.group(1)!} # $version';
      }).toList();
  const expectedUses = <String>[
    '$_checkout # v6.1.0',
    '$_flutterAction # v2.23.0',
    '$_checkout # v6.1.0',
    '$_setupBuildx # v3.12.0',
    '$_buildPush # v7.3.0',
    '$_uploadArtifact # v4.6.2',
    '$_checkout # v6.1.0',
    '$_setupBuildx # v3.12.0',
    '$_dockerLogin # v4.6.0',
    '$_buildPush # v7.3.0',
    '$_uploadArtifact # v4.6.2',
    '$_downloadArtifact # v6.0.0',
    '$_checkout # v6.1.0',
    '$_setupBuildx # v3.12.0',
    '$_dockerLogin # v4.6.0',
    '$_buildPush # v7.3.0',
    '$_githubAppToken # v3.2.0',
    '$_checkout # v6.1.0',
  ];

  if (uses.length != expectedUses.length ||
      !Iterable.generate(uses.length).every(
        (index) =>
            index < expectedUses.length && uses[index] == expectedUses[index],
      )) {
    errors.add('ordered action pin map drifted: $uses');
  }
  if (uses.any(
    (value) =>
        !RegExp(r'^[^@]+@[0-9a-f]{40} # v\d+\.\d+\.\d+$').hasMatch(value),
  )) {
    errors.add('every action must use a full immutable commit SHA');
  }
  if (RegExp(r'\b[a-z0-9-]+-latest\b').hasMatch(source)) {
    errors.add('latest runner labels are forbidden');
  }
  if (_count(source, 'runs-on: ubuntu-24.04') != 6) {
    errors.add('all six ET10 jobs must use ubuntu-24.04');
  }
  final setupBuildxSteps = _actionStepBodies(source, _setupBuildx);
  if (setupBuildxSteps.length != 3 ||
      setupBuildxSteps.any(
        (step) =>
            !step.contains('version: v0.34.1') ||
            !step.contains('image=$_buildkitImage') ||
            step.contains('platforms:'),
      )) {
    errors.add('all three builders must pin Buildx and BuildKit');
  }
  final buildPushSteps = _actionStepBodies(source, _buildPush);
  if (buildPushSteps.length != 3 ||
      buildPushSteps.any((step) => !step.contains('platforms: linux/amd64')) ||
      _count(source, 'platforms: linux/amd64') != 3) {
    errors.add('all three image builds must pin linux/amd64');
  }
  if (!source.contains("flutter-version: '3.44.1'") ||
      !source.contains('dart pub get --enforce-lockfile') ||
      !source.contains('dart run melos bootstrap --enforce-lockfile') ||
      !source.contains('lock_sha256_before=') ||
      !source.contains(_lockInvariant) ||
      source.contains('dart pub global activate melos')) {
    errors.add('CI must use the locked Flutter workspace Melos');
  }
  if (!source.contains(_kustomizeSha) ||
      !source.contains('sha256sum -c -') ||
      !source.contains('kustomize_v5.4.3_linux_amd64.tar.gz')) {
    errors.add('Kustomize 5.4.3 download must be checksum verified');
  }
  return errors;
}

List<String> _dockerfilePinErrors(String source) {
  final errors = <String>[];
  final expectedBuilder =
      'FROM --platform=linux/amd64 $_flutterBuilder AS build';
  final expectedRuntime =
      'FROM --platform=linux/amd64 $_nginxRuntime AS runtime';

  if (!source.contains(expectedBuilder) || !source.contains(expectedRuntime)) {
    errors.add('Docker base image or platform drifted');
  }
  if (!source.contains('ENV FLUTTER_VERSION=3.44.1') ||
      !source.contains('DART_VERSION=3.12.1') ||
      !source.contains('FLUTTER_REVISION=$_flutterRevision') ||
      !source.contains('FLUTTER_ARCHIVE_SHA256=$_flutterArchiveSha') ||
      source.contains('ARG FLUTTER_VERSION') ||
      source.contains('ARG FLUTTER_ARCHIVE_SHA256')) {
    errors.add('Flutter SDK tuple drifted');
  }
  if (!source.contains('flutter_linux_\${FLUTTER_VERSION}-stable.tar.xz') ||
      !source.contains('sha256sum -c -') ||
      !source.contains('frameworkRevision') ||
      RegExp(r'curl[\s\S]{0,300}\|\s*tar').hasMatch(source)) {
    errors.add('Flutter archive must be downloaded, verified, then extracted');
  }
  if (!source.contains('dart pub get --enforce-lockfile') ||
      !source.contains('dart run melos bootstrap --enforce-lockfile') ||
      !source.contains(_lockInvariant) ||
      source.contains('dart pub global activate melos')) {
    errors.add('Docker build must preserve and use the workspace lock');
  }
  return errors;
}

void main() {
  late String workflow;
  late String webDockerfile;
  late String adminDockerfile;
  late String gradleWrapper;

  setUpAll(() {
    workflow = File(
      '../../.github/workflows/ci.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    webDockerfile = File('Dockerfile').readAsStringSync();
    adminDockerfile = File('../admin/Dockerfile').readAsStringSync();
    gradleWrapper = File(
      '../mobile/android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();
  });

  test('ET10 workflow locks the exact approved action and builder graph', () {
    expect(_workflowPinErrors(workflow), isEmpty);
  });

  test('workflow contract rejects same-count action and builder drift', () {
    final actionDrift = workflow.replaceFirst(
      _checkout,
      'actions/checkout@0000000000000000000000000000000000000000',
    );
    final buildkitDrift = workflow.replaceFirst(
      _buildkitImage,
      'moby/buildkit:v0.30.0@sha256:$_zeroSha',
    );
    final setupPlatformDrift = workflow.replaceFirst(
      'version: v0.34.1',
      'version: v0.34.1\n          platforms: linux/amd64',
    );
    final lockDrift = workflow.replaceFirst(
      'dart run melos bootstrap --enforce-lockfile',
      'dart run melos bootstrap',
    );
    final lockAssertionDrift = workflow.replaceFirst(_lockInvariant, 'true');
    final wrongComment = workflow.replaceFirst(
      '$_checkout # v6.1.0',
      '$_checkout # v6.1.1',
    );
    final missingComment = workflow.replaceFirst(
      '$_flutterAction # v2.23.0',
      _flutterAction,
    );
    final arbitraryComment = workflow.replaceFirst(
      '$_setupBuildx # v3.12.0',
      '$_setupBuildx # reviewed',
    );

    expect(_workflowPinErrors(actionDrift), isNotEmpty);
    expect(_workflowPinErrors(buildkitDrift), isNotEmpty);
    expect(_workflowPinErrors(setupPlatformDrift), isNotEmpty);
    expect(_workflowPinErrors(lockDrift), isNotEmpty);
    expect(_workflowPinErrors(lockAssertionDrift), isNotEmpty);
    expect(_workflowPinErrors(wrongComment), isNotEmpty);
    expect(_workflowPinErrors(missingComment), isNotEmpty);
    expect(_workflowPinErrors(arbitraryComment), isNotEmpty);
  });

  test('web and admin Dockerfiles lock production build inputs', () {
    expect(_dockerfilePinErrors(webDockerfile), isEmpty);
    expect(_dockerfilePinErrors(adminDockerfile), isEmpty);
  });

  test('Docker contract rejects base and archive checksum drift', () {
    final baseDrift = webDockerfile.replaceFirst(
      _nginxRuntime,
      'nginx:alpine@sha256:$_zeroSha',
    );
    final archiveDrift = adminDockerfile.replaceFirst(
      _flutterArchiveSha,
      _zeroSha,
    );
    final lockAssertionDrift = webDockerfile.replaceFirst(
      _lockInvariant,
      'true',
    );

    expect(_dockerfilePinErrors(baseDrift), isNotEmpty);
    expect(_dockerfilePinErrors(archiveDrift), isNotEmpty);
    expect(_dockerfilePinErrors(lockAssertionDrift), isNotEmpty);
  });

  test('Gradle wrapper distribution is checksum locked', () {
    expect(
      gradleWrapper,
      contains('distributionSha256Sum=$_gradleDistributionSha'),
    );
  });
}
