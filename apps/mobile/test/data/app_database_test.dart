import 'package:devpath_mobile/src/data/local/app_database.dart';
import 'package:devpath_mobile/src/features/dashboard/data/drift_dashboard_cache.dart';
import 'package:dp_core/dp_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftDashboardCache (drift native)', () {
    late AppDatabase db;
    late DriftDashboardCache cache;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      cache = DriftDashboardCache(db);
    });

    tearDown(() => db.close());

    test('초기 캐시 비어 있음', () async {
      expect(await cache.read(), isNull);
    });

    test('쓰기 → 읽기 라운드트립(배지 JSON 포함)', () async {
      await cache.write(
        const DashboardSummary(
          streakDays: 5,
          progressPercent: 50,
          nextTaskTitle: '과제',
          badges: ['a', 'b'],
        ),
      );
      final r = await cache.read();
      expect(r, isNotNull);
      expect(r!.streakDays, 5);
      expect(r.progressPercent, 50);
      expect(r.nextTaskTitle, '과제');
      expect(r.badges, ['a', 'b']);
    });

    test('upsert: 단일 행 갱신(null next + 빈 배지)', () async {
      await cache.write(
        const DashboardSummary(
          streakDays: 5,
          progressPercent: 50,
          nextTaskTitle: '과제',
          badges: ['a'],
        ),
      );
      await cache.write(
        const DashboardSummary(
          streakDays: 9,
          progressPercent: 90,
          nextTaskTitle: null,
          badges: [],
        ),
      );
      final r = await cache.read();
      expect(r!.streakDays, 9);
      expect(r.nextTaskTitle, isNull);
      expect(r.badges, isEmpty);
    });
  });
}
