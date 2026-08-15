import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/dashboard_state.dart';

class DashboardController extends Notifier<DashboardState> {
  Future<void>? _inFlight;
  int? _inFlightGeneration;
  var _generation = 0;
  var _disposed = false;
  String? _ownerKey;
  var _ownerBound = false;

  @override
  DashboardState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation += 1;
      _inFlight = null;
      _inFlightGeneration = null;
    });
    return const DashLoading();
  }

  /// 화면이 읽으려는 인증 계정과 현재 지표 cache의 소유자가 같은지 확인한다.
  ///
  /// Dashboard가 닫힌 동안 계정이 바뀐 경우 post-frame 동기화 전에 이전
  /// [DashLoaded]가 한 frame 렌더되는 것을 막기 위한 read-only projection이다.
  bool isBoundTo(String? ownerKey) =>
      _ownerBound && _ownerKey == ownerKey;

  /// Dashboard 화면이 인증 상태에서 얻은 owner를 전달한다. 컨트롤러 자체가
  /// AuthController를 강제로 초기화하지 않으므로 콘텐츠 완료 후 지표 refresh가
  /// 불필요한 세션 bootstrap을 만들지 않는다.
  void synchronizeOwner(String? ownerKey) {
    if (_disposed || (_ownerBound && ownerKey == _ownerKey)) return;
    _ownerBound = true;
    _ownerKey = ownerKey;
    _generation += 1;
    _inFlight = null;
    _inFlightGeneration = null;
    state = const DashLoading();
    if (ownerKey != null) unawaited(load());
  }

  Future<void> load() {
    final active = _inFlight;
    if (active != null && _inFlightGeneration == _generation) return active;

    final generation = _generation;
    state = const DashLoading();

    late final Future<void> tracked;
    tracked = _fetch(generation).whenComplete(() {
      if (identical(_inFlight, tracked)) {
        _inFlight = null;
        _inFlightGeneration = null;
      }
    });
    _inFlight = tracked;
    _inFlightGeneration = generation;
    return tracked;
  }

  Future<void> _fetch(int generation) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/dashboard/me');
      if (_disposed || generation != _generation) return;
      state = DashLoaded(DashboardSummary.fromJson(json));
    } on ApiException catch (e) {
      if (_disposed || generation != _generation) return;
      state = DashFailed(e.message);
    } on Object {
      if (_disposed || generation != _generation) return;
      state = const DashFailed('학습 지표 형식을 확인하지 못했어요.');
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
