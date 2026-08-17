import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_source.dart';
import '../state/dashboard_state.dart';

class AdminDashController extends Notifier<AdminDashState> {
  @override
  AdminDashState build() => const AdminDashLoading();

  Future<void> load() async {
    state = const AdminDashLoading();
    try {
      state = AdminDashLoaded(await ref.read(adminStatsFetchProvider)());
    } on ApiException catch (e) {
      state = AdminDashFailed(e.message);
    } on Object {
      state = const AdminDashFailed('운영 지표를 불러오지 못했어요');
    }
  }
}

final adminDashProvider = NotifierProvider<AdminDashController, AdminDashState>(
  AdminDashController.new,
);
