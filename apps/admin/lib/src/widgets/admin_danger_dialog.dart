import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

Future<bool?> showAdminDangerDialog({
  required BuildContext context,
  required String title,
  required String impact,
  required String confirmLabel,
  required Future<dynamic> Function() onConfirm,
  String? confirmationValue,
}) => showDialog<bool>(
  context: context,
  builder: (_) => AdminDangerDialog(
    title: title,
    impact: impact,
    confirmLabel: confirmLabel,
    onConfirm: onConfirm,
    confirmationValue: confirmationValue,
  ),
);

/// Shared confirmation for destructive Admin operations.
///
/// The dialog owns the async boundary so a failed request never dismisses the
/// impact statement or clears selection/form state in the calling surface.
class AdminDangerDialog extends StatefulWidget {
  const AdminDangerDialog({
    super.key,
    required this.title,
    required this.impact,
    required this.confirmLabel,
    required this.onConfirm,
    this.confirmationValue,
  });

  final String title;
  final String impact;
  final String confirmLabel;
  final Future<dynamic> Function() onConfirm;

  /// Optional typed guard for especially consequential decisions.
  /// It is local confirmation only and is never added to an API payload.
  final String? confirmationValue;

  @override
  State<AdminDangerDialog> createState() => _AdminDangerDialogState();
}

class _AdminDangerDialogState extends State<AdminDangerDialog> {
  late final TextEditingController _confirmation = TextEditingController()
    ..addListener(_confirmationChanged);
  bool _pending = false;
  String? _error;

  bool get _confirmationMatches =>
      widget.confirmationValue == null ||
      _confirmation.text == widget.confirmationValue;

  @override
  void dispose() {
    _confirmation
      ..removeListener(_confirmationChanged)
      ..dispose();
    super.dispose();
  }

  void _confirmationChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        icon: Icon(DpIcons.error, color: colors.danger),
        title: Semantics(
          header: true,
          child: Text(widget.title, style: text.titleLarge),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.impact, style: text.bodyMedium),
              if (widget.confirmationValue case final value?) ...[
                const SizedBox(height: DpSpacing.md),
                TextField(
                  key: const ValueKey('admin-danger-confirmation-input'),
                  controller: _confirmation,
                  enabled: !_pending,
                  decoration: InputDecoration(labelText: '확인을 위해 "$value" 입력'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: DpSpacing.md),
                Semantics(
                  liveRegion: true,
                  label: '작업 실패: $_error',
                  child: ExcludeSemantics(
                    child: Text(
                      _error!,
                      style: text.bodyMedium?.copyWith(color: colors.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: _pending || !_confirmationMatches ? null : _confirm,
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: _pending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (result is String && result.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _pending = false;
          _error = result;
        });
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = error is ApiException
            ? error.message
            : '작업을 완료하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }
}
