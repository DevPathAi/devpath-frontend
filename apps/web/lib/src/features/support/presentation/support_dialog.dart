import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../application/support_controller.dart';
import '../data/support_context_collector.dart';
import '../data/support_draft.dart';

/// 제보 다이얼로그를 띄우고 접수 번호를 돌려준다(취소면 null).
///
/// 두 진입점(앱셸 상시 버튼 · 오류 화면의 [문의하기])이 이 함수만 호출한다.
Future<int?> showSupportDialog(
  BuildContext context, {
  String? traceId,
  String? errorCode,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => SupportDialog(traceId: traceId, errorCode: errorCode),
  );
}

class SupportDialog extends ConsumerStatefulWidget {
  const SupportDialog({super.key, this.traceId, this.errorCode});

  final String? traceId;
  final String? errorCode;

  @override
  ConsumerState<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends ConsumerState<SupportDialog> {
  static const _titleMax = 200;
  static const _bodyMax = 5000;

  String _type = 'ERROR';

  // Controller 는 State 가 소유한다 — 매 빌드 교체하면 IME 조합이 끊긴다
  // (2026-08-01 서식 에디터에서 겪은 문제).
  final _title = TextEditingController();
  final _body = TextEditingController();

  String? _validationMessage;
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final failures = ref.watch(apiFailureLogProvider).recent;

    return AlertDialog(
      title: const Text('오류 신고·문의'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ERROR', label: Text('오류')),
                  ButtonSegment(value: 'INQUIRY', label: Text('문의')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: DpSpacing.md),
              TextField(
                key: const ValueKey('support-title'),
                controller: _title,
                maxLength: _titleMax,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              TextField(
                key: const ValueKey('support-body'),
                controller: _body,
                maxLength: _bodyMax,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '내용',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              // 선택이 아니라 고지다 — 무엇이 전송되는지 열어 볼 수 있어야 한다.
              // 마스킹된 값을 그대로 보여주므로 "여기 이메일이 남아 있다"를 발견할 수 있다.
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('함께 보낼 정보'),
                  subtitle: Text(
                    '최근 실패 ${failures.length}건 · 화면 경로 · 브라우저 정보',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  children: [
                    for (final f in failures)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${f.method} ${f.path}'),
                        subtitle: Text(
                          '${f.statusCode ?? '네트워크 실패'}'
                          '${f.errorCode == null ? '' : ' · ${f.errorCode}'}'
                          '${f.message == null ? '' : '\n${f.message}'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    if (failures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DpSpacing.xs,
                        ),
                        child: Text(
                          '기록된 API 실패가 없습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: DpSpacing.xs),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: c.danger, fontSize: 12),
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: DpSpacing.xs),
                Text(
                  _submitError!,
                  style: TextStyle(color: c.danger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('support-submit'),
          // 입력이 비어도 **버튼을 죽이지 않는다** — 눌러도 아무 일 없는 버튼을 두지 않는다.
          onPressed: _submitting ? null : _submit,
          child: const Text('보내기'),
        ),
      ],
    );
  }

  /// 라우터 밖(테스트 호스트)에서는 '/' 로 둔다 — 진단 정보 하나 때문에 제보가
  /// 실패하면 안 된다는 §5.2 원칙과 같은 판단이다.
  String _pagePath(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/';
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _validationMessage = '제목과 내용을 모두 입력해 주세요';
        _submitError = null;
      });
      return;
    }

    setState(() {
      _validationMessage = null;
      _submitError = null;
      _submitting = true;
    });

    final media = MediaQuery.sizeOf(context);
    final ctx = SupportContext(
      // .path 를 쓰므로 쿼리스트링이 구조적으로 빠진다.
      pagePath: _pagePath(context),
      appVersion: ref.read(appConfigProvider).appVersion,
      userAgent: userAgentReader().read(),
      viewport: '${media.width.round()}x${media.height.round()}',
      traceId: widget.traceId,
      errorCode: widget.errorCode,
      occurredAt: DateTime.now(),
      failures: ref.read(apiFailureLogProvider).recent,
    );

    try {
      final id = await ref
          .read(supportControllerProvider.notifier)
          .submit(SupportDraft(type: _type, title: title, body: body), ctx);
      if (mounted) Navigator.of(context).pop(id);
    } on ApiException catch (e) {
      // 입력을 유지한 채 에러만 보여준다.
      if (mounted) {
        setState(() {
          _submitError = e.message;
          _submitting = false;
        });
      }
    }
  }
}
