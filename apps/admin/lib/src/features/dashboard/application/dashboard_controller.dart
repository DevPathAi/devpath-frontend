import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/dashboard_state.dart';

class AdminDashController extends Notifier<AdminDashState> {
  @override
  AdminDashState build() => const AdminDashLoading();

  Future<void> load() async {
    state = const AdminDashLoading();
    try {
      final json =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>('/admin/stats');
      state = AdminDashLoaded(json.map((k, v) => MapEntry(k, (v as num).toInt())));
    } on ApiException catch (e) {
      state = AdminDashFailed(e.message);
    }
  }
}

final adminDashProvider =
    NotifierProvider<AdminDashController, AdminDashState>(AdminDashController.new);
