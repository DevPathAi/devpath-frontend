# P1 — 모노레포 골격 (Monorepo Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** React(web/admin) 스캐폴드를 제거하고 melos + Dart pub workspaces 기반 Flutter 모노레포 골격(빈 `dp_core`/`dp_design` 패키지, `apps/web`·`apps/admin`·`apps/mobile`)을 세워 `melos run analyze`·`melos run test`가 통과하는 검증 가능한 토대를 만든다.

**Architecture:** 각 패키지/앱을 **먼저 standalone으로 생성·테스트**한 뒤, 마지막에 루트 `pubspec.yaml`의 `workspace:` + 각 멤버 `resolution: workspace`로 단일 Dart pub workspace에 결선하고 melos 7.x가 그 위에서 bootstrap·스크립트를 오케스트레이션한다. 모든 멤버는 Flutter 패키지로 `flutter test`/`flutter analyze`를 균일 적용한다(스펙 §5 — dp_core도 `flutter_test`). landing(Jaspr)은 의존성 해석 충돌 위험으로 P1에서 제외하고 P7에서 별도 결정한다.

**Tech Stack:** Dart 3.12.1 · Flutter(stable) · melos ^7.0.0 · Dart pub workspaces · GitHub Actions(`subosito/flutter-action@v2`).

> **참조 스펙:** `docs/superpowers/specs/2026-06-14-react-to-flutter-and-proto-ui-design.md` (§2 구조·스택, §6 구축 1단계). 디자인 SSoT: `DESIGN.md`.
> **선행 조건:** 작업 브랜치 `docs/flutter-migration-proto-ui-spec`(또는 신규 `feat/p1-monorepo-foundation`). 모든 명령은 레포 루트 `D:\workspace\dev-path-ai\devpath-frontend` 기준.
> **⚠️ 순서 규칙(pub workspaces):** 루트 `workspace:` 결선(Task 7)은 5개 멤버가 **모두 존재한 뒤**에만 수행한다. 그 전(Task 2~5)의 테스트는 각 패키지 **standalone**(아직 `resolution: workspace` 미부여)으로 실행한다. 순서를 바꾸면 누락 멤버로 `pub get`이 실패한다.

---

## File Structure (P1에서 생성/이동/삭제)

| 동작 | 경로 | 책임 |
|------|------|------|
| Create | `packages/dp_core/` | 도메인·데이터 패키지(P2에서 채움). P1은 빈 골격 + 스모크 테스트 |
| Create | `packages/dp_design/` | 디자인 시스템 패키지(P3에서 채움). P1은 빈 골격 + 스모크 위젯 테스트 |
| Create | `apps/web/` (`devpath_web`) | 사용자 Flutter Web 앱 골격 |
| Create | `apps/admin/` (`devpath_admin`) | 관리자 Flutter Web 앱 골격 |
| Move | `mobile/` → `apps/mobile/` | 기존 Flutter 앱(`devpath_mobile`) 이전 |
| Create | `pubspec.yaml` (루트) | Dart workspace 멤버 목록 + melos 7 설정(Task 7) |
| Create | `melos_README.md` | melos 사용법 메모 |
| Modify | `.github/workflows/ci.yml` | React 빌드/이미지/배포 → melos analyze/test |
| Delete | `web/`, `admin/` (구 React) | Vite 스캐폴드·Dockerfile·nginx.conf 제거 |

> **의도적 제거(플래그)**: 기존 CI의 `web-image`/`admin-image`(Docker)·`web-deploy`/`admin-deploy`(gitops)와 `web/Dockerfile`·`admin/Dockerfile`·`*/nginx.conf`는 React 전용이라 P1에서 제거된다. **이로써 자동 배포가 일시 중단된다.** Flutter Web → nginx 이미지 빌드·배포는 앱 빌드 산출물이 생기는 **P4(web)/P5(admin)에서 재도입**한다.

---

## Task 1: melos 설치

**Files:** (없음 — 도구 설치)

- [ ] **Step 1: melos 전역 설치**

Run:
```bash
dart pub global activate melos
```
Expected: `Activated melos 7.x.x.` (PATH에 `~/.pub-cache/bin` 필요 — 미설정 시 출력 안내대로 추가)

- [ ] **Step 2: melos 실행 확인**

Run:
```bash
melos --version
```
Expected: `7.x.x`. `command not found`이면 `dart pub global run melos --version`로 대체하거나 PATH 추가 후 재시도.

---

## Task 2: `packages/dp_core` 골격 + 스모크 테스트 (TDD, standalone)

**Files:**
- Create: `packages/dp_core/` (via `flutter create`)
- Modify: `packages/dp_core/pubspec.yaml`
- Create: `packages/dp_core/lib/dp_core.dart`
- Test: `packages/dp_core/test/dp_core_smoke_test.dart`

- [ ] **Step 1: 패키지 생성**

Run:
```bash
flutter create --template=package packages/dp_core
```
Expected: `packages/dp_core` 생성(`lib/dp_core.dart`, `test/`, `pubspec.yaml`).

- [ ] **Step 2: pubspec 정리 (아직 `resolution: workspace` 미부여 — Task 7에서 추가)**

Replace `packages/dp_core/pubspec.yaml`:
```yaml
name: dp_core
description: DevPath AI 도메인·데이터 계층(모델·API·SSE·Auth·Error). UI 없음.
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  # P2에서 추가: dio, freezed_annotation, json_annotation 등

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  # P2에서 추가: mocktail, build_runner, freezed, json_serializable
```

- [ ] **Step 3: 실패하는 스모크 테스트 작성**

Create `packages/dp_core/test/dp_core_smoke_test.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dp_core 패키지 버전 상수가 노출된다', () {
    expect(dpCoreVersion, '0.0.1');
  });
}
```

- [ ] **Step 4: 테스트 실패 확인 (standalone)**

Run:
```bash
cd packages/dp_core && flutter pub get && flutter test ; cd ../..
```
Expected: FAIL — `dpCoreVersion` 미정의(컴파일 에러).

- [ ] **Step 5: 최소 구현**

Replace `packages/dp_core/lib/dp_core.dart`:
```dart
/// DevPath AI 도메인·데이터 계층.
///
/// P2에서 models / api / sse / auth / error 를 채운다.
library dp_core;

/// 패키지 버전(스모크 확인용).
const String dpCoreVersion = '0.0.1';
```

- [ ] **Step 6: 테스트 통과 확인**

Run:
```bash
cd packages/dp_core && flutter test ; cd ../..
```
Expected: PASS (`All tests passed!`)

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_core
git commit -m "feat(dp_core): 패키지 골격 + 스모크 테스트"
```

---

## Task 3: `packages/dp_design` 골격 + 스모크 위젯 테스트 (TDD, standalone)

**Files:**
- Create: `packages/dp_design/` (via `flutter create`)
- Modify: `packages/dp_design/pubspec.yaml`
- Create: `packages/dp_design/lib/dp_design.dart`, `packages/dp_design/lib/src/dp_brand_mark.dart`
- Test: `packages/dp_design/test/dp_brand_mark_test.dart`

- [ ] **Step 1: 패키지 생성**

Run:
```bash
flutter create --template=package packages/dp_design
```
Expected: `packages/dp_design` 생성.

- [ ] **Step 2: pubspec 정리 (아직 `resolution: workspace` 미부여)**

Replace `packages/dp_design/pubspec.yaml`:
```yaml
name: dp_design
description: DevPath AI 디자인 시스템(Material 3). 도메인 모름. 토큰 SSoT=DESIGN.md.
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  # P3에서 추가: 폰트(Pretendard/D2Coding) 에셋, 마크다운/코드 하이라이트, 차트 래퍼

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

- [ ] **Step 3: 실패하는 위젯 테스트 작성**

Create `packages/dp_design/test/dp_brand_mark_test.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpBrandMark는 "DevPath" 텍스트를 렌더한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DpBrandMark()));
    expect(find.text('DevPath'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 테스트 실패 확인 (standalone)**

Run:
```bash
cd packages/dp_design && flutter pub get && flutter test ; cd ../..
```
Expected: FAIL — `DpBrandMark` 미정의.

- [ ] **Step 5: 최소 구현**

Create `packages/dp_design/lib/src/dp_brand_mark.dart`:
```dart
import 'package:flutter/material.dart';

/// 디자인 시스템 스모크용 최소 위젯. P3에서 실제 토큰/컴포넌트로 대체·확장.
class DpBrandMark extends StatelessWidget {
  const DpBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('DevPath');
  }
}
```

Replace `packages/dp_design/lib/dp_design.dart`:
```dart
/// DevPath AI 디자인 시스템(Material 3).
///
/// P3에서 theme(토큰) / components(상태위젯·폼·렌더러) / icons 를 채운다.
library dp_design;

export 'src/dp_brand_mark.dart';
```

- [ ] **Step 6: 테스트 통과 확인**

Run:
```bash
cd packages/dp_design && flutter test ; cd ../..
```
Expected: PASS

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_design
git commit -m "feat(dp_design): 패키지 골격 + 스모크 위젯 테스트"
```

---

## Task 4: `mobile/` → `apps/mobile/` 이전

**Files:**
- Move: `mobile/` → `apps/mobile/`
- Modify: `.gitignore` (mobile 경로 → apps/mobile)

- [ ] **Step 1: 디렉터리 이동(git 이력 보존)**

Run:
```bash
mkdir -p apps
git mv mobile apps/mobile
```
Expected: `mobile/`의 모든 파일이 `apps/mobile/`로 이동(스테이징됨).

- [ ] **Step 2: `.gitignore`의 mobile 경로 갱신**

`.gitignore`에서 `mobile/` 접두 4줄을 다음으로 변경:
```
# Flutter (mobile)
apps/mobile/.dart_tool/
apps/mobile/.flutter-plugins
apps/mobile/.flutter-plugins-dependencies
apps/mobile/build/
```

- [ ] **Step 3: 이동 후 테스트 통과 확인 (standalone)**

Run:
```bash
cd apps/mobile && flutter pub get && flutter test ; cd ../..
```
Expected: 기존 `test/widget_test.dart` PASS (카운터 데모).

- [ ] **Step 4: 커밋**

```bash
git add apps/mobile .gitignore
git commit -m "refactor(mobile): mobile/ → apps/mobile/ 이전"
```

---

## Task 5: `apps/web` · `apps/admin` Flutter 앱 골격

**Files:**
- Create: `apps/web/` (`devpath_web`), `apps/admin/` (`devpath_admin`)

- [ ] **Step 1: 두 앱 생성(web 플랫폼)**

Run:
```bash
flutter create --platforms=web --project-name devpath_web apps/web
flutter create --platforms=web --project-name devpath_admin apps/admin
```
Expected: `apps/web`, `apps/admin` 생성(웹 타깃, 기본 카운터 앱 + `test/widget_test.dart`).

- [ ] **Step 2: 두 앱 스모크 테스트 통과 확인 (standalone)**

Run:
```bash
cd apps/web && flutter test ; cd ../..
cd apps/admin && flutter test ; cd ../..
```
Expected: 각 PASS(기본 위젯 테스트). (`flutter create`가 생성 시 `pub get` 수행함)

- [ ] **Step 3: 커밋**

```bash
git add apps/web apps/admin
git commit -m "feat(apps): web/admin Flutter Web 앱 골격 생성"
```

---

## Task 6: 구 React 스캐폴드 제거

**Files:**
- Delete: `web/`, `admin/` (구 Vite/React — Dockerfile·nginx.conf·src 포함)

- [ ] **Step 1: 제거 대상 확인(안전 점검)**

Run:
```bash
ls web/package.json admin/package.json
```
Expected: 두 파일 존재(= 구 React 스캐폴드 맞음). 신규 `apps/web`·`apps/admin`(Flutter)와 경로가 다름을 확인.

- [ ] **Step 2: 디렉터리 제거**

Run:
```bash
git rm -r web admin
```
Expected: 구 `web/`·`admin/`의 모든 파일(`Dockerfile`, `nginx.conf`, `src/`, `package.json` 등) 삭제 스테이징.

- [ ] **Step 3: 커밋**

```bash
git commit -m "chore: 구 React(web/admin) 스캐폴드 제거 — Flutter로 대체"
```

---

## Task 7: Workspace 결선 (루트 pubspec + resolution + bootstrap)

> 5개 멤버가 모두 존재하므로 이제 단일 workspace로 묶는다.

**Files:**
- Create: `pubspec.yaml` (루트)
- Modify: `packages/dp_core/pubspec.yaml`, `packages/dp_design/pubspec.yaml`, `apps/web/pubspec.yaml`, `apps/admin/pubspec.yaml`, `apps/mobile/pubspec.yaml` (각 `resolution: workspace` 추가)

- [ ] **Step 1: 루트 `pubspec.yaml` 작성**

Create `pubspec.yaml`:
```yaml
name: devpath_frontend
publish_to: none
environment:
  sdk: ^3.12.0

# Dart pub workspaces — 모든 패키지/앱을 단일 해석으로 묶는다.
# landing(Jaspr)은 의존성 충돌 위험으로 P7에서 별도 결정(여기 미포함).
workspace:
  - packages/dp_core
  - packages/dp_design
  - apps/web
  - apps/admin
  - apps/mobile

dev_dependencies:
  melos: ^7.0.0

# melos 7.x: 설정이 pubspec.yaml의 melos: 키로 통합됨(과거 melos.yaml 대체)
melos:
  scripts:
    analyze:
      description: 전 패키지 정적 분석
      run: melos exec -- flutter analyze
    test:
      description: test/ 있는 패키지 테스트
      run: melos exec --dir-exists="test" -- flutter test
    format:
      description: 포맷 검사(CI용)
      run: dart format --set-exit-if-changed .
    fix:
      description: 포맷 적용
      run: dart format .
```

- [ ] **Step 2: 각 멤버 pubspec에 `resolution: workspace` 추가**

다섯 멤버 각각의 `pubspec.yaml`에서 `environment:` 블록 **바로 아래**에 추가:
```yaml
resolution: workspace
```
대상 파일: `packages/dp_core/pubspec.yaml`, `packages/dp_design/pubspec.yaml`, `apps/web/pubspec.yaml`, `apps/admin/pubspec.yaml`, `apps/mobile/pubspec.yaml`.

- [ ] **Step 3: 워크스페이스 bootstrap**

Run (레포 루트):
```bash
melos bootstrap
```
Expected: 5개 멤버 의존성 해석·설치 성공(`melos bootstrap` 완료, 루트 `pubspec.lock` 단일 생성). 실패 시 충돌 패키지 버전 정렬.

- [ ] **Step 4: 전체 analyze + test 통과 확인**

Run:
```bash
melos run analyze
melos run test
```
Expected: `analyze` 전 패키지 `No issues found!`, `test` 전 멤버 스모크 PASS.

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml packages/dp_core/pubspec.yaml packages/dp_design/pubspec.yaml apps/web/pubspec.yaml apps/admin/pubspec.yaml apps/mobile/pubspec.yaml pubspec.lock
git commit -m "build: melos 7 + Dart workspace 결선 (5개 멤버)"
```

---

## Task 8: CI를 Flutter(melos)로 교체

**Files:**
- Modify(전면 교체): `.github/workflows/ci.yml`

- [ ] **Step 1: `ci.yml` 전체 교체**

Replace `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Activate melos
        run: dart pub global activate melos
      - name: Bootstrap workspace
        run: melos bootstrap
      - name: Format check
        run: melos run format
      - name: Analyze
        run: melos run analyze
      - name: Test
        run: melos run test

# NOTE: React 전용 image/deploy(web-image·admin-image·web-deploy·admin-deploy)는
# 제거됨. Flutter Web → nginx 이미지 빌드·gitops 배포는 P4(web)/P5(admin)에서
# 앱 빌드 산출물이 생긴 뒤 재도입한다.
```

- [ ] **Step 2: React 잔존 참조 점검**

Run:
```bash
grep -rn "working-directory: web\|context: admin\|npm run build" .github/workflows/ci.yml || echo "OK: React 잔존 참조 없음"
```
Expected: `OK: React 잔존 참조 없음`

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: React 빌드/배포 → melos analyze·test로 교체 (이미지·배포는 P4/P5 재도입)"
```

---

## Task 9: 최종 검증 + melos 사용법 메모

**Files:**
- Create: `melos_README.md`

- [ ] **Step 1: 클린 재검증**

Run (레포 루트):
```bash
melos bootstrap
melos run format
melos run analyze
melos run test
```
Expected: 4개 모두 성공(format 변경 없음, analyze 이슈 없음, test 전부 PASS). format 실패 시 `melos run fix` 후 재검사.

- [ ] **Step 2: 구조 점검**

Run:
```bash
ls packages/dp_core packages/dp_design apps/web apps/admin apps/mobile pubspec.yaml ; ls web admin 2>/dev/null && echo "ERROR: 구 React 잔존" || echo "OK: 구 React 제거됨"
```
Expected: 멤버·루트 pubspec 존재, `OK: 구 React 제거됨`.

- [ ] **Step 3: melos 사용법 메모 작성**

Create `melos_README.md`:
```markdown
# Melos 사용법 (devpath-frontend 모노레포)

## 최초 1회
- `dart pub global activate melos`
- PATH에 `~/.pub-cache/bin` 추가(필요 시)

## 일상 명령
- 의존성 설치/동기화: `melos bootstrap` (별칭 `melos bs`)
- 정적 분석: `melos run analyze`
- 테스트: `melos run test`
- 포맷 검사/적용: `melos run format` / `melos run fix`

## 구조
- `packages/dp_core` — 도메인·데이터(UI 없음)
- `packages/dp_design` — 디자인 시스템(Material 3, 토큰 SSoT=DESIGN.md)
- `apps/{web,admin,mobile}` — Flutter 앱
- `landing/` — (P7) Jaspr 랜딩, workspace 편입 여부는 P7에서 결정

설정은 루트 `pubspec.yaml`의 `workspace:` + `melos:` 키(melos 7.x).
```

- [ ] **Step 4: 최종 커밋**

```bash
git add melos_README.md
git commit -m "docs: melos 사용법 메모 + P1 모노레포 골격 검증 완료"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos bootstrap` 성공(5개 멤버 단일 해석, 루트 `pubspec.lock` 1개)
- [ ] `melos run analyze` — 전 패키지 이슈 없음
- [ ] `melos run test` — 전 멤버 스모크 테스트 PASS
- [ ] `melos run format` — 변경 없음
- [ ] 구 React `web/`·`admin/` 부재, `apps/{web,admin,mobile}` 존재
- [ ] CI가 melos analyze/test만 수행(React 잔존 참조 0)
- [ ] mobile git 이력 보존된 채 `apps/mobile/`로 이전

## 리스크 / 후속(명시)

- **자동 배포 일시 중단**: P1에서 web/admin Docker 이미지·gitops 배포 제거 → **P4/P5에서 Flutter Web nginx 이미지·배포 재도입 필수**(스펙 §6). 그 전까지 web/admin 자동 배포 없음.
- **pub workspaces 해석 충돌 가능성**: Task 7 `melos bootstrap`이 멤버 간 버전 충돌로 실패할 수 있음 → 충돌 패키지 버전 정렬(P2/P3에서 실제 의존성 추가 시 재검증).
- **landing(Jaspr) 미포함**: Jaspr↔Flutter 의존성 해석 충돌 위험으로 P1 workspace 제외. P7에서 (a) 별도 resolution 또는 (b) workspace 밖 독립 프로젝트 중 결정.
- **flutter-action 버전 핀 미지정**: CI가 `channel: stable` 사용 → Dart 3.12 호환 Flutter가 stable에서 벗어나면 `flutter-version` 핀 필요. 최초 CI 실행 결과로 확정.
