import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('mission ledger fixture preserves the approved production args', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DpEt13MissionLedgerFixture()));

    final header = tester.widget<DpMissionHeader>(find.byType(DpMissionHeader));
    expect(header.variant, DpMissionHeaderVariant.standard);
    expect(header.status, DpMissionHeaderStatus.active);
    expect(header.eyebrow, '3주차 · 미션 2');
    expect(header.title, 'JPA 연관관계의 주인을 설명하고 안전하게 매핑하기');
    expect(header.why, '이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.');
    expect(header.completionCriterion, '테스트 3개가 통과하면 완료');
    expect(header.progressValue, 0.5);
    expect(header.progressLabel, '이번 주 진행');
  });

  testWidgets('payload fixture keeps exact fields and a controlled edit path', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DpEt13ContextPayloadPreviewFixture()));

    final capsule = tester.widget<DpContextCapsule>(
      find.byType(DpContextCapsule),
    );
    expect(capsule.mode, DpContextCapsuleMode.payloadPreview);
    expect(capsule.fields.map((field) => field.id), [
      'goal',
      'error',
      'review',
    ]);
    expect(
      capsule.fields
          .map(
            (field) => (
              label: field.label,
              value: field.valueSummary,
              source: field.source,
              sensitivity: field.sensitivity,
              inclusion: field.inclusion,
              editable: field.editable,
            ),
          )
          .toList(),
      const [
        (
          label: '학습 목표',
          value: 'Spring 백엔드 취업 준비',
          source: '활성 경로',
          sensitivity: DpContextSensitivity.low,
          inclusion: DpContextInclusion.included,
          editable: true,
        ),
        (
          label: '최근 오류',
          value: 'LazyInitializationException',
          source: '최근 실행',
          sensitivity: DpContextSensitivity.potentiallySensitive,
          inclusion: DpContextInclusion.excluded,
          editable: false,
        ),
        (
          label: '기존 리뷰',
          value: '소유 관계를 다시 확인하세요',
          source: '리뷰 응답',
          sensitivity: DpContextSensitivity.medium,
          inclusion: DpContextInclusion.rejected,
          editable: false,
        ),
      ],
    );
    expect(find.text('포함 1개 · 제외 또는 거절 2개'), findsOneWidget);

    await tester.tap(find.text('전송 전에 수정'));
    await tester.pump();
    expect(find.text('수정 대상 · 학습 목표'), findsOneWidget);
  });
}
