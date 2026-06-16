import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/dashboard_state.dart';

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashLoading();

  Future<void> load() async {
    state = const DashLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/dashboard');
      state = DashLoaded(DashboardSummary.fromJson(json));
    } on ApiException catch (e) {
      state = DashFailed(e.message);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
