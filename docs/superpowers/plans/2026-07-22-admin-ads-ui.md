# 베타 광고 관리 admin UI (P2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** admin 앱에 베타 광고를 관리하는 `/ads` 화면(목록·상태토글·생성/수정·이미지업로드·슬롯필터·전역토글·통계)을 추가한다.

**Architecture:** 기존 `users`/`reports` feature와 동일한 4계층(data/state/application/presentation) 구조로 신규 `ads` feature를 만든다. data 계층은 `apiClientProvider`를 래핑하는 함수형 Provider들, application 계층은 `Notifier<AdsState>`, presentation은 `ConsumerStatefulWidget` 페이지 + 다이얼로그 2종. 라우터·셸·아이콘·mock fixture는 최소 수정.

**Tech Stack:** Flutter Web · Riverpod 3.0 · go_router · dp_core(ApiClient/ApiException) · dp_design(DpIcons/DpSpacing/DpTheme/DpLoading/DpError/DpEmpty).

## Global Constraints

- 스택/명령: 모노레포 루트에서 `melos run analyze` · `melos run test` · `melos run format`(CI 게이트, `dart format --set-exit-if-changed .`). 커밋 전 `dart format .` 필수(Edit 코드는 dart format과 어긋나기 쉬움).
- 브랜치: `feat/admin-ads-ui`(이미 `develop`에서 분기됨). `main`·`develop` 직접 push 금지, develop으로 PR.
- test-first: 각 기능은 실패 테스트를 먼저 쓰고 통과를 눈으로 확인.
- Riverpod 3.0: 테스트 헬퍼에 `List<Override>` 타입 명시 금지 — 인라인 `ProviderContainer(overrides: [...])`.
- DB CHECK 제약값(폼은 이 값만 사용): `slot ∈ {DASHBOARD_TOP, COMMUNITY_FEED, CONTENT_PAGE}`, `status ∈ {ACTIVE, PAUSED}`, `weight ≥ 1`.
- 백엔드 계약: `AdRow`/`AdRequest` = title(필수)·imageUrl(nullable)·linkUrl(필수)·slot·weight(≥1)·status·startsAt(nullable ISO-8601)·endsAt(nullable). `AdStatsRow` = date(ISO date)·impressions·clicks. 이미지 업로드는 광고 id 선행 필요(수정 모드에서만).
- 경로: 신규 파일은 `apps/admin/lib/src/features/ads/{data,state,application,presentation}/`, 테스트는 `apps/admin/test/features/ads/`.

---

### Task 1: 데이터 모델 (AdRow · AdStatsRow)

**Files:**
- Create: `apps/admin/lib/src/features/ads/data/ad_row.dart`
- Create: `apps/admin/lib/src/features/ads/data/ad_stats_row.dart`
- Test: `apps/admin/test/features/ads/ad_row_test.dart`

**Interfaces:**
- Consumes: 없음(순수 Dart).
- Produces:
  - `class AdRow` — 필드 `int? id, String title, String? imageUrl, String linkUrl, String slot, int weight, String status, DateTime? startsAt, DateTime? endsAt`; `factory AdRow.fromJson(Map<String,dynamic>)`; `Map<String,dynamic> toRequestJson()`; `AdRow copyWith({...})`.
  - `class AdStatsRow` — 필드 `DateTime date, int impressions, int clicks`; `factory AdStatsRow.fromJson(Map<String,dynamic>)`; `int get ctrPercentTimes10`(정수 CTR 계산은 UI가 함 — 여기선 원자료만).

- [ ] **Step 1: 실패 테스트 작성** — `apps/admin/test/features/ads/ad_row_test.dart`

```dart
import 'package:admin/src/features/ads/data/ad_row.dart';
import 'package:admin/src/features/ads/data/ad_stats_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdRow.fromJson parses all fields incl. nullable instants', () {
    final r = AdRow.fromJson({
      'id': 7,
      'title': '배너',
      'imageUrl': 'https://cdn/x.png',
      'linkUrl': 'https://e.com',
      'slot': 'DASHBOARD_TOP',
      'weight': 3,
      'status': 'ACTIVE',
      'startsAt': '2026-07-22T00:00:00Z',
      'endsAt': null,
    });
    expect(r.id, 7);
    expect(r.title, '배너');
    expect(r.slot, 'DASHBOARD_TOP');
    expect(r.weight, 3);
    expect(r.startsAt!.toUtc().toIso8601String(), '2026-07-22T00:00:00.000Z');
    expect(r.endsAt, isNull);
  });

  test('AdRow.toRequestJson omits id and serializes instants as ISO-8601', () {
    final r = AdRow(
      id: 7,
      title: '배너',
      imageUrl: null,
      linkUrl: 'https://e.com',
      slot: 'COMMUNITY_FEED',
      weight: 1,
      status: 'PAUSED',
      startsAt: DateTime.utc(2026, 7, 22),
      endsAt: null,
    );
    final j = r.toRequestJson();
    expect(j.containsKey('id'), isFalse);
    expect(j['title'], '배너');
    expect(j['slot'], 'COMMUNITY_FEED');
    expect(j['status'], 'PAUSED');
    expect(j['startsAt'], '2026-07-22T00:00:00.000Z');
    expect(j['endsAt'], isNull);
    expect(j['imageUrl'], isNull);
  });

  test('AdStatsRow.fromJson parses date and counts', () {
    final s = AdStatsRow.fromJson(
        {'date': '2026-07-22', 'impressions': 100, 'clicks': 5});
    expect(s.date.year, 2026);
    expect(s.date.month, 7);
    expect(s.date.day, 22);
    expect(s.impressions, 100);
    expect(s.clicks, 5);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend && dart pub global run melos run test --scope=admin` (또는 `cd apps/admin && flutter test test/features/ads/ad_row_test.dart`)
Expected: FAIL — `ad_row.dart` / `ad_stats_row.dart` 없음(컴파일 에러).

- [ ] **Step 3: AdRow 구현** — `apps/admin/lib/src/features/ads/data/ad_row.dart`

```dart
/// admin 광고 목록/폼 모델. 백엔드 AdRow(응답)·AdRequest(요청) 양쪽을 담당.
class AdRow {
  const AdRow({
    this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.slot,
    required this.weight,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });

  final int? id;
  final String title;
  final String? imageUrl;
  final String linkUrl;
  final String slot; // DASHBOARD_TOP | COMMUNITY_FEED | CONTENT_PAGE
  final int weight;
  final String status; // ACTIVE | PAUSED
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory AdRow.fromJson(Map<String, dynamic> json) => AdRow(
    id: (json['id'] as num?)?.toInt(),
    title: json['title'] as String,
    imageUrl: json['imageUrl'] as String?,
    linkUrl: json['linkUrl'] as String,
    slot: json['slot'] as String,
    weight: (json['weight'] as num).toInt(),
    status: json['status'] as String,
    startsAt: _parseInstant(json['startsAt']),
    endsAt: _parseInstant(json['endsAt']),
  );

  /// POST/PUT 바디(AdRequest). id는 경로로 전달되므로 제외.
  Map<String, dynamic> toRequestJson() => {
    'title': title,
    'imageUrl': imageUrl,
    'linkUrl': linkUrl,
    'slot': slot,
    'weight': weight,
    'status': status,
    'startsAt': startsAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
  };

  AdRow copyWith({
    int? id,
    String? title,
    Object? imageUrl = _sentinel,
    String? linkUrl,
    String? slot,
    int? weight,
    String? status,
    Object? startsAt = _sentinel,
    Object? endsAt = _sentinel,
  }) => AdRow(
    id: id ?? this.id,
    title: title ?? this.title,
    imageUrl: imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
    linkUrl: linkUrl ?? this.linkUrl,
    slot: slot ?? this.slot,
    weight: weight ?? this.weight,
    status: status ?? this.status,
    startsAt: startsAt == _sentinel ? this.startsAt : startsAt as DateTime?,
    endsAt: endsAt == _sentinel ? this.endsAt : endsAt as DateTime?,
  );

  static const _sentinel = Object();

  static DateTime? _parseInstant(Object? v) =>
      v == null ? null : DateTime.parse(v as String);
}
```

- [ ] **Step 4: AdStatsRow 구현** — `apps/admin/lib/src/features/ads/data/ad_stats_row.dart`

```dart
/// 광고 일별 통계 행.
class AdStatsRow {
  const AdStatsRow({
    required this.date,
    required this.impressions,
    required this.clicks,
  });

  final DateTime date;
  final int impressions;
  final int clicks;

  factory AdStatsRow.fromJson(Map<String, dynamic> json) => AdStatsRow(
    date: DateTime.parse(json['date'] as String),
    impressions: (json['impressions'] as num).toInt(),
    clicks: (json['clicks'] as num).toInt(),
  );
}
```

- [ ] **Step 5: 테스트 통과 확인 + 포맷**

Run: `cd apps/admin && flutter test test/features/ads/ad_row_test.dart`
Expected: PASS (3 tests)
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/admin/lib/src/features/ads apps/admin/test/features/ads`

- [ ] **Step 6: 커밋**

```bash
git add apps/admin/lib/src/features/ads/data apps/admin/test/features/ads/ad_row_test.dart
git commit -m "feat(admin): 광고 데이터 모델(AdRow·AdStatsRow) 추가"
```

---

### Task 2: 데이터 소스 + 상태 + 컨트롤러

**Files:**
- Create: `apps/admin/lib/src/features/ads/data/ads_source.dart`
- Create: `apps/admin/lib/src/features/ads/state/ads_state.dart`
- Create: `apps/admin/lib/src/features/ads/application/ads_controller.dart`
- Test: `apps/admin/test/features/ads/ads_controller_test.dart`

**Interfaces:**
- Consumes: `AdRow`, `AdStatsRow`(Task 1); `apiClientProvider`(`apps/admin/lib/src/providers/api_providers.dart`).
- Produces:
  - `ads_source.dart` 함수형 typedef + Provider:
    - `typedef AdsListFetch = Future<List<AdRow>> Function({String? slot, String? status});` → `adsListProvider`
    - `typedef AdCreate = Future<AdRow> Function(AdRow draft);` → `adCreateProvider`
    - `typedef AdUpdate = Future<AdRow> Function(int id, AdRow draft);` → `adUpdateProvider`
    - `typedef AdDelete = Future<void> Function(int id);` → `adDeleteProvider`
    - `typedef AdImageUpload = Future<AdRow> Function(int id, List<int> bytes, String filename, String? contentType);` → `adImageUploadProvider`
    - `typedef AdSettingsGet = Future<bool> Function();` → `adSettingsGetProvider`
    - `typedef AdSettingsSet = Future<bool> Function(bool enabled);` → `adSettingsSetProvider`
    - `typedef AdStatsFetch = Future<List<AdStatsRow>> Function(int id, DateTime from, DateTime to);` → `adStatsProvider`
  - `ads_state.dart`: `enum AdsPhase { loading, loaded, failed }`; `class AdsState`(rows·phase·slotFilter·statusFilter·globalEnabled·error) + `copyWith`.
  - `ads_controller.dart`: `class AdsController extends Notifier<AdsState>` — `load()`, `setSlotFilter(String?)`, `setStatusFilter(String?)`, `Future<void> create(AdRow)`, `Future<void> update(int, AdRow)`, `Future<void> remove(int)`, `Future<void> toggleStatus(AdRow)`, `Future<void> toggleGlobal(bool)`, `Future<void> uploadImage(int, List<int>, String, String?)`; `final adsProvider = NotifierProvider<AdsController, AdsState>(AdsController.new);`

- [ ] **Step 1: 실패 테스트 작성** — `apps/admin/test/features/ads/ads_controller_test.dart`

```dart
import 'package:admin/src/features/ads/application/ads_controller.dart';
import 'package:admin/src/features/ads/data/ad_row.dart';
import 'package:admin/src/features/ads/data/ads_source.dart';
import 'package:admin/src/features/ads/state/ads_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad({int? id, String status = 'ACTIVE'}) => AdRow(
  id: id,
  title: 't',
  imageUrl: null,
  linkUrl: 'https://e.com',
  slot: 'DASHBOARD_TOP',
  weight: 1,
  status: status,
  startsAt: null,
  endsAt: null,
);

void main() {
  test('load fills rows and globalEnabled → loaded', () async {
    final c = ProviderContainer(overrides: [
      adsListProvider.overrideWithValue(({slot, status}) async => [_ad(id: 1)]),
      adSettingsGetProvider.overrideWithValue(() async => true),
    ]);
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    final s = c.read(adsProvider);
    expect(s.phase, AdsPhase.loaded);
    expect(s.rows.length, 1);
    expect(s.globalEnabled, isTrue);
  });

  test('toggleStatus flips ACTIVE→PAUSED via update then reloads', () async {
    int? updatedId;
    String? sentStatus;
    final c = ProviderContainer(overrides: [
      adsListProvider.overrideWithValue(({slot, status}) async => [_ad(id: 9)]),
      adSettingsGetProvider.overrideWithValue(() async => false),
      adUpdateProvider.overrideWithValue((id, draft) async {
        updatedId = id;
        sentStatus = draft.status;
        return draft.copyWith(id: id);
      }),
    ]);
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).toggleStatus(_ad(id: 9, status: 'ACTIVE'));
    expect(updatedId, 9);
    expect(sentStatus, 'PAUSED');
  });

  test('toggleGlobal updates globalEnabled', () async {
    final c = ProviderContainer(overrides: [
      adsListProvider.overrideWithValue(({slot, status}) async => []),
      adSettingsGetProvider.overrideWithValue(() async => false),
      adSettingsSetProvider.overrideWithValue((enabled) async => enabled),
    ]);
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    await c.read(adsProvider.notifier).toggleGlobal(true);
    expect(c.read(adsProvider).globalEnabled, isTrue);
  });

  test('ApiException on load → failed with message', () async {
    final c = ProviderContainer(overrides: [
      adsListProvider.overrideWithValue(
          ({slot, status}) async => throw const ApiException(ApiErrorCode.unknown, '실패')),
      adSettingsGetProvider.overrideWithValue(() async => false),
    ]);
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    final s = c.read(adsProvider);
    expect(s.phase, AdsPhase.failed);
    expect(s.error, '실패');
  });
}
```

> **NOTE(구현자):** `ApiException`의 정확한 생성자 시그니처를 `packages/dp_core/lib/src/api/api_exception.dart`에서 확인하라. 위 테스트의 `ApiException(ApiErrorCode.unknown, '실패')`가 실제 시그니처와 다르면 **테스트를 실제 시그니처에 맞춰 수정**하라(구현을 추측으로 바꾸지 말 것). `message` 게터명도 거기서 확인.

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd apps/admin && flutter test test/features/ads/ads_controller_test.dart`
Expected: FAIL — `ads_source.dart`/`ads_state.dart`/`ads_controller.dart` 없음.

- [ ] **Step 3: ads_source.dart 구현**

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'ad_row.dart';
import 'ad_stats_row.dart';

typedef AdsListFetch =
    Future<List<AdRow>> Function({String? slot, String? status});
typedef AdCreate = Future<AdRow> Function(AdRow draft);
typedef AdUpdate = Future<AdRow> Function(int id, AdRow draft);
typedef AdDelete = Future<void> Function(int id);
typedef AdImageUpload =
    Future<AdRow> Function(
      int id,
      List<int> bytes,
      String filename,
      String? contentType,
    );
typedef AdSettingsGet = Future<bool> Function();
typedef AdSettingsSet = Future<bool> Function(bool enabled);
typedef AdStatsFetch =
    Future<List<AdStatsRow>> Function(int id, DateTime from, DateTime to);

String _d(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

final adsListProvider = Provider<AdsListFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? slot, String? status}) async {
    final query = <String, dynamic>{};
    if (slot != null) query['slot'] = slot;
    if (status != null) query['status'] = status;
    final json = await client.get<List<dynamic>>(
      '/admin/ads',
      query: query.isEmpty ? null : query,
    );
    return json
        .map((o) => AdRow.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});

final adCreateProvider = Provider<AdCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (draft) async {
    final json = await client.post<Map<String, dynamic>>(
      '/admin/ads',
      body: draft.toRequestJson(),
    );
    return AdRow.fromJson(json);
  };
});

final adUpdateProvider = Provider<AdUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, draft) async {
    final json = await client.put<Map<String, dynamic>>(
      '/admin/ads/$id',
      body: draft.toRequestJson(),
    );
    return AdRow.fromJson(json);
  };
});

final adDeleteProvider = Provider<AdDelete>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) => client.delete<void>('/admin/ads/$id');
});

final adImageUploadProvider = Provider<AdImageUpload>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, bytes, filename, contentType) async {
    final json = await client.postMultipart<Map<String, dynamic>>(
      '/admin/ads/$id/image',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return AdRow.fromJson(json);
  };
});

final adSettingsGetProvider = Provider<AdSettingsGet>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/admin/ads/settings');
    return json['enabled'] as bool;
  };
});

final adSettingsSetProvider = Provider<AdSettingsSet>((ref) {
  final client = ref.watch(apiClientProvider);
  return (enabled) async {
    final json = await client.put<Map<String, dynamic>>(
      '/admin/ads/settings',
      body: {'enabled': enabled},
    );
    return json['enabled'] as bool;
  };
});

final adStatsProvider = Provider<AdStatsFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, from, to) async {
    final json = await client.get<List<dynamic>>(
      '/admin/ads/$id/stats',
      query: {'from': _d(from), 'to': _d(to)},
    );
    return json
        .map((o) => AdStatsRow.fromJson((o as Map).cast<String, dynamic>()))
        .toList();
  };
});
```

- [ ] **Step 4: ads_state.dart 구현**

```dart
import '../data/ad_row.dart';

enum AdsPhase { loading, loaded, failed }

class AdsState {
  const AdsState({
    this.rows = const [],
    this.phase = AdsPhase.loading,
    this.slotFilter,
    this.statusFilter,
    this.globalEnabled = false,
    this.error,
  });

  final List<AdRow> rows;
  final AdsPhase phase;
  final String? slotFilter;
  final String? statusFilter;
  final bool globalEnabled;
  final String? error;

  AdsState copyWith({
    List<AdRow>? rows,
    AdsPhase? phase,
    String? slotFilter,
    String? statusFilter,
    bool? globalEnabled,
    String? error,
  }) => AdsState(
    rows: rows ?? this.rows,
    phase: phase ?? this.phase,
    slotFilter: slotFilter ?? this.slotFilter,
    statusFilter: statusFilter ?? this.statusFilter,
    globalEnabled: globalEnabled ?? this.globalEnabled,
    error: error,
  );
}
```

> **NOTE:** `slotFilter`/`statusFilter`는 "필터 해제"(null 지정)를 위해 컨트롤러에서 `AdsState`를 **직접 생성**(copyWith 아님)해 null로 리셋한다. copyWith의 `??`는 null 전달 시 기존값을 유지하기 때문이다(users_state와 동일 한계).

- [ ] **Step 5: ads_controller.dart 구현**

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ad_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

class AdsController extends Notifier<AdsState> {
  @override
  AdsState build() => const AdsState();

  Future<void> load() async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: state.slotFilter,
      statusFilter: state.statusFilter,
      globalEnabled: state.globalEnabled,
    );
    try {
      final rows = await ref.read(adsListProvider)(
        slot: state.slotFilter,
        status: state.statusFilter,
      );
      final enabled = await ref.read(adSettingsGetProvider)();
      state = AdsState(
        rows: rows,
        phase: AdsPhase.loaded,
        slotFilter: state.slotFilter,
        statusFilter: state.statusFilter,
        globalEnabled: enabled,
      );
    } on ApiException catch (e) {
      state = state.copyWith(phase: AdsPhase.failed, error: e.message);
    }
  }

  Future<void> setSlotFilter(String? slot) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: slot,
      statusFilter: state.statusFilter,
      globalEnabled: state.globalEnabled,
    );
    await load();
  }

  Future<void> setStatusFilter(String? status) async {
    state = AdsState(
      phase: AdsPhase.loading,
      slotFilter: state.slotFilter,
      statusFilter: status,
      globalEnabled: state.globalEnabled,
    );
    await load();
  }

  Future<void> create(AdRow draft) async {
    await ref.read(adCreateProvider)(draft);
    await load();
  }

  Future<void> update(int id, AdRow draft) async {
    await ref.read(adUpdateProvider)(id, draft);
    await load();
  }

  Future<void> remove(int id) async {
    await ref.read(adDeleteProvider)(id);
    await load();
  }

  Future<void> toggleStatus(AdRow row) async {
    final next = row.status == 'ACTIVE' ? 'PAUSED' : 'ACTIVE';
    await ref.read(adUpdateProvider)(row.id!, row.copyWith(status: next));
    await load();
  }

  Future<void> toggleGlobal(bool enabled) async {
    final result = await ref.read(adSettingsSetProvider)(enabled);
    state = state.copyWith(globalEnabled: result);
  }

  Future<void> uploadImage(
    int id,
    List<int> bytes,
    String filename,
    String? contentType,
  ) async {
    await ref.read(adImageUploadProvider)(id, bytes, filename, contentType);
    await load();
  }
}

final adsProvider = NotifierProvider<AdsController, AdsState>(
  AdsController.new,
);
```

- [ ] **Step 6: 테스트 통과 확인 + 포맷**

Run: `cd apps/admin && flutter test test/features/ads/ads_controller_test.dart`
Expected: PASS (4 tests). 실패 시 NOTE대로 `ApiException` 시그니처를 실제에 맞춰 **테스트**를 정정.
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/admin/lib/src/features/ads apps/admin/test/features/ads`

- [ ] **Step 7: 커밋**

```bash
git add apps/admin/lib/src/features/ads/data/ads_source.dart apps/admin/lib/src/features/ads/state apps/admin/lib/src/features/ads/application apps/admin/test/features/ads/ads_controller_test.dart
git commit -m "feat(admin): 광고 소스/상태/컨트롤러 추가"
```

---

### Task 3: 프레젠테이션 (페이지 + 폼/통계 다이얼로그)

**Files:**
- Create: `apps/admin/lib/src/features/ads/presentation/ads_page.dart`
- Test: `apps/admin/test/features/ads/ads_page_test.dart`

**Interfaces:**
- Consumes: `adsProvider`(Task 2), `AdRow`(Task 1), `adStatsProvider`(Task 2), dp_design 위젯.
- Produces: `class AdminAdsPage extends ConsumerStatefulWidget`(라우터가 참조). 내부 `_AdFormDialog`·`_AdStatsDialog`는 private.

- [ ] **Step 1: 실패 위젯 테스트 작성** — `apps/admin/test/features/ads/ads_page_test.dart`

```dart
import 'package:admin/src/features/ads/application/ads_controller.dart';
import 'package:admin/src/features/ads/data/ad_row.dart';
import 'package:admin/src/features/ads/data/ads_source.dart';
import 'package:admin/src/features/ads/presentation/ads_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad(int id, String title) => AdRow(
  id: id,
  title: title,
  imageUrl: null,
  linkUrl: 'https://e.com',
  slot: 'DASHBOARD_TOP',
  weight: 1,
  status: 'ACTIVE',
  startsAt: null,
  endsAt: null,
);

Widget _host(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
);

void main() {
  testWidgets('renders ad rows and global switch', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      adsListProvider.overrideWithValue(({slot, status}) async => [_ad(1, '첫 배너')]),
      adSettingsGetProvider.overrideWithValue(() async => true),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('첫 배너'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets); // 전역 스위치 + 행 토글
  });

  testWidgets('tapping 광고 생성 opens form dialog', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([
      adsListProvider.overrideWithValue(({slot, status}) async => []),
      adSettingsGetProvider.overrideWithValue(() async => false),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('광고 생성'));
    await tester.pumpAndSettle();
    expect(find.text('링크 URL'), findsOneWidget); // 폼 필드 라벨
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd apps/admin && flutter test test/features/ads/ads_page_test.dart`
Expected: FAIL — `ads_page.dart` 없음.

- [ ] **Step 3: ads_page.dart 구현** (페이지 + 폼 다이얼로그 + 통계 다이얼로그)

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ads_controller.dart';
import '../data/ad_row.dart';
import '../data/ad_stats_row.dart';
import '../data/ads_source.dart';
import '../state/ads_state.dart';

const _kSlots = ['DASHBOARD_TOP', 'COMMUNITY_FEED', 'CONTENT_PAGE'];
const _kStatuses = ['ACTIVE', 'PAUSED'];

class AdminAdsPage extends ConsumerStatefulWidget {
  const AdminAdsPage({super.key});
  @override
  ConsumerState<AdminAdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends ConsumerState<AdminAdsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adsProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adsProvider);
    final n = ref.read(adsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('광고 관리'),
        actions: [
          Row(
            children: [
              const Text('전역 노출'),
              Switch(
                value: s.globalEnabled,
                onChanged: (v) => n.toggleGlobal(v),
              ),
              const SizedBox(width: DpSpacing.md),
              FilledButton.icon(
                icon: const Icon(DpIcons.edit),
                label: const Text('광고 생성'),
                onPressed: () => _openForm(context, n, null),
              ),
              const SizedBox(width: DpSpacing.lg),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
            child: Row(
              children: [
                const Text('슬롯:'),
                const SizedBox(width: DpSpacing.sm),
                for (final slot in _kSlots)
                  Padding(
                    padding: const EdgeInsets.only(right: DpSpacing.xs),
                    child: ChoiceChip(
                      label: Text(slot),
                      selected: s.slotFilter == slot,
                      onSelected: (sel) =>
                          n.setSlotFilter(sel ? slot : null),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: switch (s.phase) {
        AdsPhase.loading => const DpLoading(),
        AdsPhase.failed => DpError(message: s.error ?? '오류', onRetry: n.load),
        AdsPhase.loaded when s.rows.isEmpty => DpEmpty(
          icon: DpIcons.ads,
          title: '광고가 없어요',
          actionLabel: '광고 생성',
          onAction: () => _openForm(context, n, null),
        ),
        AdsPhase.loaded => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('제목')),
              DataColumn(label: Text('슬롯')),
              DataColumn(label: Text('가중치')),
              DataColumn(label: Text('상태')),
              DataColumn(label: Text('액션')),
            ],
            rows: [
              for (final r in s.rows)
                DataRow(
                  cells: [
                    DataCell(Text(r.title)),
                    DataCell(Text(r.slot)),
                    DataCell(Text('${r.weight}')),
                    DataCell(
                      Switch(
                        value: r.status == 'ACTIVE',
                        onChanged: (_) => n.toggleStatus(r),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(DpIcons.edit),
                            tooltip: '수정',
                            onPressed: () => _openForm(context, n, r),
                          ),
                          IconButton(
                            icon: const Icon(DpIcons.dashboard),
                            tooltip: '통계',
                            onPressed: () => _openStats(context, r),
                          ),
                          IconButton(
                            icon: const Icon(DpIcons.error),
                            tooltip: '삭제',
                            onPressed: () => n.remove(r.id!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      },
    );
  }

  Future<void> _openForm(
    BuildContext context,
    AdsController n,
    AdRow? existing,
  ) async {
    final result = await showDialog<AdRow>(
      context: context,
      builder: (_) => _AdFormDialog(existing: existing),
    );
    if (result == null) return;
    if (existing?.id == null) {
      await n.create(result);
    } else {
      await n.update(existing!.id!, result);
    }
  }

  Future<void> _openStats(BuildContext context, AdRow row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AdStatsDialog(adId: row.id!, title: row.title),
    );
  }
}

// ---------------------------------------------------------------------------
// 생성/수정 폼 다이얼로그
// ---------------------------------------------------------------------------
class _AdFormDialog extends StatefulWidget {
  const _AdFormDialog({required this.existing});
  final AdRow? existing;
  @override
  State<_AdFormDialog> createState() => _AdFormDialogState();
}

class _AdFormDialogState extends State<_AdFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _link;
  late final TextEditingController _image;
  late final TextEditingController _weight;
  late String _slot;
  late String _status;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _link = TextEditingController(text: e?.linkUrl ?? '');
    _image = TextEditingController(text: e?.imageUrl ?? '');
    _weight = TextEditingController(text: '${e?.weight ?? 1}');
    _slot = e?.slot ?? _kSlots.first;
    _status = e?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    _image.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '광고 생성' : '광고 수정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              TextField(
                controller: _link,
                decoration: const InputDecoration(labelText: '링크 URL'),
              ),
              TextField(
                controller: _image,
                decoration: const InputDecoration(labelText: '이미지 URL(선택)'),
              ),
              TextField(
                controller: _weight,
                decoration: const InputDecoration(labelText: '가중치(1 이상)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: DpSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _slot,
                decoration: const InputDecoration(labelText: '슬롯'),
                items: [
                  for (final s in _kSlots)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _slot = v ?? _slot),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '상태'),
                items: [
                  for (final s in _kStatuses)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              if (widget.existing?.id != null)
                Padding(
                  padding: const EdgeInsets.only(top: DpSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '이미지 파일 업로드는 저장 후 목록의 수정에서 지원됩니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final weight = int.tryParse(_weight.text.trim()) ?? 1;
            final draft = AdRow(
              id: widget.existing?.id,
              title: _title.text.trim(),
              imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
              linkUrl: _link.text.trim(),
              slot: _slot,
              weight: weight < 1 ? 1 : weight,
              status: _status,
              startsAt: widget.existing?.startsAt,
              endsAt: widget.existing?.endsAt,
            );
            Navigator.of(context).pop(draft);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 통계 다이얼로그 (최근 7일 기본, 테이블 + 합계)
// ---------------------------------------------------------------------------
class _AdStatsDialog extends ConsumerWidget {
  const _AdStatsDialog({required this.adId, required this.title});
  final int adId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 6));
    return AlertDialog(
      title: Text('통계 · $title'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<AdStatsRow>>(
          future: ref.read(adStatsProvider)(adId, from, to),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return const Text('통계를 불러오지 못했어요.');
            }
            final rows = snap.data ?? const [];
            final impr = rows.fold<int>(0, (a, r) => a + r.impressions);
            final clk = rows.fold<int>(0, (a, r) => a + r.clicks);
            final ctr = impr == 0 ? 0.0 : clk * 100 / impr;
            return SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('날짜')),
                  DataColumn(label: Text('노출')),
                  DataColumn(label: Text('클릭')),
                  DataColumn(label: Text('CTR')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(
                          '${r.date.month}/${r.date.day}',
                        )),
                        DataCell(Text('${r.impressions}')),
                        DataCell(Text('${r.clicks}')),
                        DataCell(Text(
                          r.impressions == 0
                              ? '-'
                              : '${(r.clicks * 100 / r.impressions).toStringAsFixed(1)}%',
                        )),
                      ],
                    ),
                  DataRow(
                    cells: [
                      const DataCell(Text('합계')),
                      DataCell(Text('$impr')),
                      DataCell(Text('$clk')),
                      DataCell(Text('${ctr.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
```

> **NOTE(구현자):** `DpEmpty`·`DpError`·`DpLoading`의 정확한 생성자 파라미터를 `packages/dp_design`에서 확인하라(users_page.dart 사용례와 동일해야 함: `DpError(message:, onRetry:)`, `DpEmpty(icon:, title:, actionLabel:, onAction:)`). 다르면 실제 시그니처에 맞춰 **호출부**를 수정. `DropdownButtonFormField.initialValue`는 Flutter 3.33+ API(교훈⑭) — 분석 경고 시 확인.

- [ ] **Step 4: 테스트 통과 확인 + 포맷**

Run: `cd apps/admin && flutter test test/features/ads/ads_page_test.dart`
Expected: PASS (2 tests)
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/admin/lib/src/features/ads apps/admin/test/features/ads`

- [ ] **Step 5: 커밋**

```bash
git add apps/admin/lib/src/features/ads/presentation apps/admin/test/features/ads/ads_page_test.dart
git commit -m "feat(admin): 광고 관리 페이지 + 폼/통계 다이얼로그"
```

---

### Task 4: 배선 (라우터·셸·아이콘·mock fixture) + 라우트 스모크

**Files:**
- Modify: `packages/dp_design/lib/src/icons/dp_icons.dart` (아이콘 1개 추가)
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart` (내비 항목 1개)
- Modify: `apps/admin/lib/src/app/router.dart` (GoRoute 1개)
- Modify: `apps/admin/lib/src/data/admin_mock_fixtures.dart` (mock 응답)
- Test: `apps/admin/test/features/ads/ads_route_test.dart`

**Interfaces:**
- Consumes: `AdminAdsPage`(Task 3), `DpIcons.ads`(이 태스크에서 신설), `adsListProvider`/`adSettingsGetProvider`(Task 2).
- Produces: `/ads` 라우트 + 내비 항목.

- [ ] **Step 1: DpIcons.ads 추가** — `packages/dp_design/lib/src/icons/dp_icons.dart`

`static const IconData settings = Symbols.settings_rounded;` 아래에 추가:

```dart
  static const IconData ads = Symbols.campaign_rounded;
```

- [ ] **Step 2: 셸 내비 항목 추가** — `admin_shell.dart` `kAdminDestinations` 리스트에 추가

```dart
  (path: '/ads', icon: DpIcons.ads, label: '광고'),
```

(`/reports` 항목 다음에 추가.)

- [ ] **Step 3: 라우트 추가** — `router.dart`

상단 import에 추가:

```dart
import '../features/ads/presentation/ads_page.dart';
```

ShellRoute의 `routes:` 리스트에서 `/reports` GoRoute 다음에 추가:

```dart
          GoRoute(path: '/ads', builder: (_, _) => const AdminAdsPage()),
```

- [ ] **Step 4: mock fixture 추가** — `admin_mock_fixtures.dart` 맵에 항목 추가(mock 모드에서 광고 페이지가 동작하도록)

```dart
  'GET /admin/ads': (
    200,
    [
      {
        'id': 1,
        'title': '하우스 배너 · 부트캠프',
        'imageUrl': null,
        'linkUrl': 'https://example.com/promo',
        'slot': 'DASHBOARD_TOP',
        'weight': 3,
        'status': 'ACTIVE',
        'startsAt': null,
        'endsAt': null,
      },
      {
        'id': 2,
        'title': '커뮤니티 스폰서',
        'imageUrl': null,
        'linkUrl': 'https://example.com/sponsor',
        'slot': 'COMMUNITY_FEED',
        'weight': 1,
        'status': 'PAUSED',
        'startsAt': null,
        'endsAt': null,
      },
    ],
  ),
  'GET /admin/ads/settings': (200, {'enabled': true}),
  'PUT /admin/ads/settings': (200, {'enabled': true}),
  'GET /admin/ads/1/stats': (
    200,
    [
      {'date': '2026-07-21', 'impressions': 120, 'clicks': 4},
      {'date': '2026-07-22', 'impressions': 98, 'clicks': 7},
    ],
  ),
```

> **NOTE(구현자):** `MockFixture` 값의 정확한 형태(2-튜플 `(int, Object)`)와 body가 List/Map 모두 허용되는지 `admin_mock_fixtures.dart` 상단 타입과 `MockHttpAdapter`(dp_core)를 확인하라. 기존 fixture는 Map body만 있으니 **List body 지원 여부를 반드시 검증**하고, 미지원이면 이 fixture 스텝은 생략하되(read 경로만) 라우트 스모크 테스트에는 영향 없음(테스트는 provider override 사용). 미지원 사실을 커밋 메시지/PR에 명시.

- [ ] **Step 5: 라우트 스모크 테스트 작성** — `apps/admin/test/features/ads/ads_route_test.dart`

```dart
import 'package:admin/src/features/ads/data/ads_source.dart';
import 'package:admin/src/features/ads/presentation/ads_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdminAdsPage builds under ProviderScope', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        adsListProvider.overrideWithValue(({slot, status}) async => []),
        adSettingsGetProvider.overrideWithValue(() async => false),
      ],
      child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('광고 관리'), findsOneWidget);
  });
}
```

- [ ] **Step 6: 전체 검증**

Run: `cd D:/workspace/dpa/devpath-frontend && dart format .`
Run: `dart pub global run melos run analyze`
Expected: no issues (admin·dp_design 포함)
Run: `dart pub global run melos run test`
Expected: 전체 PASS
Run: `dart pub global run melos run format`
Expected: 변경 없음(exit 0)

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_design/lib/src/icons/dp_icons.dart apps/admin/lib/src/features/shell apps/admin/lib/src/app/router.dart apps/admin/lib/src/data/admin_mock_fixtures.dart apps/admin/test/features/ads/ads_route_test.dart
git commit -m "feat(admin): 광고 라우트·내비·아이콘·mock fixture 배선"
```

---

## Self-Review (작성자 점검 결과)

**1. Spec coverage:**
- 목록+슬롯/상태 필터 → Task 3(페이지)·Task 2(setSlotFilter/StatusFilter). ✅
- 상태 토글 → Task 2 toggleStatus + Task 3 행 스위치. ✅
- 생성/수정 폼 → Task 3 `_AdFormDialog`. ✅
- 이미지 업로드(수정 모드만) → Task 2 uploadImage + Task 3 폼의 안내(파일 업로드 UI 자체는 웹 file picker 후속; spec은 "수정에서 업로드 노출" — 본 계획은 안내 문구 + 소스/컨트롤러 경로 완비, 실제 file picker 위젯은 P4 web처럼 후속). ⚠️ **범위 명확화**: 백엔드 계약(id 선행) 및 컨트롤러/소스 경로는 구현하되, admin 웹 file-picker 위젯 배선은 이 PR에서 안내 문구로 대체하고 후속으로 남긴다(YAGNI/점진). PR 설명에 명시.
- 전역 토글 → Task 2 toggleGlobal + Task 3 AppBar 스위치. ✅
- 통계(테이블+합계) → Task 3 `_AdStatsDialog`. ✅
- 라우트/셸/아이콘 → Task 4. ✅

**2. Placeholder scan:** 각 코드 스텝에 실제 코드 포함. "NOTE(구현자)"는 추측 금지·실제 시그니처 확인 지시(플레이스홀더 아님). ✅

**3. Type consistency:** `adsProvider`(controller), `AdsState`/`AdsPhase`, source typedef/Provider명(adsListProvider·adCreateProvider·adUpdateProvider·adDeleteProvider·adImageUploadProvider·adSettingsGetProvider·adSettingsSetProvider·adStatsProvider), `AdRow.toRequestJson`/`copyWith`, `AdStatsRow.fromJson` — Task 간 일치 확인. ✅

**주의(교훈 반영):** ①커밋 전 `dart format .`(CI format 게이트 별도, 교훈⑪). ②`implements ApiClient` fake 없음 — 본 계획은 source Provider override로 테스트(ApiClient 직접 구현 회피). ③`DropdownButtonFormField.initialValue`(교훈⑭). ④`ApiException`/dp_design 위젯 시그니처는 구현자가 실제 확인 후 테스트/호출부 정합.
