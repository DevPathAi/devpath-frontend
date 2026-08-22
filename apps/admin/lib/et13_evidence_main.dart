import 'package:dp_design/dp_design.dart';
import 'package:flutter/widgets.dart';

import 'src/evidence/et13_admin_evidence_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  const sourceSha = String.fromEnvironment('ET13_SOURCE_SHA');
  final config = DpEt13EvidenceLaunchConfig.fromUri(
    uri: Uri.base,
    allowedFixtureIds: Et13AdminEvidenceApp.fixtureIds,
    sourceSha: sourceSha,
  );
  runApp(
    Et13AdminEvidenceApp(
      fixtureId: config.fixtureId,
      brightness: config.brightness,
      textScale: config.textScale,
      sourceSha: config.sourceSha,
    ),
  );
}
