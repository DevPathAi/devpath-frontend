# 베타 광고 web 위젯 (P3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** web 앱 3개 슬롯(대시보드 상단·커뮤니티 피드 5번째 뒤·콘텐츠 페이지)에 fail-silent 광고 위젯을 넣고, 뷰포트 가시 시 IMPRESSION 1회·클릭 시 CLICK 이벤트를 측정한다.

**Architecture:** 신규 `apps/web/lib/src/features/ads/`(data/application/presentation). 단일 `AdSlotWidget(slot:)`이 3슬롯 공용. 서빙 fetch는 fail-silent(204/에러→null). 링크 오픈은 `oauth_launcher` 조건부-import 패턴 미러링. 가시성은 `visibility_detector`.

**Tech Stack:** Flutter Web · Riverpod 3.0 · dp_core(ApiClient) · dp_design · visibility_detector · package:web.

## Global Constraints

- 명령: 루트에서 `melos run analyze`·`melos run test`·`melos run format`(CI 게이트). 커밋 전 `dart format .`.
- 브랜치: `feat/web-ads-widget`(develop 분기됨). develop으로 PR.
- test-first. Riverpod 3.0: 테스트에 `List<Override>` 타입 명시 금지 → 인라인 `ProviderScope(overrides:[...])`/`ProviderContainer(overrides:[...])`.
- fail-silent: 광고 fetch 실패·204 → 위젯이 `SizedBox.shrink()`. 이벤트 발사 실패는 삼킴.
- 서빙 계약: `GET /ads?slot=` → 200 `AdView{id,title,imageUrl?,linkUrl,slot}` 또는 204. `POST /ads/{id}/events` body `{type:"IMPRESSION"|"CLICK"}`.
- 슬롯 상수: `DASHBOARD_TOP`·`COMMUNITY_FEED`·`CONTENT_PAGE`.
- 경로: 신규=`apps/web/lib/src/features/ads/{data,application,presentation}/`, 테스트=`apps/web/test/features/ads/`.

---

### Task 1: AdView 모델 + ads_source (fail-silent fetch/event)

**Files:**
- Create: `apps/web/lib/src/features/ads/data/ad_view.dart`
- Create: `apps/web/lib/src/features/ads/data/ads_source.dart`
- Test: `apps/web/test/features/ads/ads_source_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`(web `providers/api_providers.dart` — 정확 경로는 기존 web feature source에서 확인, 예: `apps/web/lib/src/providers/api_providers.dart`).
- Produces:
  - `class AdView` — `int id, String title, String? imageUrl, String linkUrl, String slot`; `factory AdView.fromJson(Map<String,dynamic>)`.
  - `typedef AdFetch = Future<AdView?> Function(String slot);` → `adFetchProvider`.
  - `typedef AdEvent = Future<void> Function(int id, String type);` → `adEventProvider`.

- [ ] **Step 1: 실패 테스트 작성** — `apps/web/test/features/ads/ads_source_test.dart`

```dart
import 'package:devpath_web/src/features/ads/data/ad_view.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const ApiException(code: ApiErrorCode.unknown, message: 'boom');
}

void main() {
  test('AdView.fromJson parses fields', () {
    final a = AdView.fromJson({
      'id': 3,
      'title': '광고',
      'imageUrl': null,
      'linkUrl': 'https://e.com',
      'slot': 'DASHBOARD_TOP',
    });
    expect(a.id, 3);
    expect(a.linkUrl, 'https://e.com');
    expect(a.imageUrl, isNull);
  });

  test('adFetchProvider returns null on ApiException (fail-silent)', () async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_ThrowingClient())],
    );
    addTearDown(c.dispose);
    final result = await c.read(adFetchProvider)('DASHBOARD_TOP');
    expect(result, isNull);
  });
}
```

> **NOTE(구현자):** ① `apiClientProvider`의 정확한 import 경로를 기존 web source(예 `features/mypage/data/mypage_source.dart`)에서 확인해 맞춰라. ② `ApiClient`가 `abstract`/`class`인지 확인 — `implements ApiClient` fake가 컴파일되는지(안 되면 `apiClientProvider.overrideWith((ref)=>...)` 대신 fetch 결과를 다른 방식으로 던지게). dp_core `ApiClient`는 dio 래핑 클래스이므로 `noSuchMethod` fake가 통상 동작. ③ web 앱 패키지명이 `devpath_web`가 맞는지 `apps/web/pubspec.yaml`에서 확인.

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd apps/web && flutter test test/features/ads/ads_source_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: ad_view.dart 구현**

```dart
/// 서빙 광고 뷰(읽기 전용). 백엔드 AdView 계약.
class AdView {
  const AdView({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.slot,
  });

  final int id;
  final String title;
  final String? imageUrl;
  final String linkUrl;
  final String slot;

  factory AdView.fromJson(Map<String, dynamic> json) => AdView(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    imageUrl: json['imageUrl'] as String?,
    linkUrl: json['linkUrl'] as String,
    slot: json['slot'] as String,
  );
}
```

- [ ] **Step 4: ads_source.dart 구현**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import 'ad_view.dart';

typedef AdFetch = Future<AdView?> Function(String slot);
typedef AdEvent = Future<void> Function(int id, String type);

/// GET /ads?slot= — 200이면 AdView, 204/에러면 null(fail-silent).
final adFetchProvider = Provider<AdFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (slot) async {
    try {
      final json = await client.get<Map<String, dynamic>?>(
        '/ads',
        query: {'slot': slot},
      );
      if (json == null || json.isEmpty) return null; // 204 → 빈 본문
      return AdView.fromJson(json);
    } catch (_) {
      return null; // fail-silent
    }
  };
});

/// POST /ads/{id}/events — 측정. 실패는 조용히 무시.
final adEventProvider = Provider<AdEvent>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id, type) async {
    try {
      await client.post<void>('/ads/$id/events', body: {'type': type});
    } catch (_) {
      // 측정 유실 허용
    }
  };
});
```

> **NOTE(구현자):** dio가 204를 어떻게 반환하는지 확인 — `get<Map<String,dynamic>?>`에서 204 본문은 보통 `null` 또는 빈 문자열. 만약 dio가 빈 문자열을 반환해 캐스팅 예외가 나면 `catch`가 잡아 null 반환하므로 fail-silent 유지된다(문제 없음). 실제 204 동작을 6단계 로컬 스모크에서 확인.

- [ ] **Step 5: 테스트 통과 확인 + 포맷**

Run: `cd apps/web && flutter test test/features/ads/ads_source_test.dart`
Expected: PASS (2 tests). fake/경로 이슈 시 NOTE대로 실제에 맞춰 테스트 정정.
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/web/lib/src/features/ads apps/web/test/features/ads`

- [ ] **Step 6: 커밋**

```bash
git add apps/web/lib/src/features/ads/data apps/web/test/features/ads/ads_source_test.dart
git commit -m "feat(web): 광고 서빙 소스(AdView·fail-silent fetch/event)"
```

---

### Task 2: AdLinkOpener (조건부 import)

**Files:**
- Create: `apps/web/lib/src/features/ads/application/ad_link_opener.dart`
- Create: `apps/web/lib/src/features/ads/application/ad_link_opener_web.dart`
- Create: `apps/web/lib/src/features/ads/application/ad_link_opener_stub.dart`

**Interfaces:**
- Produces: `abstract interface class AdLinkOpener { void open(String url); }`; `final adLinkOpenerProvider = Provider<AdLinkOpener>((ref) => createAdLinkOpener());`; `AdLinkOpener createAdLinkOpener()`(조건부).
- 참조: 기존 `apps/web/lib/src/features/auth/application/oauth_launcher*.dart` 패턴과 1:1 대응.

- [ ] **Step 1: ad_link_opener.dart (인터페이스 + provider + 조건부 import)**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_link_opener_web.dart'
    if (dart.library.io) 'ad_link_opener_stub.dart';

/// 광고 클릭 시 외부 링크를 새 탭으로 연다. 테스트에서 Fake로 교체.
abstract interface class AdLinkOpener {
  void open(String url);
}

final adLinkOpenerProvider = Provider<AdLinkOpener>(
  (ref) => createAdLinkOpener(),
);
```

- [ ] **Step 2: ad_link_opener_web.dart (웹 구현)**

```dart
import 'package:web/web.dart' as web;

import 'ad_link_opener.dart';

/// 웹: 새 탭으로 링크 오픈.
class _WebAdLinkOpener implements AdLinkOpener {
  const _WebAdLinkOpener();

  @override
  void open(String url) {
    web.window.open(url, '_blank');
  }
}

AdLinkOpener createAdLinkOpener() => const _WebAdLinkOpener();
```

- [ ] **Step 3: ad_link_opener_stub.dart (VM/테스트 스텁)**

```dart
import 'ad_link_opener.dart';

class _StubAdLinkOpener implements AdLinkOpener {
  const _StubAdLinkOpener();

  @override
  void open(String url) {
    throw UnsupportedError(
      'AdLinkOpener.open is not supported on non-web platforms. '
      'Override adLinkOpenerProvider in tests with a Fake.',
    );
  }
}

AdLinkOpener createAdLinkOpener() => const _StubAdLinkOpener();
```

- [ ] **Step 4: analyze로 컴파일 확인 + 포맷**

Run: `cd apps/web && flutter analyze lib/src/features/ads/application`
Expected: no issues (조건부 import 해석 OK)
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/web/lib/src/features/ads/application`

- [ ] **Step 5: 커밋**

```bash
git add apps/web/lib/src/features/ads/application
git commit -m "feat(web): 광고 링크 오프너(조건부 import, 새 탭)"
```

---

### Task 3: AdSlotWidget (fail-silent · 가시 impression · 클릭)

**Files:**
- Modify: `apps/web/pubspec.yaml` (visibility_detector 의존 추가)
- Create: `apps/web/lib/src/features/ads/presentation/ad_slot_widget.dart`
- Test: `apps/web/test/features/ads/ad_slot_widget_test.dart`

**Interfaces:**
- Consumes: `adFetchProvider`·`adEventProvider`(Task 1), `adLinkOpenerProvider`(Task 2), `AdView`.
- Produces: `class AdSlotWidget extends ConsumerStatefulWidget` — `const AdSlotWidget({super.key, required this.slot}); final String slot;`.

- [ ] **Step 1: visibility_detector 의존 추가**

`apps/web/pubspec.yaml`의 `dependencies:`에 추가(정확 버전은 `flutter pub add`로 해석):

Run: `cd apps/web && flutter pub add visibility_detector`
그 후 Run: `cd D:/workspace/dpa/devpath-frontend && dart pub global run melos bootstrap`
Expected: 의존 해석 성공. 실패 시(워크스페이스 제약 충돌) 버전을 낮춰 재시도하고 결과를 기록.

- [ ] **Step 2: 실패 위젯 테스트 작성** — `apps/web/test/features/ads/ad_slot_widget_test.dart`

```dart
import 'package:devpath_web/src/features/ads/application/ad_link_opener.dart';
import 'package:devpath_web/src/features/ads/data/ad_view.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/ads/presentation/ad_slot_widget.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FakeOpener implements AdLinkOpener {
  String? opened;
  @override
  void open(String url) => opened = url;
}

AdView _ad() => const AdView(
  id: 5,
  title: '테스트 광고',
  imageUrl: null,
  linkUrl: 'https://e.com/land',
  slot: 'DASHBOARD_TOP',
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('fetch→null renders nothing (fail-silent)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue((slot) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('광고'), findsNothing);
  });

  testWidgets('fetch→AdView renders title and 광고 label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue((slot) async => _ad()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('테스트 광고'), findsOneWidget);
    expect(find.text('광고'), findsOneWidget);
  });

  testWidgets('tap fires CLICK and opens link', (tester) async {
    final events = <String>[];
    final opener = _FakeOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue((slot) async => _ad()),
          adEventProvider.overrideWithValue((id, type) async {
            events.add('$id:$type');
          }),
          adLinkOpenerProvider.overrideWithValue(opener),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(opener.opened, 'https://e.com/land');
    expect(events, contains('5:CLICK'));
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd apps/web && flutter test test/features/ads/ad_slot_widget_test.dart`
Expected: FAIL — `ad_slot_widget.dart` 없음.

- [ ] **Step 4: ad_slot_widget.dart 구현**

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../application/ad_link_opener.dart';
import '../data/ad_view.dart';
import '../data/ads_source.dart';

/// 슬롯 공용 광고 위젯. fail-silent: 광고 없으면 아무것도 그리지 않는다.
class AdSlotWidget extends ConsumerStatefulWidget {
  const AdSlotWidget({super.key, required this.slot});
  final String slot;

  @override
  ConsumerState<AdSlotWidget> createState() => _AdSlotWidgetState();
}

class _AdSlotWidgetState extends ConsumerState<AdSlotWidget> {
  AdView? _ad;
  bool _impressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final ad = await ref.read(adFetchProvider)(widget.slot);
    if (!mounted) return;
    setState(() => _ad = ad);
  }

  void _onVisible(double fraction) {
    if (_impressed || _ad == null) return;
    if (fraction >= 0.5) {
      _impressed = true;
      ref.read(adEventProvider)(_ad!.id, 'IMPRESSION');
    }
  }

  void _onTap() {
    final ad = _ad;
    if (ad == null) return;
    ref.read(adEventProvider)(ad.id, 'CLICK');
    ref.read(adLinkOpenerProvider).open(ad.linkUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return VisibilityDetector(
      key: Key('ad-${widget.slot}-${ad.id}'),
      onVisibilityChanged: (info) => _onVisible(info.visibleFraction),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
        child: InkWell(
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.md),
            child: Row(
              children: [
                if (ad.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: DpSpacing.md),
                    child: Image.network(
                      ad.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 64, height: 64),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('광고', style: text.labelSmall?.copyWith(
                        color: c.textSecondary,
                      )),
                      const SizedBox(height: DpSpacing.xs),
                      Text(ad.title, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

> **NOTE(구현자):** `context.dpColors`·`text.labelSmall`·`DpSpacing` 존재 확인(dashboard_page.dart 등 기존 사용례와 동일). `Image.network` `errorBuilder`의 인자 3개 시그니처 확인(`(context, error, stackTrace)`).

- [ ] **Step 5: 테스트 통과 확인 + 포맷**

Run: `cd apps/web && flutter test test/features/ads/ad_slot_widget_test.dart`
Expected: PASS (3 tests)
Run: `cd D:/workspace/dpa/devpath-frontend && dart format apps/web/lib/src/features/ads apps/web/test/features/ads`

- [ ] **Step 6: 커밋**

```bash
git add apps/web/pubspec.yaml apps/web/lib/src/features/ads/presentation apps/web/test/features/ads/ad_slot_widget_test.dart D:/workspace/dpa/devpath-frontend/pubspec.lock
git commit -m "feat(web): AdSlotWidget(가시 impression·클릭·fail-silent) + visibility_detector"
```

> pubspec.lock 경로는 워크스페이스 루트일 수 있음 — `git status`로 실제 변경된 lock 파일을 add.

---

### Task 4: 3개 슬롯 배선 + 전체 검증

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart`
- Modify: `apps/web/lib/src/features/content/presentation/content_page.dart`

**Interfaces:**
- Consumes: `AdSlotWidget`(Task 3).

- [ ] **Step 1: 대시보드 상단 배선** — `dashboard_page.dart`

상단 import에 추가:

```dart
import '../../ads/presentation/ad_slot_widget.dart';
```

`_Body.build`의 `ListView(... children: [` **바로 다음(첫 자식)** 에 삽입:

```dart
        const AdSlotWidget(slot: 'DASHBOARD_TOP'),
```

(기존 `// 1) 스트릭` 카드 앞에 위치.)

- [ ] **Step 2: 커뮤니티 피드 5번째 뒤 배선** — `community_home_page.dart`

상단 import에 추가:

```dart
import '../../ads/presentation/ad_slot_widget.dart';
```

`CommunityPhase.loaded => ListView.separated(` 블록을 아래로 교체(광고를 인덱스 5에 삽입):

```dart
        CommunityPhase.loaded => Builder(
          builder: (_) {
            final showAd = s.posts.length >= 5;
            return ListView.separated(
              padding: const EdgeInsets.all(DpSpacing.lg),
              itemCount: s.posts.length + (showAd ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: DpSpacing.sm),
              itemBuilder: (_, i) {
                if (showAd && i == 5) {
                  return const AdSlotWidget(slot: 'COMMUNITY_FEED');
                }
                final idx = (showAd && i > 5) ? i - 1 : i;
                final p = s.posts[idx];
                final c = context.dpColors;
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        if (p.solved)
                          Padding(
                            padding: const EdgeInsets.only(right: DpSpacing.xs),
                            child: Icon(
                              DpIcons.stepDone,
                              size: 18,
                              color: c.success,
                            ),
                          ),
                        Expanded(child: Text(p.title)),
                      ],
                    ),
                    subtitle: Text(
                      '답변 ${p.answerCount} · 추천 ${p.upvoteCount}',
                      style: TextStyle(color: c.textSecondary),
                    ),
                    onTap: () => context.go('/community/${p.id}'),
                  ),
                );
              },
            );
          },
        ),
```

> **NOTE(구현자):** 위 카드 렌더는 **기존 itemBuilder 본문을 그대로 옮긴 것**이다. 실제 파일의 현재 itemBuilder 전체(닫는 `);`·`}` 포함)를 정확히 복사해 idx 인덱싱만 바꿔라. 기존 코드에 없는 필드를 추측 추가하지 말 것.

- [ ] **Step 3: 콘텐츠 페이지 배선** — `content_page.dart`

상단 import에 추가:

```dart
import '../../ads/presentation/ad_slot_widget.dart';
```

`_ContentBody`의 `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ ... ]`에서 **children 리스트 말미(닫는 `]` 직전)** 에 추가:

```dart
              const SizedBox(height: DpSpacing.lg),
              const AdSlotWidget(slot: 'CONTENT_PAGE'),
```

> **NOTE(구현자):** `_ContentBody` `Column`의 children 끝을 파일에서 찾아(본문 렌더 마지막 위젯 뒤, `],` 직전) 위 2줄을 삽입. 다른 Column과 혼동하지 말 것(maxWidth 840 ConstrainedBox 내부의 그 Column).

- [ ] **Step 4: 전체 검증**

Run: `cd D:/workspace/dpa/devpath-frontend && dart format .`
Run: `dart pub global run melos run analyze`
Expected: no issues (web 포함)
Run: `dart pub global run melos run test`
Expected: 전체 PASS(기존 dashboard/community/content 위젯 테스트 포함 — 광고 삽입으로 깨지면 해당 테스트의 finder를 조정하되, 광고는 fetch 미override 시 fail-silent라 대개 영향 없음)
Run: `dart pub global run melos run format`
Expected: 변경 없음(exit 0)

> **NOTE(구현자):** 기존 community/dashboard/content 위젯 테스트가 광고 위젯 삽입으로 실패하면, 그 테스트는 `adFetchProvider`를 override하지 않아 실제 fetch가 도는 것 — 테스트 환경 ApiClient가 mock이면 204/에러로 fail-silent(SizedBox.shrink)라 영향 없음. 만약 실패하면 원인을 읽고(광고 카드가 finder에 걸리는지) 필요한 최소 조정만.

- [ ] **Step 5: 커밋**

```bash
git add apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart apps/web/lib/src/features/community/presentation/community_home_page.dart apps/web/lib/src/features/content/presentation/content_page.dart
git commit -m "feat(web): 대시보드·커뮤니티(5번째 뒤)·콘텐츠 슬롯에 광고 배선"
```

---

## Self-Review (작성자 점검 결과)

**1. Spec coverage:**
- AdView·fail-silent fetch/event → Task 1. ✅
- 링크 오프너(새 탭) → Task 2. ✅
- 단일 AdSlotWidget·가시 impression 1회·클릭·"광고" 라벨·이미지 폴백 → Task 3. ✅
- 3슬롯 배선(대시보드 상단·커뮤니티 5번째 뒤·콘텐츠) → Task 4. ✅
- visibility_detector 의존 → Task 3 Step 1. ✅

**2. Placeholder scan:** 각 코드 스텝 실제 코드 포함. "NOTE(구현자)"는 실제 시그니처·경로 확인 지시(추측 금지). ✅

**3. Type consistency:** `adFetchProvider`/`adEventProvider`(typedef AdFetch/AdEvent), `AdView.fromJson`, `AdLinkOpener.open`/`adLinkOpenerProvider`, `AdSlotWidget(slot:)` — Task 간 일치. ✅

**주의(교훈 반영):** ①커밋 전 `dart format .`(CI format 게이트 별도, 교훈⑪). ②Riverpod 3.0 `List<Override>` 타입 명시 금지 — 인라인 override(교훈⑫). ③`ApiClient` fake는 `noSuchMethod`로(인터페이스 확장 파급 회피). ④web 패키지명(`devpath_web`)·`apiClientProvider` 경로는 구현자가 실제 확인.
