import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import 'dashboard_cache.dart';

/// drift 백엔드 [DashboardCache]. 단일 행(id=0) upsert로 최신 스냅샷만 유지.
class DriftDashboardCache implements DashboardCache {
  DriftDashboardCache(this._db);

  final AppDatabase _db;

  @override
  Future<DashboardSummary?> read() async {
    final row = await (_db.select(
      _db.dashboardCacheRows,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (row == null) return null;
    return DashboardSummary(
      streakDays: row.streakDays,
      progressPercent: row.progressPercent,
      nextTaskTitle: row.nextTaskTitle,
      badges: (jsonDecode(row.badges) as List).cast<String>(),
    );
  }

  @override
  Future<void> write(DashboardSummary summary) async {
    await _db
        .into(_db.dashboardCacheRows)
        .insertOnConflictUpdate(
          DashboardCacheRowsCompanion.insert(
            id: const Value(0),
            streakDays: summary.streakDays,
            progressPercent: summary.progressPercent,
            nextTaskTitle: Value(summary.nextTaskTitle),
            badges: jsonEncode(summary.badges),
            cachedAt: DateTime.now(),
          ),
        );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

/// 프로덕션 대시보드 캐시. 테스트는 이 provider를 [InMemoryDashboardCache]로 오버라이드.
final dashboardCacheProvider = Provider<DashboardCache>(
  (ref) => DriftDashboardCache(ref.watch(appDatabaseProvider)),
);
