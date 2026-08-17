import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// Mission/context header projection shared by the live contextual Mentor and
/// the ET13 browser-distribution fixture.
class WebMentorContextProjection extends StatelessWidget {
  const WebMentorContextProjection({
    super.key,
    required this.mission,
    required this.task,
    required this.fields,
    required this.capsuleMode,
    required this.capsuleStatus,
    this.statusMessage,
    this.disclosureFocusNode,
    this.onDisclosurePressed,
    this.onFieldEditRequested,
    this.onRetry,
  });

  final CurrentMission? mission;
  final WeeklyTask? task;
  final List<DpContextFieldViewModel> fields;
  final DpContextCapsuleMode capsuleMode;
  final DpContextCapsuleStatus capsuleStatus;
  final String? statusMessage;
  final FocusNode? disclosureFocusNode;
  final VoidCallback? onDisclosurePressed;
  final ValueChanged<String>? onFieldEditRequested;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.48,
    ),
    child: SingleChildScrollView(
      key: const ValueKey('mentor-context-scroll'),
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DpMissionHeader(
            eyebrow: mission?.weekNum == null
                ? '오늘의 미션 · AI 멘토'
                : '${mission!.weekNum}주차 · 오늘의 미션 · AI 멘토',
            title: task?.title ?? '현재 미션 질문',
            why: '현재 학습 근거를 직접 확인한 뒤 필요한 만큼만 질문에 보냅니다.',
            completionCriterion: '답변을 확인하고 실습 또는 리뷰로 돌아갑니다',
            progressValue: task?.completed == true ? 1 : 0,
            progressLabel: '현재 미션 진행 상태',
            variant: DpMissionHeaderVariant.compact,
            status: task?.completed == true
                ? DpMissionHeaderStatus.completed
                : DpMissionHeaderStatus.active,
          ),
          const SizedBox(height: DpSpacing.md),
          DpContextCapsule(
            name: '질문에 보낼 학습 맥락',
            fields: fields,
            mode: capsuleMode,
            status: capsuleStatus,
            statusMessage: statusMessage,
            disclosureFocusNode: disclosureFocusNode,
            onDisclosurePressed: onDisclosurePressed,
            onFieldEditRequested: onFieldEditRequested,
            onRetry: onRetry,
          ),
        ],
      ),
    ),
  );
}
