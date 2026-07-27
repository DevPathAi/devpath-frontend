# 마이페이지 P4 — frontend features/mypage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans 또는 subagent-driven-development. 단계는 체크박스(`- [ ]`).

**Goal:** `apps/web`에 마이페이지(`/mypage`)를 구현한다 — 프로필 표시/편집·avatar 업로드·활동 집계(완료수·질문/답변수)를 각 svc API를 병렬 호출·합성(부분실패 내성)해 렌더한다.

**Architecture:** dp_core에 `ProfileView`·`MyActivity` freezed 모델 + `ApiClient.postMultipart`(dio FormData). `features/mypage`는 `mypage_source`(Provider<Fetch>)·`mypage_state`(sealed)·`mypage_controller`(Notifier, 병렬 로드·합성·부분실패·저장·avatar)·`mypage_page`. 라우터 ShellRoute에 `/mypage`, 셸에 프로필 아이콘 진입.

**Tech Stack:** Flutter · Riverpod(Notifier) · freezed/json_serializable(codegen) · go_router · dio(FormData) · melos 7

## Global Constraints

- 브랜치: `feat/mypage`(develop에서 분기). 신규 작업은 이 브랜치에서만.
- 백엔드 계약(전부 머지됨): `GET/PUT /users/me/profile`→`ProfileView{avatar,bio,learningGoal,targetTrack,experienceYears}`(모두 nullable), `POST/DELETE /users/me/avatar`(multipart part=`file`)→ProfileView, `GET /dashboard/me`(+`completedContentCount`), `GET /community/me/activity`→`{questionCount,answerCount}`, `GET /users/me`→User(요약).
- 에러: `ApiException`(dp_core). 프로필 실패=전체 에러+재시도, 집계 svc 부분 실패=해당 섹션만 에러(전체 유지).
- 검증(눈으로): `cd D:\workspace\dpa\devpath-frontend && dart pub global run melos run analyze` + `melos run test`. codegen: `cd packages/dp_core && dart run build_runner build --delete-conflicting-outputs`.
- 패턴 준수: controller=`Notifier<State>`+`NotifierProvider`, source=`Provider<typedef Fetch>`+`ref.watch(apiClientProvider)`, model=freezed(`part '*.freezed.dart'`+`part '*.g.dart'`). 테스트=`flutter_test`+`ProviderContainer`(inline override).
- `implements ApiClient` fake는 `postMultipart` 추가 시 컴파일 깨짐 → 반드시 2곳 override: `apps/web/test/features/dashboard/dashboard_controller_test.dart`(_CapturingApiClient), `apps/web/test/golden_path_onboarding_test.dart`(_NewUserFirstApiClient).
- **[rebase 갱신 2026-07-05] develop #69(consent/settings)가 `ApiClient.put`·`delete`를 이미 추가했다.** 따라서 Task 3 Step 2(put 추가)는 **생략**하고 기존 `client.put`을 그대로 쓴다. fake 2곳에도 put/delete override가 이미 있을 것이므로(구현 시 실측), P4는 `postMultipart` override만 추가한다.

---

## File Structure

- Create `packages/dp_core/lib/src/models/profile_view.dart` (+ codegen `.freezed.dart`/`.g.dart`)
- Create `packages/dp_core/lib/src/models/my_activity.dart` (+ codegen)
- Modify `packages/dp_core/lib/src/models/dashboard_summary.dart` — `completedContentCount` 추가
- Modify `packages/dp_core/lib/dp_core.dart` — 신규 모델 export
- Modify `packages/dp_core/lib/src/api/api_client.dart` — `postMultipart`
- Modify fake 2곳(위 Global Constraints)
- Create `apps/web/lib/src/features/mypage/data/mypage_source.dart`
- Create `apps/web/lib/src/features/mypage/state/mypage_state.dart`
- Create `apps/web/lib/src/features/mypage/application/mypage_controller.dart`
- Create `apps/web/lib/src/features/mypage/presentation/mypage_page.dart`
- Modify `apps/web/lib/src/app/router.dart` — `/mypage` GoRoute
- Modify `apps/web/lib/src/features/shell/presentation/app_shell.dart` — 프로필 아이콘 진입
- Test: `apps/web/test/features/mypage/mypage_controller_test.dart`

---

## Task 1: dp_core 모델 (ProfileView·MyActivity·DashboardSummary 확장)

**Files:** Create `profile_view.dart`·`my_activity.dart`; Modify `dashboard_summary.dart`·`dp_core.dart`

**Interfaces — Produces:** `ProfileView{String? avatar,bio,learningGoal,targetTrack; int? experienceYears}`, `MyActivity{int questionCount,answerCount}`, `DashboardSummary.completedContentCount:int`

- [ ] **Step 1: profile_view.dart 작성**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_view.freezed.dart';
part 'profile_view.g.dart';

/// 마이페이지 프로필(platform GET/PUT /users/me/profile). 미저장 시 전부 null.
@freezed
abstract class ProfileView with _$ProfileView {
  const factory ProfileView({
    String? avatar,
    String? bio,
    String? learningGoal,
    String? targetTrack,
    int? experienceYears,
  }) = _ProfileView;

  factory ProfileView.fromJson(Map<String, dynamic> json) =>
      _$ProfileViewFromJson(json);
}
```

- [ ] **Step 2: my_activity.dart 작성**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_activity.freezed.dart';
part 'my_activity.g.dart';

/// 커뮤니티 활동 집계(GET /community/me/activity).
@freezed
abstract class MyActivity with _$MyActivity {
  const factory MyActivity({
    @Default(0) int questionCount,
    @Default(0) int answerCount,
  }) = _MyActivity;

  factory MyActivity.fromJson(Map<String, dynamic> json) =>
      _$MyActivityFromJson(json);
}
```

- [ ] **Step 3: dashboard_summary.dart에 completedContentCount 추가**

`dashboard_summary.dart`의 factory에 필드 추가(기존 필드 유지, `@Default(0)`로 하위호환):

```dart
  const factory DashboardSummary({
    required int streakDays,
    required int progressPercent,
    String? nextTaskTitle,
    @Default(<String>[]) List<String> badges,
    @Default(0) int completedContentCount,
  }) = _DashboardSummary;
```

- [ ] **Step 4: dp_core.dart에 export 추가**

`packages/dp_core/lib/dp_core.dart`에서 다른 `models/*.dart` export 옆에 추가:

```dart
export 'src/models/profile_view.dart';
export 'src/models/my_activity.dart';
```

(먼저 `dp_core.dart`를 열어 기존 export 라인 형식을 확인하고 동일 형식으로 추가.)

- [ ] **Step 5: codegen 실행**

Run: `cd D:\workspace\dpa\devpath-frontend\packages\dp_core && dart run build_runner build --delete-conflicting-outputs`
Expected: `profile_view.freezed.dart`·`profile_view.g.dart`·`my_activity.*` 생성, `dashboard_summary.*` 갱신, 에러 없음.

- [ ] **Step 6: 분석 확인 + 커밋**

Run: `cd D:\workspace\dpa\devpath-frontend && dart pub global run melos run analyze`
Expected: dp_core 분석 통과.

```bash
git add packages/dp_core/lib/src/models/profile_view.dart packages/dp_core/lib/src/models/my_activity.dart packages/dp_core/lib/src/models/dashboard_summary.dart packages/dp_core/lib/dp_core.dart packages/dp_core/lib/src/models/*.freezed.dart packages/dp_core/lib/src/models/*.g.dart
git commit -m "feat(mypage): dp_core ProfileView·MyActivity 모델 + DashboardSummary.completedContentCount"
```

---

## Task 2: ApiClient.postMultipart + fake 파급

**Files:** Modify `api_client.dart`; Modify fake 2곳

**Interfaces — Produces:** `Future<T> postMultipart<T>(String path, {required List<int> bytes, required String filename, String field, String? contentType})`

- [ ] **Step 1: fake override 실패 테스트 확인(선파급)**

먼저 `api_client.dart`에 `postMultipart`를 추가하면 `implements ApiClient` fake 2곳이 깨진다. Step 2에서 추가 후 Step 3에서 fake를 고친다.

- [ ] **Step 2: api_client.dart에 postMultipart 추가**

import에 `import 'package:http_parser/http_parser.dart';` 필요 여부는 `DioMediaType` 사용 방식으로 결정 — dio는 `DioMediaType`(재수출)을 제공하므로 별도 import 없이 `DioMediaType.parse`를 쓴다. `sse` 메서드 아래에 추가:

```dart
  /// multipart 업로드(part=[field]). 실패 시 [ApiException] throw.
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      field: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: contentType == null ? null : DioMediaType.parse(contentType),
      ),
    });
    try {
      final res = await dio.post<T>(path, data: form);
      return res.data as T;
    } on DioException catch (e) {
      throw (e.error is ApiException)
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
```

- [ ] **Step 3: fake 2곳에 postMultipart override 추가**

`apps/web/test/features/dashboard/dashboard_controller_test.dart`의 `_CapturingApiClient`에 추가:

```dart
  @override
  Future<T> postMultipart<T>(String path,
          {required List<int> bytes,
          required String filename,
          String field = 'file',
          String? contentType}) =>
      throw UnimplementedError();
```

`apps/web/test/golden_path_onboarding_test.dart`의 `_NewUserFirstApiClient`에 추가(inner 위임):

```dart
  @override
  Future<T> postMultipart<T>(String path,
          {required List<int> bytes,
          required String filename,
          String field = 'file',
          String? contentType}) =>
      _inner.postMultipart<T>(path,
          bytes: bytes, filename: filename, field: field, contentType: contentType);
```

- [ ] **Step 4: 분석 + 커밋**

Run: `cd D:\workspace\dpa\devpath-frontend && dart pub global run melos run analyze`
Expected: 통과(fake 포함 컴파일 OK).

```bash
git add packages/dp_core/lib/src/api/api_client.dart apps/web/test/features/dashboard/dashboard_controller_test.dart apps/web/test/golden_path_onboarding_test.dart
git commit -m "feat(mypage): ApiClient.postMultipart + fake 파급 정합"
```

---

## Task 3: mypage_source (API providers)

**Files:** Create `mypage_source.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `ProfileView`·`MyActivity`·`DashboardSummary`·`User`
- Produces: `myProfileFetchProvider`(`Future<ProfileView> Function()`), `myProfileUpdateProvider`(`Future<ProfileView> Function(Map<String,dynamic>)`), `myAvatarUploadProvider`(`Future<ProfileView> Function({required List<int> bytes, required String filename, String? contentType})`), `myDashboardFetchProvider`(`Future<DashboardSummary> Function()`), `myActivityFetchProvider`(`Future<MyActivity> Function()`)

- [ ] **Step 1: mypage_source.dart 작성**

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 마이페이지 데이터 레이어 — 각 svc REST를 apiClient로 호출. 목은 MockHttpAdapter가 처리.
typedef MyProfileFetch = Future<ProfileView> Function();
typedef MyProfileUpdate = Future<ProfileView> Function(Map<String, dynamic> body);
typedef MyAvatarUpload = Future<ProfileView> Function({
  required List<int> bytes,
  required String filename,
  String? contentType,
});
typedef MyDashboardFetch = Future<DashboardSummary> Function();
typedef MyActivityFetch = Future<MyActivity> Function();

final myProfileFetchProvider = Provider<MyProfileFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/users/me/profile');
    return ProfileView.fromJson(json);
  };
});

final myProfileUpdateProvider = Provider<MyProfileUpdate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (body) async {
    final json = await client.post<Map<String, dynamic>>('/users/me/profile',
        body: body);
    return ProfileView.fromJson(json);
  };
});
```

> 주의: PUT이다. `ApiClient`엔 `put`이 없다 — Step 2에서 `ApiClient.put`을 추가하거나 dio를 직접 쓴다. **결정: dp_core `ApiClient`에 `put` 헬퍼를 추가**(get/post와 동일 규약). 아래 Step 2.

- [ ] **Step 2: ApiClient.put 추가**(mypage_source가 PUT을 쓰므로)

`api_client.dart`의 `post` 아래에 추가:

```dart
  /// PUT 후 JSON 반환. (get/post 헬퍼와 동일 규약)
  Future<T> put<T>(String path, {Object? body}) async {
    try {
      final res = await dio.put<T>(path, data: body);
      return res.data as T;
    } on DioException catch (e) {
      throw (e.error is ApiException)
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
```

fake 2곳에도 `put` override 추가(_CapturingApiClient→UnimplementedError, _NewUserFirstApiClient→`_inner.put`). Task 2 Step 3과 동일 방식.

그리고 `mypage_source.dart`의 `myProfileUpdateProvider`를 `client.put`으로 수정:

```dart
    final json = await client.put<Map<String, dynamic>>('/users/me/profile',
        body: body);
```

- [ ] **Step 3: 나머지 provider 추가**(mypage_source.dart 이어서)

```dart
final myAvatarUploadProvider = Provider<MyAvatarUpload>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({required List<int> bytes, required String filename, String? contentType}) async {
    final json = await client.postMultipart<Map<String, dynamic>>(
      '/users/me/avatar',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return ProfileView.fromJson(json);
  };
});

final myDashboardFetchProvider = Provider<MyDashboardFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/dashboard/me');
    return DashboardSummary.fromJson(json);
  };
});

final myActivityFetchProvider = Provider<MyActivityFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return () async {
    final json = await client.get<Map<String, dynamic>>('/community/me/activity');
    return MyActivity.fromJson(json);
  };
});
```

- [ ] **Step 4: 분석 + 커밋**

Run: `melos run analyze` (통과). 
```bash
git add packages/dp_core/lib/src/api/api_client.dart apps/web/test/features/dashboard/dashboard_controller_test.dart apps/web/test/golden_path_onboarding_test.dart apps/web/lib/src/features/mypage/data/mypage_source.dart
git commit -m "feat(mypage): mypage_source(profile/avatar/dashboard/activity) + ApiClient.put"
```

---

## Task 4: mypage_state + mypage_controller (병렬 로드·합성·부분실패·저장·avatar) — TDD

**Files:** Create `mypage_state.dart`·`mypage_controller.dart`; Test `mypage_controller_test.dart`

**Interfaces:**
- Consumes: Task 3 provider들, `User`
- Produces: `MyPageController extends Notifier<MyPageState>`(`load()`·`saveProfile(Map)`·`uploadAvatar({bytes,filename,contentType})`), `myPageControllerProvider`

- [ ] **Step 1: mypage_state.dart 작성**

```dart
import 'package:dp_core/dp_core.dart';

/// 마이페이지 합성 상태. 프로필(핵심)은 필수, 집계 섹션은 부분 실패 허용.
sealed class MyPageState {
  const MyPageState();
}

class MyPageLoading extends MyPageState {
  const MyPageLoading();
}

/// 프로필 로드 성공. 집계(dashboard·activity)는 각각 null이면 해당 섹션 에러.
class MyPageLoaded extends MyPageState {
  const MyPageLoaded({
    required this.profile,
    this.dashboard,
    this.activity,
    this.saving = false,
  });
  final ProfileView profile;
  final DashboardSummary? dashboard; // null = 집계 섹션 실패
  final MyActivity? activity; // null = 집계 섹션 실패
  final bool saving;

  MyPageLoaded copyWith({
    ProfileView? profile,
    DashboardSummary? dashboard,
    MyActivity? activity,
    bool? saving,
  }) => MyPageLoaded(
    profile: profile ?? this.profile,
    dashboard: dashboard ?? this.dashboard,
    activity: activity ?? this.activity,
    saving: saving ?? this.saving,
  );
}

/// 프로필(핵심) 로드 실패 → 전체 에러+재시도.
class MyPageFailed extends MyPageState {
  const MyPageFailed(this.message);
  final String message;
}
```

- [ ] **Step 2: 실패 테스트 작성 — mypage_controller_test.dart**

```dart
import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/data/mypage_source.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerWith(List<Override> overrides) {
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }

  test('load()는 프로필+집계를 병렬 로드해 합성한다', () async {
    final c = containerWith([
      myProfileFetchProvider.overrideWithValue(
          () async => const ProfileView(bio: '백엔드 지망', targetTrack: 'BACKEND_SPRING')),
      myDashboardFetchProvider.overrideWithValue(
          () async => const DashboardSummary(streakDays: 3, progressPercent: 40, completedContentCount: 7)),
      myActivityFetchProvider.overrideWithValue(
          () async => const MyActivity(questionCount: 2, answerCount: 5)),
    ]);

    await c.read(myPageControllerProvider.notifier).load();
    final s = c.read(myPageControllerProvider);

    expect(s, isA<MyPageLoaded>());
    final loaded = s as MyPageLoaded;
    expect(loaded.profile.bio, '백엔드 지망');
    expect(loaded.dashboard?.completedContentCount, 7);
    expect(loaded.activity?.questionCount, 2);
  });

  test('집계 svc 부분 실패는 해당 섹션만 null, 전체 유지', () async {
    final c = containerWith([
      myProfileFetchProvider.overrideWithValue(() async => const ProfileView(bio: 'x')),
      myDashboardFetchProvider.overrideWithValue(
          () async => throw const ApiException(code: ApiErrorCode.serverError, message: 'down', status: 500)),
      myActivityFetchProvider.overrideWithValue(() async => const MyActivity(questionCount: 1, answerCount: 0)),
    ]);

    await c.read(myPageControllerProvider.notifier).load();
    final loaded = c.read(myPageControllerProvider) as MyPageLoaded;

    expect(loaded.dashboard, isNull); // 실패 섹션
    expect(loaded.activity?.questionCount, 1); // 성공 섹션 유지
  });

  test('프로필(핵심) 실패는 전체 MyPageFailed', () async {
    final c = containerWith([
      myProfileFetchProvider.overrideWithValue(
          () async => throw const ApiException(code: ApiErrorCode.serverError, message: '프로필 실패', status: 500)),
      myDashboardFetchProvider.overrideWithValue(
          () async => const DashboardSummary(streakDays: 0, progressPercent: 0)),
      myActivityFetchProvider.overrideWithValue(() async => const MyActivity()),
    ]);

    await c.read(myPageControllerProvider.notifier).load();
    expect(c.read(myPageControllerProvider), isA<MyPageFailed>());
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd D:\workspace\dpa\devpath-frontend\apps\web && flutter test test/features/mypage/mypage_controller_test.dart`
Expected: FAIL(컴파일 — MyPageController 없음).

- [ ] **Step 4: mypage_controller.dart 구현**

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mypage_source.dart';
import '../state/mypage_state.dart';

class MyPageController extends Notifier<MyPageState> {
  @override
  MyPageState build() => const MyPageLoading();

  Future<void> load() async {
    state = const MyPageLoading();
    // 프로필(핵심) 먼저 — 실패 시 전체 에러.
    final ProfileView profile;
    try {
      profile = await ref.read(myProfileFetchProvider)();
    } on ApiException catch (e) {
      state = MyPageFailed(e.message);
      return;
    }
    // 집계는 부분 실패 허용 — 각각 독립 try.
    DashboardSummary? dashboard;
    MyActivity? activity;
    final results = await Future.wait([
      _safe(() => ref.read(myDashboardFetchProvider)()),
      _safe(() => ref.read(myActivityFetchProvider)()),
    ]);
    dashboard = results[0] as DashboardSummary?;
    activity = results[1] as MyActivity?;
    state = MyPageLoaded(profile: profile, dashboard: dashboard, activity: activity);
  }

  Future<void> saveProfile(Map<String, dynamic> body) async {
    final cur = state;
    if (cur is! MyPageLoaded) return;
    state = cur.copyWith(saving: true);
    try {
      final updated = await ref.read(myProfileUpdateProvider)(body);
      state = cur.copyWith(profile: updated, saving: false);
    } on ApiException {
      state = cur.copyWith(saving: false);
      rethrow; // 화면이 스낵바로 처리
    }
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final cur = state;
    if (cur is! MyPageLoaded) return;
    state = cur.copyWith(saving: true);
    try {
      final updated = await ref.read(myAvatarUploadProvider)(
          bytes: bytes, filename: filename, contentType: contentType);
      state = cur.copyWith(profile: updated, saving: false);
    } on ApiException {
      state = cur.copyWith(saving: false);
      rethrow;
    }
  }

  Future<T?> _safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException {
      return null;
    }
  }
}

final myPageControllerProvider =
    NotifierProvider<MyPageController, MyPageState>(MyPageController.new);
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd apps/web && flutter test test/features/mypage/mypage_controller_test.dart`
Expected: PASS(3 tests).

- [ ] **Step 6: 커밋**

```bash
git add apps/web/lib/src/features/mypage/state/mypage_state.dart apps/web/lib/src/features/mypage/application/mypage_controller.dart apps/web/test/features/mypage/mypage_controller_test.dart
git commit -m "feat(mypage): mypage_controller 병렬로드·합성·부분실패·저장·avatar + 테스트"
```

---

## Task 5: mypage_page (UI)

**Files:** Create `mypage_page.dart`

**Interfaces:** Consumes `myPageControllerProvider`. `ConsumerStatefulWidget`(편집 폼 상태). dashboard_page.dart의 `ConsumerWidget`+상태 switch 패턴 참고(먼저 열어 dp_design 위젯/`context.dpColors`·`DpTheme` 사용법 확인).

- [ ] **Step 1: mypage_page.dart 작성**

프로필 헤더(avatar 또는 닉네임 이니셜 + 업로드/삭제 버튼), 편집 폼(bio·learningGoal·targetTrack·experienceYears), 활동 섹션(completedContentCount·questionCount·answerCount, null이면 섹션 에러 표시), 설정 진입 링크(`context.go('/settings')`). 상태 switch: `MyPageLoading`→`CircularProgressIndicator`, `MyPageFailed`→에러+재시도(`load()`), `MyPageLoaded`→본문. avatar 업로드는 `image_picker` 대신 web `FileUploadInputElement` 회피 — **범위 최소화**: 이번엔 `file_picker`가 dp 의존에 없으므로, 업로드 버튼은 `mypage_controller.uploadAvatar` 호출만 배선하고 바이트 획득은 후속(page 스모크 테스트는 표시/편집 위주). 정확한 위젯은 dashboard_page + dp_design 확인 후 동일 톤으로 작성.

> 구현 시 `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`와 `packages/dp_design`을 먼저 읽고 동일 컴포넌트/색상 토큰을 쓴다(추측 금지). 편집 폼은 `TextFormField`+로컬 컨트롤러, 저장 시 `saveProfile({'bio':..,'learningGoal':..,'targetTrack':..,'experienceYears':..})`.

- [ ] **Step 2: 페이지 스모크 테스트**(선택, 시간 허용 시) — `mypage_page_test.dart`로 `MyPageLoaded` 주입 후 bio 텍스트 렌더 확인.

- [ ] **Step 3: 분석 + 커밋**

Run: `melos run analyze` + `cd apps/web && flutter test test/features/mypage/`
```bash
git add apps/web/lib/src/features/mypage/presentation/mypage_page.dart apps/web/test/features/mypage/
git commit -m "feat(mypage): mypage_page 프로필 표시/편집·활동·설정 진입"
```

---

## Task 6: 라우팅 + 셸 진입점

**Files:** Modify `router.dart`·`app_shell.dart`

- [ ] **Step 1: router.dart에 /mypage 추가**

import에 `import '../features/mypage/presentation/mypage_page.dart';` 추가. ShellRoute의 `routes:` 안(예: `/community` 라우트들 뒤)에 추가:

```dart
          GoRoute(path: '/mypage', builder: (_, _) => const MyPagePage()),
```

(클래스명은 Task 5에서 정한 것과 일치시킨다 — 권장 `MyPagePage` 또는 `MyPageScreen`. Task 5 파일과 동일하게.)

- [ ] **Step 2: app_shell.dart에 프로필 아이콘 진입 추가**

`AppShellView.build`의 `Scaffold`에 프로필 진입을 추가한다. 셸 destination(kShellDestinations)에는 **넣지 않고**(spec §23), NavigationRail의 `trailing` 또는 상단 아이콘으로 `/mypage` 이동:

```dart
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      icon: const Icon(Icons.account_circle),
                      tooltip: '마이페이지',
                      onPressed: () => onSelect?.call('/mypage'),
                    ),
                  ),
                ),
              ),
              destinations: [ /* 기존 유지 */ ],
            ),
```

좁은 화면(NavigationBar)에서는 `AppBar`가 없으므로, 본문 상단에 프로필 IconButton을 두는 대신 **최소 범위**로 wide(Rail) trailing만 우선 배선하고, 좁은 화면 진입은 후속(스모크 영향 없음). `_index`가 `/mypage`에서 -1→0 되는 문제 없음(마이페이지는 destination 아님).

- [ ] **Step 3: 분석 + 전체 테스트 + 커밋**

Run: `cd D:\workspace\dpa\devpath-frontend && dart pub global run melos run analyze && dart pub global run melos run test`
Expected: 전체 그린(web·mobile·admin·dp_core·dp_design). fake 파급(postMultipart/put) 반영 확인.

```bash
git add apps/web/lib/src/app/router.dart apps/web/lib/src/features/shell/presentation/app_shell.dart
git commit -m "feat(mypage): /mypage 라우트 + 셸 프로필 진입"
git push -u origin feat/mypage
gh pr create --base develop --title "feat(mypage): ② 마이페이지 P4 frontend" --body "spec/plan: docs/superpowers/{specs,plans}/2026-07-05-mypage*. features/mypage(프로필 표시/편집·avatar·활동집계 합성·부분실패 내성) + dp_core ProfileView·MyActivity·ApiClient.postMultipart/put. P1~P3·스토리지 후속."
```

Expected: PR CI(melos analyze/test) 녹색.

---

## Self-Review

**1. Spec coverage:** 프로필 전체편집(Task4 saveProfile·Task5 폼)·avatar 업로드(Task2 postMultipart·Task3 source·Task4 uploadAvatar)·활동집계 합성(Task3·Task4 병렬로드)·부분실패 내성(Task4 `_safe`)·설정 진입(Task5)·진입 썸네일(Task6). completedContentCount(Task1). 커버 완료. **구독 섹션=비범위(spec)**.

**2. Placeholder scan:** Task5 page는 UI라 dashboard_page+dp_design 확인 후 작성으로 위임(정확 위젯은 실측 필요 — 추측 금지 원칙). avatar 바이트 획득(file picker)은 명시적으로 범위 최소화(배선만). 나머지 태스크는 완전 코드.

**3. Type consistency:** `ProfileView`(nullable 필드)·`MyActivity`·`DashboardSummary.completedContentCount`·`postMultipart`/`put` 시그니처가 source→controller→test에서 일관. fake override 시그니처가 `api_client.dart` 정의와 일치.

**리스크:** Task5(UI)·Task6(좁은 화면 진입)은 실측 후 확정. avatar 파일 선택 UI는 이번 범위에서 배선까지(파일 바이트 획득은 후속). melos 전체 test에서 기존 fake 파급(postMultipart/put) 누락 시 컴파일 실패 → Task2/3의 fake override 필수.
