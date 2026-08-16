import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/support/data/support_request.dart';
import '../features/support/presentation/support_page.dart';

export '../features/dashboard/presentation/dashboard_page.dart'
    show AdminKpiDashboardProjection;
export '../features/support/presentation/support_page.dart'
    show AdminSupportDetailProjection;

class Et13AdminEvidenceApp extends StatelessWidget {
  const Et13AdminEvidenceApp({
    super.key,
    required this.fixtureId,
    required this.brightness,
    required this.textScale,
    required this.sourceSha,
    this.waitForFonts = waitForEt13EvidenceFonts,
  });

  static const fixtureIds = <String>[
    'admin-kpi-dashboard',
    'admin-support-long-wire',
  ];

  final String fixtureId;
  final Brightness brightness;
  final double textScale;
  final String sourceSha;
  final Et13ReadyWaiter waitForFonts;

  @override
  Widget build(BuildContext context) => DpEt13EvidenceFrame(
    fixtureId: fixtureId,
    brightness: brightness,
    textScale: textScale,
    sourceSha: sourceSha,
    waitForFonts: waitForFonts,
    child: buildEt13AdminFixture(fixtureId),
  );
}

Widget buildEt13AdminFixture(String fixtureId) => switch (fixtureId) {
  'admin-kpi-dashboard' => const AdminKpiDashboardProjection(
    stats: {'dau': 1280, 'newUsers': 64, 'openReports': 2, 'aiCalls': 9421},
  ),
  'admin-support-long-wire' => const _Et13AdminSupportFixture(),
  _ => throw ArgumentError.value(
    fixtureId,
    'fixtureId',
    'unknown admin ET13 fixture',
  ),
};

class _Et13AdminSupportFixture extends StatefulWidget {
  const _Et13AdminSupportFixture();

  @override
  State<_Et13AdminSupportFixture> createState() =>
      _Et13AdminSupportFixtureState();
}

class _Et13AdminSupportFixtureState extends State<_Et13AdminSupportFixture> {
  static const _unknownWire =
      'VENDOR_ESCALATED_WITH_EXTERNAL_REVIEW_PHASE_1234567';
  static const _longKorean = '운영자가 실제로 확인해야 하는 매우 긴 한국어 제목과 설명이 여러 줄로 이어집니다';
  static const _detail = SupportRequestDetail(
    id: 77,
    type: 'ERROR',
    title: _longKorean,
    body: '$_longKorean $_longKorean',
    status: _unknownWire,
    pagePath: '/diagnostics/path/with/forty-seven-character-segment',
    appVersion: 'et13-release-candidate+20260816',
    viewport: '320x900@1',
    userAgent: 'Pinned Chromium 140.0.7339.16 / linux-amd64',
    errorCode: _unknownWire,
    traceId: _unknownWire,
    occurredAt: '2026-08-16T12:34:56Z',
    reporterId: 42,
    adminNote: '외부 상태 원문을 유지합니다.',
    failures: [
      SupportFailure(
        seq: 1,
        method: 'POST',
        path: '/api/diagnostics/very-long-request-path-for-operator',
        occurredAt: '2026-08-16T12:34:56Z',
        statusCode: 503,
        errorCode: _unknownWire,
        traceId: _unknownWire,
        message: _longKorean,
      ),
    ],
  );

  late final TextEditingController _note = TextEditingController(
    text: _detail.adminNote,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AlertDialog(
      title: const Text('#77 $_longKorean'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: AdminSupportDetailProjection(
            detail: _detail,
            noteController: _note,
          ),
        ),
      ),
      actions: const [TextButton(onPressed: null, child: Text('닫기'))],
    ),
  );
}
