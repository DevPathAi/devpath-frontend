import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 시안 `today` 의 `.cols` 좌측 — 「이번 주 과제」 표.
///
/// 데이터는 `CurrentMission.tasks` 뿐이다(오늘 화면은 `LearningPath` 를 읽지
/// 않는다). 시안의 과제 설명(`.ex`)에 해당하는 필드가 `WeeklyTask` 에 없어 그
/// 줄은 그리지 않는다 — 새 API 를 만들지 않는다.
class TodayTasksPanel extends StatelessWidget {
  const TodayTasksPanel({
    super.key,
    required this.mission,
    required this.onOpenTask,
  });

  final CurrentMission mission;
  final ValueChanged<WeeklyTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    // 시안 `.hide-n` — 720 미만에서 감추는 칼럼. `DpWebTable` 은 칼럼 숨김을
    // 모르므로 칼럼 목록 자체에서 뺀다. 셀도 같은 조건으로 빼야 한다
    // (`DpWebTable` 의 assert 가 개수 불일치를 배치 전에 잡는다).
    final compact = context.windowClass == DpWindowClass.compact;
    final nextTaskId = mission.nextTask?.taskId;

    return DpPanel(
      title: const DpPanelTitle('이번 주 과제'),
      child: DpWebTable(
        columns: [
          const (label: '과제', width: null, numeric: false),
          if (!compact) const (label: '유형', width: 72, numeric: false),
          const (label: '상태', width: 72, numeric: false),
          const (label: '', width: 72, numeric: true),
        ],
        empty: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: DpSpacing.xl,
            horizontal: DpSpacing.lg,
          ),
          child: Text('이번 주 과제가 아직 없어요'),
        ),
        rows: [
          for (final task in mission.tasks)
            (
              cells: [
                DpLink.title(text: task.title, onTap: () => onOpenTask(task)),
                if (!compact)
                  DpTag(label: DpLearningLabels.taskType(task.taskType)),
                _status(task, nextTaskId),
                DpLink.inline(
                  text: _actionLabel(task, nextTaskId),
                  onTap: () => onOpenTask(task),
                ),
              ],
              onTap: () => onOpenTask(task),
            ),
        ],
      ),
    );
  }

  /// 시안 `.st.ok/.now/.no` — 색만으로 의미를 전달하지 않도록 기호를 함께 넣는다.
  Widget _status(WeeklyTask task, int? nextTaskId) {
    if (task.completed) {
      return const DpStatusText(text: '✓ 완료', tone: DpStatusTone.done);
    }
    if (task.taskId != null && task.taskId == nextTaskId) {
      return const DpStatusText(text: '● 다음', tone: DpStatusTone.current);
    }
    return const DpStatusText(text: '대기', tone: DpStatusTone.idle);
  }

  String _actionLabel(WeeklyTask task, int? nextTaskId) {
    if (task.completed) return '다시 보기';
    if (task.taskId != null && task.taskId == nextTaskId) return '시작';
    return '열기';
  }
}

/// 시안 `today` 의 `.side` 첫 패널 — 「진행」 키-값.
///
/// 옛 KPI 카드 2장(`연속 학습`·`완료 콘텐츠`)·도넛(`전체 진행률`)·배지 스트립의
/// 데이터가 전부 이 표로 모인다. 같은 숫자를 한 화면에 두 번 그리지 않는다.
class TodayProgressPanel extends StatelessWidget {
  const TodayProgressPanel({
    super.key,
    required this.summary,
    required this.mission,
  });

  final DashboardSummary summary;
  final CurrentMission? mission;

  @override
  Widget build(BuildContext context) {
    final tasks = mission?.tasks ?? const <WeeklyTask>[];
    final done = tasks.where((task) => task.completed).length;
    final weekNum = mission?.weekNum;

    return DpPanel(
      title: const DpPanelTitle('진행'),
      child: DpKeyValues(
        entries: [
          if (tasks.isNotEmpty)
            (key: '이번 주', value: Text('$done / ${tasks.length}')),
          // 시안은 「12주 중 1주차」지만 총 주차 수는 이 화면에 내려오지 않는다
          // (`LearningPath` 를 읽지 않는다). 새 호출을 만들지 않고 낮춰 적는다.
          if (weekNum != null) (key: '현재 주차', value: Text('$weekNum주차')),
          (key: '전체 진행률', value: Text('${summary.progressPercent}%')),
          (key: '연속 학습', value: Text('${summary.streakDays}일')),
          (key: '완료 콘텐츠', value: Text('${summary.completedContentCount}개')),
          if (summary.badges.isNotEmpty)
            (
              key: '배지',
              value: Wrap(
                alignment: WrapAlignment.end,
                spacing: DpSpacing.xs,
                runSpacing: DpSpacing.xs,
                children: [for (final b in summary.badges) DpTag(label: b)],
              ),
            ),
        ],
      ),
    );
  }
}

/// 시안 `today` 의 「왜 이 순서인가요」 패널.
class TodayWhyPanel extends StatelessWidget {
  const TodayWhyPanel({super.key, required this.why, required this.onOpenPath});

  /// `DpMissionHeader.why` 와 같은 문장을 받는다 — 두 곳이 갈라지지 않게.
  final String why;
  final VoidCallback onOpenPath;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return DpPanel(
      title: const DpPanelTitle('왜 이 순서인가요'),
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            why,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: DpSpacing.sm),
          DpLink.inline(text: '경로 전체 보기', onTap: onOpenPath),
        ],
      ),
    );
  }
}

/// 시안 `today` 의 「막히면」 패널 — 구분선 목록 안 링크 둘.
class TodayHelpPanel extends StatelessWidget {
  const TodayHelpPanel({
    super.key,
    required this.onOpenMentor,
    required this.onOpenQna,
  });

  final VoidCallback onOpenMentor;
  final VoidCallback onOpenQna;

  @override
  Widget build(BuildContext context) => DpPanel(
    title: const DpPanelTitle('막히면'),
    child: DpListLines(
      children: [
        DpLink.inline(text: 'AI 멘토에게 이 과제 물어보기', onTap: onOpenMentor),
        DpLink.inline(text: 'Q/A 에서 비슷한 질문 찾기', onTap: onOpenQna),
      ],
    ),
  );
}
