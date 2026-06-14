import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import 'dp_state_scaffold.dart';

class DpEmpty extends StatelessWidget {
  const DpEmpty({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = DpIcons.empty,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DpStateScaffold(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}
