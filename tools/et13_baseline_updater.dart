import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'et13_evidence.dart' as evidence;

Never _fail(String message) => throw StateError(message);

Map<String, String> _options(Iterable<String> arguments) => <String, String>{
  for (final argument in arguments)
    if (argument.startsWith('--') && argument.contains('='))
      argument.substring(2, argument.indexOf('=')): argument.substring(
        argument.indexOf('=') + 1,
      ),
};

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) _fail('missing --$name');
  return value;
}

Map<String, Object?> _readObject(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('missing JSON file: $path');
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) _fail('$path must be a JSON object');
  return decoded;
}

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

void _exact(Object? actual, Object? expected, String name) {
  if (jsonEncode(actual) != jsonEncode(expected)) {
    _fail('$name does not match the approved ET13 contract');
  }
}

void _validateCandidate({
  required Map<String, Object?> candidate,
  required String reviewCandidatePath,
  required String candidateRoot,
  required Map<String, Object?> approval,
}) {
  const expectedKeys = <String>{
    'schema_version',
    'kind',
    'evidence_mode',
    'producer_run_id',
    'producer_run_attempt',
    'repository',
    'source_sha',
    'case_catalog_sha256',
    'case_catalog_version',
    'case_catalog_schema_version',
    'projection_contract_sha256',
    'fixture_ids',
    'case_count',
    'surface_case_counts',
    'capture_surface',
    'device_evidence',
    'input_provenance_sha256',
    'input_provenance_file_sha256',
    'baseline_status',
    'baseline_set_sha256',
    'baseline_approval_sha256',
  };
  if (candidate.keys.toSet().length != expectedKeys.length ||
      !candidate.keys.toSet().containsAll(expectedKeys)) {
    _fail('candidate spec must contain the exact visual candidate key set');
  }
  final catalog = evidence.validateCatalog();
  final generatedPath = 'evidence/et13/generated/visual-cases.v1.json';
  final generated = _readObject(generatedPath);
  for (final entry in <String, Object?>{
    'schema_version': 'leva.et13.candidate-spec.v1',
    'kind': 'visual',
    'evidence_mode': 'diagnostic',
    'repository': 'DevPathAi/devpath-frontend',
    'source_sha': approval['source_sha'],
    'case_catalog_sha256': _sha256(generatedPath),
    'case_catalog_version': 'leva.et13.catalog.v1',
    'case_catalog_schema_version': 'leva.et13.visual-cases.v1',
    'projection_contract_sha256': catalog['projection_contract_sha256'],
    'fixture_ids': generated['fixture_ids'],
    'case_count': 96,
    'surface_case_counts': generated['surface_case_counts'],
    'capture_surface': 'flutter_web_release_projection',
    'device_evidence': false,
    'baseline_status': 'pending_external_review',
    'baseline_set_sha256': null,
    'baseline_approval_sha256': null,
  }.entries) {
    _exact(candidate[entry.key], entry.value, 'candidate.${entry.key}');
  }
  for (final key in ['producer_run_id', 'producer_run_attempt']) {
    final value = candidate[key];
    if (value is! int || value < 1) _fail('candidate.$key must be positive');
  }
  for (final key in [
    'input_provenance_sha256',
    'input_provenance_file_sha256',
  ]) {
    if (candidate[key] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(candidate[key]! as String)) {
      _fail('candidate.$key must be a SHA-256 digest');
    }
  }
  _exact(
    approval['review_candidate_sha256'],
    _sha256(reviewCandidatePath),
    'approval.review_candidate_sha256',
  );
  _exact(
    approval['candidate_set_sha256'],
    evidence.visualArtifactSetSha(candidateRoot),
    'approval.candidate_set_sha256',
  );
}

void installApprovedBaseline({
  required String candidateRoot,
  required String reviewCandidatePath,
  required String approvalPath,
  required String destinationPath,
}) {
  if ((Platform.environment['CI'] ?? '').isNotEmpty ||
      (Platform.environment['GITHUB_ACTIONS'] ?? '').isNotEmpty) {
    _fail('the external baseline updater is disabled in CI');
  }
  final candidateDirectory = Directory(candidateRoot).absolute;
  final destination = Directory(destinationPath).absolute;
  if (!candidateDirectory.existsSync()) _fail('candidate root is missing');
  if (destination.existsSync()) {
    _fail('baseline destination already exists; updates never overwrite');
  }
  final approval = evidence.validateBaselineApproval(
    approvalPath: approvalPath,
    baselineRoot: candidateDirectory.path,
    reviewCandidatePath: reviewCandidatePath,
  );
  final candidate = _readObject(reviewCandidatePath);
  _validateCandidate(
    candidate: candidate,
    reviewCandidatePath: reviewCandidatePath,
    candidateRoot: candidateDirectory.path,
    approval: approval,
  );

  final generated = _readObject('evidence/et13/generated/visual-cases.v1.json');
  final cases = generated['cases'];
  if (cases is! List<Object?> || cases.length != 96) {
    _fail('visual generated catalog must contain exactly 96 cases');
  }
  final temporary = Directory('${destination.path}.tmp-${pid}');
  if (temporary.existsSync()) _fail('temporary baseline path already exists');
  destination.parent.createSync(recursive: true);
  temporary.createSync();
  try {
    for (final raw in cases) {
      if (raw is! Map<String, Object?> || raw['artifact_path'] is! String) {
        _fail('visual generated case has an invalid artifact path');
      }
      final relative = raw['artifact_path']! as String;
      final source = File.fromUri(candidateDirectory.uri.resolve(relative));
      final target = File.fromUri(temporary.uri.resolve(relative));
      target.parent.createSync(recursive: true);
      source.copySync(target.path);
    }
    File(approvalPath).copySync(
      File.fromUri(temporary.uri.resolve('baseline-approval.v1.json')).path,
    );
    File(reviewCandidatePath).copySync(
      File.fromUri(temporary.uri.resolve('review-candidate.v1.json')).path,
    );
    _exact(
      evidence.visualArtifactSetSha(temporary.path),
      approval['candidate_set_sha256'],
      'installed baseline set',
    );
    evidence.validateBaselineApproval(
      approvalPath: File.fromUri(
        temporary.uri.resolve('baseline-approval.v1.json'),
      ).path,
      baselineRoot: temporary.path,
      reviewCandidatePath: File.fromUri(
        temporary.uri.resolve('review-candidate.v1.json'),
      ).path,
      requireExactBundle: true,
    );
    temporary.renameSync(destination.path);
  } catch (_) {
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    rethrow;
  }
}

void _usage() {
  stderr.writeln(
    'Usage: dart run tools/et13_baseline_updater.dart '
    '--candidate-root=<path> --review-candidate=<path> --approval=<path> '
    '--destination=<new-path>',
  );
}

void main(List<String> arguments) {
  try {
    final parsed = _options(arguments);
    installApprovedBaseline(
      candidateRoot: _required(parsed, 'candidate-root'),
      reviewCandidatePath: _required(parsed, 'review-candidate'),
      approvalPath: _required(parsed, 'approval'),
      destinationPath: _required(parsed, 'destination'),
    );
    stdout.writeln('ET13 approved visual baseline installed');
  } on Object catch (error) {
    _usage();
    stderr.writeln('ET13 baseline update refused: $error');
    exitCode = 1;
  }
}
