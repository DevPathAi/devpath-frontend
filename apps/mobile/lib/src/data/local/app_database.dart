import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// 오프라인 읽기 캐시(단일 행, id=0). 대시보드 스냅샷을 보관한다.
/// badges는 JSON 배열 문자열로 직렬화한다.
class DashboardCacheRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get streakDays => integer()();
  IntColumn get progressPercent => integer()();
  TextColumn get nextTaskTitle => text().nullable()();
  TextColumn get badges => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DashboardCacheRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// 프로덕션 연결 — 앱 문서 디렉터리의 sqlite 파일(백그라운드 isolate).
LazyDatabase openAppDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'devpath_cache.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
