import 'package:flutter/material.dart';

import '../mission/dp_context_capsule.dart';
import '../mission/dp_mission_header.dart';
import '../theme/dp_spacing.dart';

/// Canonical ET13 mission-ledger production component projection.
class DpEt13MissionLedgerFixture extends StatelessWidget {
  const DpEt13MissionLedgerFixture({super.key});

  @override
  Widget build(BuildContext context) => const DpMissionHeader(
    eyebrow: '3주차 · 미션 2',
    title: 'JPA 연관관계의 주인을 설명하고 안전하게 매핑하기',
    why: '이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.',
    completionCriterion: '테스트 3개가 통과하면 완료',
    progressValue: 0.5,
    progressLabel: '이번 주 진행',
    variant: DpMissionHeaderVariant.standard,
    status: DpMissionHeaderStatus.active,
  );
}

/// Canonical ET13 context payload-preview production component projection.
///
/// The edit action is controlled: the capsule returns the selected field ID,
/// and this owner records and renders that intent without mutating approval or
/// inclusion state.
class DpEt13ContextPayloadPreviewFixture extends StatefulWidget {
  const DpEt13ContextPayloadPreviewFixture({super.key});

  @override
  State<DpEt13ContextPayloadPreviewFixture> createState() =>
      _DpEt13ContextPayloadPreviewFixtureState();
}

class _DpEt13ContextPayloadPreviewFixtureState
    extends State<DpEt13ContextPayloadPreviewFixture> {
  static const _fields = [
    DpContextFieldViewModel(
      id: 'goal',
      label: '학습 목표',
      valueSummary: 'Spring 백엔드 취업 준비',
      source: '활성 경로',
      sensitivity: DpContextSensitivity.low,
      inclusion: DpContextInclusion.included,
      editable: true,
    ),
    DpContextFieldViewModel(
      id: 'error',
      label: '최근 오류',
      valueSummary: 'LazyInitializationException',
      source: '최근 실행',
      sensitivity: DpContextSensitivity.potentiallySensitive,
      inclusion: DpContextInclusion.excluded,
    ),
    DpContextFieldViewModel(
      id: 'review',
      label: '기존 리뷰',
      valueSummary: '소유 관계를 다시 확인하세요',
      source: '리뷰 응답',
      sensitivity: DpContextSensitivity.medium,
      inclusion: DpContextInclusion.rejected,
    ),
  ];

  String? _editedFieldId;

  @override
  Widget build(BuildContext context) {
    final edited = _fields.where((field) => field.id == _editedFieldId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpContextCapsule(
          fields: _fields,
          mode: DpContextCapsuleMode.payloadPreview,
          onFieldEditRequested: (fieldId) {
            setState(() => _editedFieldId = fieldId);
          },
        ),
        if (edited.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text('수정 대상 · ${edited.single.label}'),
          ),
        ],
      ],
    );
  }
}
