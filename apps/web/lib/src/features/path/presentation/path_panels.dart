import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 시안 `path` 의 `.cols` 좌측 — 「N주 계획」 표.
///
/// 옛 `ExpansionTile` 목록(「완료한 주차」·「앞으로의 주차」)을 대체한다. 접혀
/// 있던 `goalDescription` 이 「목표」 칼럼으로 올라오므로 정보가 줄지 않는다.
class PathWeeksPanel extends StatelessWidget {
  const PathWeeksPanel({
    super.key,
    required this.plan,
    required this.currentWeek,
    required this.onOpenWeek,
  });

  final LearningPath plan;
  final int? currentWeek;

  /// null 이면 제목을 링크로 만들지 않는다 — 주차 상세 라우트가 아직 없으므로
  /// 빈 콜백으로 링크처럼 보이게 하지 않는다.
  final ValueChanged<PathMilestone>? onOpenWeek;

  @override
  Widget build(BuildContext context) {
    // 시안 `.hide-n` — 좁은 폭에서 감추는 칼럼. 칼럼과 셀을 같은 조건으로 뺀다
    // (`DpWebTable` 의 assert 가 개수 불일치를 배치 전에 잡는다).
    final compact = context.windowClass == DpWindowClass.compact;
    final onOpen = onOpenWeek;

    return DpPanel(
      title: DpPanelTitle('${plan.totalWeeks}주 계획'),
      child: DpWebTable(
        columns: [
          const (label: '주차', width: 56, numeric: true),
          const (label: '주제', width: null, numeric: false),
          if (!compact) const (label: '목표', width: null, numeric: false),
          const (label: '진행', width: 88, numeric: false),
        ],
        empty: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: DpSpacing.xl,
            horizontal: DpSpacing.lg,
          ),
          child: Text('아직 주차 계획이 없어요'),
        ),
        rows: [
          for (final milestone in plan.milestones)
            (
              cells: [
                Text('${milestone.weekNum}'),
                _topic(context, milestone, onOpen),
                if (!compact) _goal(context, milestone),
                _progress(milestone),
              ],
              onTap: onOpen == null ? null : () => onOpen(milestone),
            ),
        ],
      ),
    );
  }

  Widget _topic(
    BuildContext context,
    PathMilestone milestone,
    ValueChanged<PathMilestone>? onOpen,
  ) {
    final isCurrent = milestone.weekNum == currentWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpen == null)
          Text(
            milestone.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.dpColors.textPrimary,
            ),
          )
        else
          DpLink.title(text: milestone.title, onTap: () => onOpen(milestone)),
        if (isCurrent) ...[
          const SizedBox(height: DpSpacing.xs),
          const DpStatusText(text: '● 진행 중', tone: DpStatusTone.current),
        ],
      ],
    );
  }

  /// 목표 칼럼 — 시안 `.ex` 처럼 두 줄이다. 옛 `ExpansionTile` 이 접어 두었던
  /// `goalDescription` 과 `expectedOutcome` 을 **둘 다** 올려, 표로 바꾸면서
  /// 비현재 주차의 기대 결과가 사라지지 않게 한다(기능 보존 규칙).
  Widget _goal(BuildContext context, PathMilestone milestone) {
    final c = context.dpColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          milestone.goalDescription,
          style: TextStyle(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          milestone.expectedOutcome,
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _progress(PathMilestone milestone) {
    final tasks = milestone.tasks;
    if (tasks.isEmpty) {
      return const DpStatusText(text: '대기', tone: DpStatusTone.idle);
    }
    final done = tasks.where((task) => task.completed).length;
    return Text('$done / ${tasks.length}');
  }
}

/// 시안 `path` 의 `.side` 「진단 요약」 — 강점·보강·트랙.
class PathDiagnosisPanel extends StatelessWidget {
  const PathDiagnosisPanel({super.key, required this.plan});

  final LearningPath plan;

  @override
  Widget build(BuildContext context) {
    final diagnosis = plan.diagnosis;
    return DpPanel(
      title: const DpPanelTitle('진단 요약'),
      child: DpKeyValues(
        entries: [
          if (diagnosis != null) ...[
            if (diagnosis.strengthConcepts.isNotEmpty)
              (key: '강점', value: _tags(diagnosis.strengthConcepts)),
            if (diagnosis.weaknessConcepts.isNotEmpty)
              (key: '보강', value: _tags(diagnosis.weaknessConcepts)),
            (key: '현재 수준', value: Text(diagnosis.diagnosedLevel)),
          ],
          // 트랙 문구의 SSoT 는 `DpLearningLabels` 다 — wire 값이 제품 문구로 새지 않는다.
          (key: '트랙', value: Text(DpLearningLabels.track(plan.track))),
          (key: '주차 수', value: Text('${plan.totalWeeks}주')),
        ],
      ),
    );
  }

  Widget _tags(List<String> concepts) => Wrap(
    alignment: WrapAlignment.end,
    spacing: DpSpacing.xs,
    runSpacing: DpSpacing.xs,
    children: [for (final c in concepts) DpTag(label: c)],
  );
}

/// 시안 `path` 의 `.side` 「N주차를 끝내면」 — 완료 근거 + 다음 잠금 해제.
class PathWeekOutcomePanel extends StatelessWidget {
  const PathWeekOutcomePanel({
    super.key,
    required this.milestone,
    required this.nextUnlock,
  });

  /// 현재 주차의 경로 상세. null 이면 완료 근거 없이 [nextUnlock] 만 말한다 —
  /// 「다음에 무엇이 열리는가」는 서버 미션만으로 계산되므로 경로 상세가 아직
  /// 없거나 현재 미션과 맞지 않다는 이유로 지우지 않는다.
  final PathMilestone? milestone;

  /// 다음에 열리는 것. 문장을 계산하는 책임은 호출부에 둔다.
  final String nextUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final week = milestone;
    return DpPanel(
      title: DpPanelTitle(
        week == null ? '다음에 열리는 것' : '${week.weekNum}주차를 끝내면',
      ),
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (week != null) ...[
            Text(week.expectedOutcome, style: text.bodyMedium),
            const SizedBox(height: DpSpacing.sm),
          ],
          Text(
            '다음 잠금 해제 · $nextUnlock',
            style: text.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 옛 `ExpansionTile` 「경로 설계 근거」. 시안에는 없지만 `plan.rationale` 을
/// 잃지 않기 위해 사이드 패널로 남긴다(기능 보존 규칙).
class PathRationalePanel extends StatelessWidget {
  const PathRationalePanel({super.key, required this.plan});

  final LearningPath plan;

  @override
  Widget build(BuildContext context) => DpPanel(
    title: const DpPanelTitle('경로 설계 근거'),
    padding: const EdgeInsets.symmetric(
      vertical: DpSpacing.md,
      horizontal: DpSpacing.lg,
    ),
    child: Text(
      plan.rationale,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.dpColors.textSecondary),
    ),
  );
}
