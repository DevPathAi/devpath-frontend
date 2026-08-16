import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tools/et13_evidence.dart' as et13;

void main() {
  test('production capture runner pins Playwright and axe-core', () {
    final packageFile = File('../../tools/et13/package.json');
    final lockFile = File('../../tools/et13/package-lock.json');
    final captureFile = File('../../tools/et13/capture.mjs');
    final externalVerifier = File(
      '../../tools/et13/verify_external_artifact.mjs',
    );

    expect(packageFile.existsSync(), isTrue);
    expect(lockFile.existsSync(), isTrue);
    expect(captureFile.existsSync(), isTrue);
    expect(externalVerifier.existsSync(), isTrue);

    final package = jsonDecode(packageFile.readAsStringSync()) as Map;
    expect(package['private'], isTrue);
    expect(package['dependencies'], {
      'axe-core': '4.10.3',
      'pixelmatch': '7.1.0',
      'playwright': '1.55.0',
      'pngjs': '7.0.0',
    });
    final capture = captureFile.readAsStringSync();
    expect(capture, contains('ET13_READY:'));
    expect(capture, contains('ET13_SOURCE_SHA:'));
    expect(capture, contains('ET13_CAPTURE_SURFACE:'));
    expect(
      capture,
      contains("page.getByLabel(surface, { exact: true })"),
      reason: 'the rendered capture-surface container exposes an aria label',
    );
    expect(
      capture,
      contains("page.getByText(label, { exact: true })"),
      reason:
          'CanvasKit exposes leaf runtime Semantics markers as exact text '
          'nodes rather than aria-label attributes',
    );
    expect(capture, isNot(contains('`[aria-label="\${label}"]`')));
    expect(capture, contains("route.abort('blockedbyclient')"));
    expect(capture, contains("'wcag22aa'"));
    expect(capture, contains('page.screenshot'));
    expect(capture, contains('browser-smoke'));
    expect(capture, contains('pixel-stable across two captures'));
    expect(capture, contains('PNG axes differ from its catalog profile'));
    expect(capture, contains("page.on('requestfailed'"));
    expect(capture, contains("page.on('response'"));
    expect(RegExp(r'assertClean\(\);').allMatches(capture), hasLength(3));
    expect(capture, isNot(contains('updateSnapshot')));

    final verifier = externalVerifier.readAsStringSync();
    expect(verifier, contains('DevPathAi/devpath-gitops'));
    expect(verifier, contains('.github/workflows/mission-spine-candidate.yml'));
    expect(verifier, contains('.github/workflows/et13-baseline-approval.yml'));
    expect(verifier, contains('/attempts/'));
    expect(verifier, contains("createHash('sha256')"));
    expect(verifier, contains("exact(workflow.encoding, 'base64'"));
  });

  test('all release renderers resolve CanvasKit default font offline', () {
    for (final path in [
      '../../apps/web/web/flutter_bootstrap.js',
      '../../apps/admin/web/flutter_bootstrap.js',
      '../../apps/mobile/web/flutter_bootstrap.js',
    ]) {
      final bootstrap = File(path).readAsStringSync();
      expect(
        bootstrap,
        contains("new URLSearchParams(window.location.search).has('fixture')"),
        reason: '$path must scope the offline fallback to evidence routes',
      );
      expect(
        bootstrap,
        contains('fontFallbackBaseUrl:'),
        reason: '$path must configure the engine fallback base',
      );
      expect(
        bootstrap,
        contains('assets/packages/dp_design/fonts/Pretendard-Regular.otf?'),
        reason:
            '$path must resolve CanvasKit fallback requests from the already '
            'hash-pinned local Pretendard bytes',
      );
    }
  });

  test('release producer has strict evidence and baseline schemas', () {
    for (final path in [
      '../../evidence/et13/evidence.schema.json',
      '../../evidence/et13/baseline-approval.schema.json',
      '../../tools/et13_baseline_updater.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }

    final schema =
        jsonDecode(
              File(
                '../../evidence/et13/evidence.schema.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(schema['additionalProperties'], isFalse);
    expect(
      schema['required'],
      containsAll([
        'candidate_spec_sha256',
        'producer_run_id',
        'producer_run_attempt',
        'case_catalog_schema_version',
        'projection_contract_sha256',
        'input_provenance_sha256',
        'input_provenance_file_sha256',
        'result_manifest_sha256',
        'evidence_mode',
      ]),
    );
    expect(schema['required'], isNot(contains('projection_contract_version')));

    final approvalSchema =
        jsonDecode(
              File(
                '../../evidence/et13/baseline-approval.schema.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(approvalSchema['required'], contains('review_candidate_sha256'));
    expect(
      approvalSchema['required'],
      containsAll([
        'approval_workflow_sha256',
        'approval_environment_id',
        'approved_by_id',
        'approval_effective_at',
        'raw_review_head_sha',
        'raw_review_artifact_digest',
      ]),
    );
    expect(
      approvalSchema['required'],
      isNot(contains('candidate_spec_sha256')),
    );
    final approvalProperties = approvalSchema['properties'] as Map;
    expect(approvalProperties['fixture_ids'], {r'$ref': r'#/$defs/fixtureIds'});
    expect(
      (approvalProperties['approval_effective_at'] as Map)['pattern'],
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$',
    );

    final bundle =
        jsonDecode(
              File(
                '../../evidence/et13/release-bundle.v1.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(bundle['schema_version'], 'leva.et13.release-bundle.v1');
    expect((bundle['lanes'] as List), hasLength(2));
  });

  test('release evidence binds the full canonical candidate raw bytes', () {
    final temporary = Directory.systemTemp.createTempSync(
      'et13-canonical-candidate-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final catalog =
        jsonDecode(
              File('../../evidence/et13/catalog.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final generated =
        jsonDecode(
              File(
                '../../evidence/et13/generated/a11y-cases.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    const sourceSha = '1234567890abcdef1234567890abcdef12345678';
    const digest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final binding = <String, Object?>{
      'evidence_mode': 'release_ready',
      'repository': 'DevPathAi/devpath-frontend',
      'source_sha': sourceSha,
      'case_catalog_sha256': sha256
          .convert(
            File(
              '../../evidence/et13/generated/a11y-cases.v1.json',
            ).readAsBytesSync(),
          )
          .toString(),
      'case_catalog_version': 'leva.et13.catalog.v1',
      'case_catalog_schema_version': 'leva.et13.a11y-cases.v1',
      'projection_contract_sha256': catalog['projection_contract_sha256'],
      'fixture_ids': generated['fixture_ids'],
      'case_count': 24,
      'surface_case_counts': generated['surface_case_counts'],
      'capture_surface': 'flutter_web_release_projection',
      'device_evidence': false,
      'input_provenance_sha256': digest,
      'input_provenance_file_sha256': digest,
    };
    final lane = <String, Object?>{
      'repository': binding['repository'],
      'source_sha': sourceSha,
      'path': 'evidence/et13/generated/a11y-cases.v1.json',
      'sha256': binding['case_catalog_sha256'],
      'case_catalog_version': binding['case_catalog_version'],
      'case_catalog_schema_version': binding['case_catalog_schema_version'],
      'projection_contract_sha256': binding['projection_contract_sha256'],
      'fixture_ids': binding['fixture_ids'],
      'case_count': 24,
      'surface_case_counts': binding['surface_case_counts'],
      'capture_surface': binding['capture_surface'],
      'device_evidence': false,
      'evidence_mode': 'release_ready',
      'input_provenance_sha256': digest,
      'input_provenance_file_sha256': digest,
    };
    final fullCandidate = <String, Object?>{
      r'$schema': 'release-manifests/schema-v1.json',
      'schema_version': 1,
      'document_type': 'candidate-spec',
      'release_id': 'ms-test-canonical',
      'created_at': '2099-01-01T00:00:00Z',
      'gitops': <String, Object?>{},
      'services': <String, Object?>{},
      'shared_migration': <String, Object?>{},
      'frontend': {
        'repository': 'DevPathAi/devpath-frontend',
        'source_sha': sourceSha,
      },
      'home': <String, Object?>{},
      'analytics_privacy': <String, Object?>{},
      'ai_release_eval_config': <String, Object?>{},
      'environments': <String, Object?>{},
      'journey_harness': <String, Object?>{},
      'quality_evidence_inputs': {
        'catalogs': {'frontend-automated-a11y': lane},
        'frontend_projection_contract': {
          'schema_version': 'leva.et13.projection-contract.v1',
          'projection_contract_sha256': catalog['projection_contract_sha256'],
          'projection_matrix': catalog['projection_matrix'],
        },
      },
      'rollout': <String, Object?>{},
    };
    final canonical = File('${temporary.path}/candidate-spec.json')
      ..writeAsStringSync(jsonEncode(fullCandidate));
    final canonicalSha = sha256.convert(canonical.readAsBytesSync()).toString();
    expect(
      et13.validateCanonicalReleaseCandidateForLane(
        kind: 'a11y',
        canonicalCandidatePath: canonical.path,
        expectedCandidateSha256: canonicalSha,
        releaseId: 'ms-test-canonical',
        sourceSha: sourceSha,
        laneBinding: binding,
        catalogPath: '../../evidence/et13/catalog.v1.json',
      ),
      canonicalSha,
    );

    final forkBinding = <String, Object?>{
      ...binding,
      'repository': 'UntrustedFork/devpath-frontend',
    };
    expect(
      () => et13.validateCanonicalReleaseCandidateForLane(
        kind: 'a11y',
        canonicalCandidatePath: canonical.path,
        expectedCandidateSha256: canonicalSha,
        releaseId: 'ms-test-canonical',
        sourceSha: sourceSha,
        laneBinding: forkBinding,
        catalogPath: '../../evidence/et13/catalog.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );

    fullCandidate['created_at'] = '2099-01-02T00:00:00Z';
    canonical.writeAsStringSync(jsonEncode(fullCandidate));
    expect(
      () => et13.validateCanonicalReleaseCandidateForLane(
        kind: 'a11y',
        canonicalCandidatePath: canonical.path,
        expectedCandidateSha256: canonicalSha,
        releaseId: 'ms-test-canonical',
        sourceSha: sourceSha,
        laneBinding: binding,
        catalogPath: '../../evidence/et13/catalog.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );

    canonical.writeAsStringSync(jsonEncode(binding));
    expect(
      () => et13.validateCanonicalReleaseCandidateForLane(
        kind: 'a11y',
        canonicalCandidatePath: canonical.path,
        expectedCandidateSha256: sha256
            .convert(canonical.readAsBytesSync())
            .toString(),
        releaseId: 'ms-test-canonical',
        sourceSha: sourceSha,
        laneBinding: binding,
        catalogPath: '../../evidence/et13/catalog.v1.json',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('approved baseline bundle is the exact review-bound 98-file set', () {
    final root = Directory.systemTemp.createTempSync('et13-approved-bundle-');
    addTearDown(() => root.deleteSync(recursive: true));
    final catalogPath = '../../evidence/et13/catalog.v1.json';
    final generatedPath = '../../evidence/et13/generated/visual-cases.v1.json';
    final catalog =
        jsonDecode(File(catalogPath).readAsStringSync())
            as Map<String, dynamic>;
    final generated =
        jsonDecode(File(generatedPath).readAsStringSync())
            as Map<String, dynamic>;
    for (final raw in (generated['cases'] as List).cast<Map>()) {
      final artifact = File.fromUri(
        root.uri.resolve(raw['artifact_path']! as String),
      );
      artifact.parent.createSync(recursive: true);
      artifact.writeAsBytesSync([1]);
    }
    const sourceSha = '1234567890abcdef1234567890abcdef12345678';
    const digest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final review = <String, Object?>{
      'schema_version': 'leva.et13.candidate-spec.v1',
      'kind': 'visual',
      'evidence_mode': 'diagnostic',
      'producer_run_id': 1,
      'producer_run_attempt': 1,
      'repository': 'DevPathAi/devpath-frontend',
      'source_sha': sourceSha,
      'case_catalog_sha256': sha256
          .convert(File(generatedPath).readAsBytesSync())
          .toString(),
      'case_catalog_version': 'leva.et13.catalog.v1',
      'case_catalog_schema_version': 'leva.et13.visual-cases.v1',
      'projection_contract_sha256': catalog['projection_contract_sha256'],
      'fixture_ids': generated['fixture_ids'],
      'case_count': 96,
      'surface_case_counts': generated['surface_case_counts'],
      'capture_surface': 'flutter_web_release_projection',
      'device_evidence': false,
      'input_provenance_sha256': digest,
      'input_provenance_file_sha256': digest,
      'baseline_status': 'pending_external_review',
      'baseline_set_sha256': null,
      'baseline_approval_sha256': null,
    };
    final reviewFile = File.fromUri(
      root.uri.resolve('review-candidate.v1.json'),
    )..writeAsStringSync(jsonEncode(review));
    final approval = <String, Object?>{
      'schema_version': 'leva.et13.baseline-approval.v1',
      'status': 'approved',
      'source_sha': sourceSha,
      'catalog_sha256': sha256
          .convert(File(catalogPath).readAsBytesSync())
          .toString(),
      'case_catalog_sha256': sha256
          .convert(File(generatedPath).readAsBytesSync())
          .toString(),
      'review_candidate_sha256': sha256
          .convert(reviewFile.readAsBytesSync())
          .toString(),
      'fixture_ids': generated['fixture_ids'],
      'case_count': 96,
      'candidate_set_sha256': et13.visualArtifactSetSha(
        root.path,
        generatedCatalogPath: generatedPath,
      ),
      'approval_repository': 'DevPathAi/devpath-frontend',
      'approval_workflow_path': '.github/workflows/et13-baseline-approval.yml',
      'approval_workflow_sha256': sha256
          .convert(
            File(
              '../../.github/workflows/et13-baseline-approval.yml',
            ).readAsBytesSync(),
          )
          .toString(),
      'approval_run_id': 12,
      'approval_run_attempt': 1,
      'approval_head_sha': sourceSha,
      'approval_environment': 'et13-baseline-approval',
      'approval_environment_id': 34,
      'approved_by_id': 56,
      'approved_by': 'external-reviewer',
      'approval_effective_at': '2099-01-01T00:00:00Z',
      'raw_review_workflow_sha256': sha256
          .convert(
            File('../../.github/workflows/et13-evidence.yml').readAsBytesSync(),
          )
          .toString(),
      'raw_review_run_id': 7,
      'raw_review_run_attempt': 2,
      'raw_review_head_sha': sourceSha,
      'raw_review_artifact_id': 89,
      'raw_review_artifact_name': 'et13-unsealed-raw-review-run-7-attempt-2',
      'raw_review_artifact_digest': 'sha256:$digest',
    };
    final approvalFile = File.fromUri(
      root.uri.resolve('baseline-approval.v1.json'),
    )..writeAsStringSync(jsonEncode(approval));
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      returnsNormally,
    );
    final authentication = et13.buildBaselineAuthentication(
      releaseId: 'ms-20260816-et13',
      sourceSha: sourceSha,
      baselineRoot: root.path,
      approvalPath: approvalFile.path,
      runId: 12,
      runAttempt: 1,
      artifactId: 90,
      artifactName:
          'ms-20260816-et13-frontend-visual-approved-baseline-run-12-attempt-1',
      artifactArchiveSha256: digest,
      workflowSha256: approval['approval_workflow_sha256']! as String,
      catalogPath: catalogPath,
      generatedCatalogPath: generatedPath,
      approvalWorkflowPath:
          '../../.github/workflows/et13-baseline-approval.yml',
      rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
    );
    expect(authentication, {
      'release_id': 'ms-20260816-et13',
      'repository': 'DevPathAi/devpath-frontend',
      'workflow_path': '.github/workflows/et13-baseline-approval.yml',
      'workflow_sha256': approval['approval_workflow_sha256'],
      'run_id': 12,
      'run_attempt': 1,
      'head_sha': sourceSha,
      'artifact_id': 90,
      'artifact_name':
          'ms-20260816-et13-frontend-visual-approved-baseline-run-12-attempt-1',
      'artifact_archive_sha256': digest,
      'approval_document_sha256': sha256
          .convert(approvalFile.readAsBytesSync())
          .toString(),
      'approval_environment': 'et13-baseline-approval',
      'approval_environment_id': 34,
      'approved_by_id': 56,
      'approved_by': 'external-reviewer',
      'approval_effective_at': '2099-01-01T00:00:00Z',
    });

    review['repository'] = 'UntrustedFork/devpath-frontend';
    reviewFile.writeAsStringSync(jsonEncode(review));
    approval['review_candidate_sha256'] = sha256
        .convert(reviewFile.readAsBytesSync())
        .toString();
    approvalFile.writeAsStringSync(jsonEncode(approval));
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      throwsA(isA<FormatException>()),
    );
    review['repository'] = 'DevPathAi/devpath-frontend';
    reviewFile.writeAsStringSync(jsonEncode(review));
    approval['review_candidate_sha256'] = sha256
        .convert(reviewFile.readAsBytesSync())
        .toString();
    approvalFile.writeAsStringSync(jsonEncode(approval));

    approval['approval_effective_at'] = '2099-01-01T09:00:00+09:00';
    approvalFile.writeAsStringSync(jsonEncode(approval));
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      throwsA(isA<FormatException>()),
    );
    approval['approval_effective_at'] = '2099-01-01T00:00:00Z';
    approvalFile.writeAsStringSync(jsonEncode(approval));

    approval['approved_by'] = 'not a github login';
    approvalFile.writeAsStringSync(jsonEncode(approval));
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      throwsA(isA<FormatException>()),
    );
    approval['approved_by'] = 'external-reviewer';
    approval['approval_environment'] = 'unprotected-environment';
    approvalFile.writeAsStringSync(jsonEncode(approval));
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      throwsA(isA<FormatException>()),
    );
    approval['approval_environment'] = 'et13-baseline-approval';
    approvalFile.writeAsStringSync(jsonEncode(approval));

    File.fromUri(root.uri.resolve('extra.json')).writeAsStringSync('{}');
    expect(
      () => et13.validateBaselineApproval(
        approvalPath: approvalFile.path,
        baselineRoot: root.path,
        reviewCandidatePath: reviewFile.path,
        requireExactBundle: true,
        catalogPath: catalogPath,
        generatedCatalogPath: generatedPath,
        approvalWorkflowPath:
            '../../.github/workflows/et13-baseline-approval.yml',
        rawReviewWorkflowPath: '../../.github/workflows/et13-evidence.yml',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('candidate and provenance identity cannot drift together', () {
    const digest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final candidate = <String, Object?>{
      'source_sha': '1234567890abcdef1234567890abcdef12345678',
      'input_provenance_sha256': digest,
    };
    final provenance = <String, Object?>{...candidate};
    expect(
      () => et13.validateCandidateProvenanceIdentity(
        candidate: candidate,
        provenance: provenance,
      ),
      returnsNormally,
    );
    provenance['source_sha'] = 'abcdef1234567890abcdef1234567890abcdef12';
    expect(
      () => et13.validateCandidateProvenanceIdentity(
        candidate: candidate,
        provenance: provenance,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('atomic visual and a11y bindings share run identity', () {
    final visual = <String, Object?>{
      'evidence_mode': 'release_ready',
      'producer_run_id': 41,
      'producer_run_attempt': 2,
      'repository': 'DevPathAi/devpath-frontend',
      'source_sha': '1234567890abcdef1234567890abcdef12345678',
    };
    final a11y = <String, Object?>{...visual};
    expect(
      () => et13.validateAtomicLaneBindingIdentity(
        visualBinding: visual,
        a11yBinding: a11y,
      ),
      returnsNormally,
    );
    a11y['producer_run_attempt'] = 3;
    expect(
      () => et13.validateAtomicLaneBindingIdentity(
        visualBinding: visual,
        a11yBinding: a11y,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('sealable package layout rejects extra directories and links', () {
    final root = Directory.systemTemp.createTempSync('et13-package-layout-');
    addTearDown(() => root.deleteSync(recursive: true));
    for (final path in [
      'evidence.json',
      'evidence/et13/generated/visual-cases.v1.json',
      'artifacts/et13/provenance.v1.json',
      'artifacts/et13/visual-manifest.v1.json',
    ]) {
      final file = File.fromUri(root.uri.resolve(path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{}');
    }
    expect(
      () => et13.validateReleasePackageLayout(
        kind: 'visual',
        packageRoot: root.path,
      ),
      returnsNormally,
    );
    final extra = Directory.fromUri(root.uri.resolve('unexpected/'))
      ..createSync();
    expect(
      () => et13.validateReleasePackageLayout(
        kind: 'visual',
        packageRoot: root.path,
      ),
      throwsA(isA<FormatException>()),
    );
    extra.deleteSync();

    final link = Link.fromUri(root.uri.resolve('unexpected-link'));
    try {
      link.createSync(File.fromUri(root.uri.resolve('evidence.json')).path);
      expect(
        () => et13.validateReleasePackageLayout(
          kind: 'visual',
          packageRoot: root.path,
        ),
        throwsA(isA<FormatException>()),
      );
      link.deleteSync();
    } on FileSystemException {
      // Windows installations without Developer Mode cannot create symlinks;
      // the same test exercises this branch on the pinned Linux CI runner.
    }
  });

  test('source identity rejects untracked files in an isolated git repo', () {
    final root = Directory.systemTemp.createTempSync('et13-clean-source-');
    addTearDown(() => root.deleteSync(recursive: true));
    ProcessResult git(List<String> arguments) => Process.runSync(
      'git',
      arguments,
      workingDirectory: root.path,
      runInShell: false,
    );
    expect(git(['init']).exitCode, 0);
    File.fromUri(root.uri.resolve('source.txt')).writeAsStringSync('bound\n');
    expect(git(['add', 'source.txt']).exitCode, 0);
    expect(
      git([
        '-c',
        'user.name=ET13 Contract',
        '-c',
        'user.email=et13@example.invalid',
        'commit',
        '-m',
        'fixture',
      ]).exitCode,
      0,
    );
    final head = (git(['rev-parse', 'HEAD']).stdout as String).trim();
    expect(
      () => et13.validateSourceTreeClean(head, workingDirectory: root.path),
      returnsNormally,
    );
    File.fromUri(root.uri.resolve('untracked.txt')).writeAsStringSync('no\n');
    expect(
      () => et13.validateSourceTreeClean(head, workingDirectory: root.path),
      throwsA(isA<FormatException>()),
    );
  });

  test('single atomic workflow separates sealable lanes and raw review bytes', () {
    final workflow = File(
      '../../.github/workflows/et13-evidence.yml',
    ).readAsStringSync();
    expect(workflow, contains('workflow_dispatch:'));
    expect(
      workflow,
      contains('mcr.microsoft.com/playwright:v1.55.0-noble@sha256:'),
    );
    expect(workflow, contains('--network none'));
    expect(
      workflow,
      contains(
        r'-frontend-visual-run-${{ github.run_id }}-attempt-${{ github.run_attempt }}',
      ),
    );
    expect(
      workflow,
      contains(
        r'-frontend-automated-a11y-run-${{ github.run_id }}-attempt-${{ github.run_attempt }}',
      ),
    );
    expect(workflow, contains(r'"${ET13_ROOT}/stage/${lane}/evidence.json"'));
    expect(
      workflow,
      contains(
        r'"${ET13_ROOT}/stage/${lane}/evidence/et13/generated/${lane}-cases.v1.json"',
      ),
    );
    expect(
      workflow,
      contains(
        r'"${ET13_ROOT}/stage/${lane}/artifacts/et13/provenance.v1.json"',
      ),
    );
    expect(
      workflow,
      contains(
        r'"${ET13_ROOT}/stage/${lane}/artifacts/et13/${lane}-manifest.v1.json"',
      ),
    );
    expect(workflow, contains('--no-web-resources-cdn'));
    expect(workflow, contains('--no-tree-shake-icons'));
    expect(workflow, contains('validate-package'));
    expect(workflow, contains('validate-release-inputs'));
    expect(
      workflow,
      contains(
        'actions/create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1',
      ),
    );
    expect(
      workflow,
      contains(
        'actions/download-artifact@018cc2cf5baa6db3ef3c5f8a56943fffe632ef53',
      ),
    );
    expect(workflow, contains('--canonical-candidate='));
    expect(workflow, contains('review-candidate.v1.json'));
    expect(workflow, contains('release-binding.v1.json'));
    expect(workflow, contains('Hard-verify exact external artifact archives'));
    expect(workflow, contains('candidate_artifact_archive_sha256'));
    expect(workflow, contains('baseline_artifact_archive_sha256'));
    expect(workflow, contains('sha256sum --check --strict'));
    expect(workflow, contains('with zipfile.ZipFile(archive)'));
    expect(workflow, contains('duplicate external archive entry'));
    expect(workflow, contains('diff --recursive --brief'));
    for (final option in [
      '--mode="\${EVIDENCE_MODE}"',
      '--baseline-run-id="\${BASELINE_RUN_ID}"',
      '--baseline-run-attempt="\${BASELINE_RUN_ATTEMPT}"',
      '--baseline-artifact-id="\${BASELINE_ARTIFACT_ID}"',
      '--baseline-artifact-name="\${BASELINE_ARTIFACT_NAME}"',
      '--baseline-artifact-archive-sha256="\${BASELINE_ARTIFACT_ARCHIVE_SHA256}"',
      '--baseline-workflow-sha256="\${BASELINE_WORKFLOW_SHA256}"',
    ]) {
      expect(workflow, contains(option), reason: option);
    }
    expect(
      File('../../tools/et13_evidence.dart').readAsStringSync(),
      contains("'baseline_authentication'"),
    );
    expect(
      workflow,
      contains(r'[[ "${CANDIDATE_SPEC_SHA256}" =~ ^[0-9a-f]{64}$ ]]'),
    );
    expect(workflow, isNot(contains('evidence/et13/baselines/approved')));
    expect(workflow, isNot(contains('et13_baseline_updater.dart candidate')));
    expect(workflow, isNot(contains('update-snapshot')));
  });

  test(
    'external baseline updater is incapable of self-approval in CI',
    () async {
      final result = await Process.run(
        'dart',
        [
          'run',
          'tools/et13_baseline_updater.dart',
          '--candidate-root=missing-candidate',
          '--review-candidate=missing-review-candidate.json',
          '--approval=missing-approval.json',
          '--destination=missing-destination',
        ],
        workingDirectory: '../..',
        environment: const {'CI': 'true'},
        includeParentEnvironment: true,
        runInShell: true,
      );
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr,
        contains('external baseline updater is disabled in CI'),
      );
    },
  );
}
