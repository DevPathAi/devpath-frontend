import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/report.dart';
import '../state/reports_state.dart';

class ReportsController extends Notifier<ReportsState> {
  @override
  ReportsState build() {
    _load();
    return const ReportsLoading();
  }

  Future<void> _load() async {
    try {
      final json =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>('/admin/reports');
      final list = (json['data'] as List)
          .map((o) => Report.fromJson((o as Map).cast<String, dynamic>()))
          .toList();
      state = ReportsLoaded(list);
    } on ApiException catch (e) {
      state = ReportsFailed(e.message);
    }
  }

  Future<void> resolve(String id) async {
    await ref.read(apiClientProvider)
        .post<Map<String, dynamic>>('/admin/reports/$id/resolve');
    final s = state;
    if (s is ReportsLoaded) {
      state = ReportsLoaded(s.reports.where((r) => r.id != id).toList());
    }
  }
}

final reportsProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);
