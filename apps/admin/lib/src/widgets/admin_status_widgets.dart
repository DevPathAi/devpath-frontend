import 'dart:math' as math;

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../design/admin_status_catalog.dart';

/// Localized operator-facing status with the immutable wire value kept visible.
class AdminStatusText extends StatelessWidget {
  const AdminStatusText({super.key, required this.domain, required this.wire});

  final AdminStatusDomain domain;
  final String wire;

  @override
  Widget build(BuildContext context) {
    final status = AdminStatusCatalog.resolve(domain, wire);
    final text = Theme.of(context).textTheme;
    final colors = context.dpColors;
    return Semantics(
      label: status.displayLabel,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: DpSpacing.xs,
          runSpacing: DpSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(status.label, style: text.bodyMedium),
            Text(
              '(${status.wire})',
              style: text.bodySmall?.copyWith(
                color: status.isKnown ? colors.textSecondary : colors.danger,
                fontFamily: DpTypography.codeFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One responsive status-filter control shared by every Admin list surface.
///
/// A dropdown avoids the fixed-width four/five-way segmented control that
/// overflows at 320 logical px and 200% text. Only raw values are returned.
class AdminStatusFilter extends StatelessWidget {
  const AdminStatusFilter({
    super.key,
    required this.domain,
    required this.selectedWire,
    required this.onSelected,
    this.includeAll = true,
    this.label = '상태',
  });

  static const _all = '__ADMIN_ALL_STATUSES__';

  final AdminStatusDomain domain;
  final String? selectedWire;
  final ValueChanged<String?> onSelected;
  final bool includeAll;
  final String label;

  @override
  Widget build(BuildContext context) {
    final known = AdminStatusCatalog.values(domain);
    final selected = selectedWire == null && includeAll ? _all : selectedWire;
    final options = <AdminStatusDescriptor>[
      ...known,
      if (selectedWire != null && !known.any((e) => e.wire == selectedWire))
        AdminStatusCatalog.resolve(domain, selectedWire!),
    ];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(320.0, math.max(0.0, screenWidth - DpSpacing.xxl));
    final selectedLabel = selectedWire == null
        ? '전체 상태'
        : AdminStatusCatalog.resolve(domain, selectedWire!).displayLabel;

    return Semantics(
      container: true,
      label: '$label 필터: $selectedLabel',
      child: SizedBox(
        width: width,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey('admin-status-filter-${domain.name}-$selected'),
              value: selected,
              isExpanded: true,
              menuMaxHeight: 420,
              items: [
                if (includeAll)
                  const DropdownMenuItem(
                    value: _all,
                    child: Text('전체 상태', overflow: TextOverflow.ellipsis),
                  ),
                for (final option in options)
                  DropdownMenuItem(
                    value: option.wire,
                    child: Text(
                      option.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onSelected(value == _all ? null : value);
              },
            ),
          ),
        ),
      ),
    );
  }
}
