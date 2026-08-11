import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 신고 다이얼로그가 돌려주는 값. 취소하면 null 이다.
class ReportDialogResult {
  const ReportDialogResult(this.category, this.reason);
  final CommunityReportCategory category;

  /// 비어 있으면 null — 서버에 빈 문자열을 보내지 않는다.
  final String? reason;
}

/// 신고 사유 선택 다이얼로그.
///
/// 카테고리를 고르기 전에는 제출 버튼이 비활성이다 — 눌리지만 아무 일도 안 하는
/// "조용히 실패하는 버튼"을 두지 않는다(이 프로젝트가 동의 화면에서 겪은 문제).
class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  /// 서버 제약과 같은 값(초과 시 400).
  static const _reasonMax = 500;

  CommunityReportCategory? _category;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('신고하기'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('사유를 골라주세요'),
            const SizedBox(height: DpSpacing.sm),
            Wrap(
              spacing: DpSpacing.xs,
              runSpacing: DpSpacing.xs,
              children: [
                for (final c in CommunityReportCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            TextField(
              key: const ValueKey('report-reason'),
              controller: _reason,
              maxLength: _reasonMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '상세 설명 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('report-submit'),
          onPressed: _category == null ? null : _submit,
          child: const Text('신고'),
        ),
      ],
    );
  }

  void _submit() {
    final trimmed = _reason.text.trim();
    Navigator.of(
      context,
    ).pop(ReportDialogResult(_category!, trimmed.isEmpty ? null : trimmed));
  }
}
