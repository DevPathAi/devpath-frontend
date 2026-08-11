# 앱 진입 HTML 위생 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `app.leva.ai.kr`이 내보내는 Flutter 기본 템플릿 메타(`devpath_web` / `A new Flutter project.`)를 브랜드에 맞게 고치고, 본문이 빈 페이지가 검색에 색인되지 않도록 `noindex`를 넣는다.

**Architecture:** `apps/web/web/index.html`과 `apps/admin/web/index.html`의 `<head>`만 수정한다. 정적 파일이므로 테스트는 파일을 읽어 문자열을 단언한다. 애드센스 스크립트·Monaco 로더·`flutter_bootstrap.js`는 건드리지 않는다.

**Tech Stack:** Flutter Web · flutter_test · melos 7

**Spec:** `docs/superpowers/specs/2026-08-11-app-index-html-hygiene-design.md`

## Global Constraints

- 대상 레포는 `devpath-frontend` 하나다.
- 작업 브랜치는 `develop`에서 분기한다. `develop`·`main`에 직접 커밋하지 않는다.
- **테스트를 먼저 쓰고 실패를 눈으로 확인한 뒤** 구현한다(CLAUDE.md 절대 조건 2).
- **추측하지 않는다.** 모르면 파일을 읽고 명령을 실행해 확인한다(절대 조건 1).
- 애드센스 스크립트와 퍼블리셔 ID `ca-pub-2785578834914321`을 **삭제하거나 변형하지 않는다.**
- `$FLUTTER_BASE_HREF` 자리표시자를 그대로 둔다. 빌드가 치환한다.
- 확인 명령: `melos run format` · `melos run analyze` · `melos run test`
- 브랜드는 `Leva`다.

## 확정 문구

| 파일 | title | description |
|---|---|---|
| `apps/web/web/index.html` | `Leva — 학습 로드맵` | `적응형 진단 결과에서 시작하는 맞춤 학습 로드맵과, 학습 맥락을 아는 AI 멘토를 제공하는 Leva 앱입니다.` |
| `apps/admin/web/index.html` | `Leva 관리자` | `Leva 서비스 운영을 위한 관리자 도구입니다.` |

## File Structure

| 파일 | 책임 |
|---|---|
| `apps/web/web/index.html` (수정) | 사용자 앱 진입 HTML의 `<head>` 메타 |
| `apps/web/test/web_index_meta_test.dart` (신규) | 위 파일의 메타·회귀·보호 가드 |
| `apps/admin/web/index.html` (수정) | 관리자 앱 진입 HTML의 `<head>` 메타 |
| `apps/admin/test/admin_index_meta_test.dart` (신규) | 위 파일의 메타·회귀 가드 |

---

### Task 1: `apps/web` 진입 HTML

**Files:**
- Create: `apps/web/test/web_index_meta_test.dart`
- Modify: `apps/web/web/index.html`

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (정적 파일 변경)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/web/test/web_index_meta_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// web/index.html은 정적 파일이라 위젯 트리로 검증할 수 없다.
/// 크롤러와 링크 미리보기가 보는 것은 이 파일의 <head>이므로 직접 읽어 단언한다.
void main() {
  final html = File('web/index.html').readAsStringSync();

  group('앱 진입 HTML 메타', () {
    test('문서 언어를 한국어로 선언한다', () {
      expect(html, contains('<html lang="ko">'));
    });

    test('브랜드 제목을 쓴다', () {
      expect(html, contains('<title>Leva — 학습 로드맵</title>'));
    });

    test('앱이 무엇인지 설명한다', () {
      expect(
        html,
        contains('적응형 진단 결과에서 시작하는 맞춤 학습 로드맵'),
      );
    });

    // 본문이 캔버스에 그려져 HTML에는 텍스트가 없다. 빈 페이지가 색인되면
    // 사이트 품질 신호에 불리하다. 검색 유입은 홈페이지가 전담한다.
    test('검색 색인을 막는다', () {
      expect(html, contains('<meta name="robots" content="noindex"'));
    });

    test('링크 미리보기용 OG 태그를 갖춘다', () {
      for (final property in [
        'og:type',
        'og:site_name',
        'og:title',
        'og:description',
        'og:url',
        'og:image',
        'og:locale',
      ]) {
        expect(html, contains('property="$property"'), reason: '$property 누락');
      }
    });
  });

  group('회귀 가드', () {
    test('Flutter 기본 템플릿 문자열이 되돌아오지 않는다', () {
      expect(html, isNot(contains('A new Flutter project.')));
      expect(html, isNot(contains('<title>devpath_web</title>')));
    });

    // 메타를 정리하다 광고 배선을 지우는 사고를 막는다.
    test('애드센스 스크립트와 퍼블리셔 ID가 그대로 있다', () {
      expect(html, contains('adsbygoogle.js'));
      expect(html, contains('ca-pub-2785578834914321'));
    });

    // 빌드가 치환하는 자리표시자다. 실수로 값을 박아 넣으면 배포 경로가 깨진다.
    test('base href 자리표시자를 유지한다', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd apps/web && flutter test test/web_index_meta_test.dart
```

Expected: FAIL. `<html lang="ko">`·브랜드 title·`noindex`·OG가 없고, 기본 템플릿 문자열이 남아 있어 회귀 가드도 실패한다. 애드센스와 base href 단언 2건만 통과해야 한다.

**통과하는 단언이 2건인지 확인한다.** 전부 실패한다면 파일 경로가 틀린 것이다(테스트의 cwd는 `apps/web`이다).

- [ ] **Step 3: `<head>`를 고친다**

`apps/web/web/index.html`에서 두 곳을 바꾼다.

첫째, 2행의 `<html>`을 바꾼다:

```html
<html lang="ko">
```

둘째, 21행의 `description` 메타부터 32행의 `<title>`까지를 다음으로 바꾼다. **`<base href>`·charset·X-UA-Compatible·iOS 태그·favicon·manifest·애드센스 스크립트는 그대로 둔다.**

기존:

```html
  <meta name="description" content="A new Flutter project.">
```

변경:

```html
  <meta name="description" content="적응형 진단 결과에서 시작하는 맞춤 학습 로드맵과, 학습 맥락을 아는 AI 멘토를 제공하는 Leva 앱입니다.">

  <!-- 본문이 캔버스에 그려져 HTML에는 텍스트가 없다. 빈 페이지가 색인되지 않도록
       검색에서 제외한다. 공개 콘텐츠와 검색 유입은 leva.ai.kr이 전담한다.
       robots 메타는 검색 크롤러에만 적용되므로 광고 게재에는 영향이 없다. -->
  <meta name="robots" content="noindex" />

  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="Leva" />
  <meta property="og:title" content="Leva — 학습 로드맵" />
  <meta property="og:description" content="적응형 진단 결과에서 시작하는 맞춤 학습 로드맵과, 학습 맥락을 아는 AI 멘토." />
  <meta property="og:url" content="https://app.leva.ai.kr/" />
  <meta property="og:image" content="https://leva.ai.kr/assets/og-image.png" />
  <meta property="og:locale" content="ko_KR" />
```

그리고 기존 `<title>devpath_web</title>`을 바꾼다:

```html
  <title>Leva — 학습 로드맵</title>
```

- [ ] **Step 4: 통과를 확인한다**

```bash
cd apps/web && flutter test test/web_index_meta_test.dart
```

Expected: PASS (9건)

- [ ] **Step 5: 커밋**

```bash
git add apps/web/web/index.html apps/web/test/web_index_meta_test.dart
git commit -m "fix(web): 앱 진입 HTML의 기본 템플릿 메타를 브랜드에 맞게 고친다"
```

---

### Task 2: `apps/admin` 진입 HTML

**Files:**
- Create: `apps/admin/test/admin_index_meta_test.dart`
- Modify: `apps/admin/web/index.html`

**Interfaces:**
- Consumes: 없음
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/admin/test/admin_index_meta_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 관리자 도구는 링크 공유 대상이 아니므로 OG는 두지 않는다.
/// 검색 색인만 확실히 막고 기본 템플릿 문자열을 걷어낸다.
void main() {
  final html = File('web/index.html').readAsStringSync();

  group('관리자 진입 HTML 메타', () {
    test('문서 언어를 한국어로 선언한다', () {
      expect(html, contains('<html lang="ko">'));
    });

    test('브랜드 제목을 쓴다', () {
      expect(html, contains('<title>Leva 관리자</title>'));
    });

    test('무엇을 위한 화면인지 설명한다', () {
      expect(html, contains('Leva 서비스 운영을 위한 관리자 도구입니다.'));
    });

    test('검색 색인을 막는다', () {
      expect(html, contains('<meta name="robots" content="noindex"'));
    });
  });

  group('회귀 가드', () {
    test('Flutter 기본 템플릿 문자열이 되돌아오지 않는다', () {
      expect(html, isNot(contains('A new Flutter project.')));
      expect(html, isNot(contains('<title>devpath_admin</title>')));
    });

    test('base href 자리표시자를 유지한다', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd apps/admin && flutter test test/admin_index_meta_test.dart
```

Expected: FAIL. base href 단언 1건만 통과해야 한다.

- [ ] **Step 3: `<head>`를 고친다**

`apps/admin/web/index.html`에서 `<html>`에 `lang="ko"`를 넣고, `description`과 `<title>`을 바꾼다:

```html
  <meta name="description" content="Leva 서비스 운영을 위한 관리자 도구입니다.">

  <!-- 관리자 도구는 검색 대상이 아니다. -->
  <meta name="robots" content="noindex" />
```

```html
  <title>Leva 관리자</title>
```

- [ ] **Step 4: 통과를 확인한다**

```bash
cd apps/admin && flutter test test/admin_index_meta_test.dart
```

Expected: PASS (6건)

- [ ] **Step 5: 커밋**

```bash
git add apps/admin/web/index.html apps/admin/test/admin_index_meta_test.dart
git commit -m "fix(admin): 관리자 진입 HTML의 기본 템플릿 메타를 고치고 색인을 막는다"
```

---

### Task 3: 전체 검증 · PR · 라이브 확인

**Files:** 없음 (릴리스 작업)

- [ ] **Step 1: 모노레포 전체 검증**

```bash
melos run format
melos run analyze
melos run test
```

Expected: 전부 통과. `format`은 `--set-exit-if-changed`라 **0 changed를 눈으로 확인**한다. `(N changed)`가 나오면 고쳐야 한다는 뜻이지 고쳤다는 뜻이 아니다.

- [ ] **Step 2: 빌드 산출물에 변경이 살아 있는지 확인한다**

`flutter build web`이 `index.html`을 어떻게 다루는지 추측하지 않고 확인한다.

```bash
cd apps/web && flutter build web --release
```

빌드 후 `apps/web/build/web/index.html`을 열어 확인할 것:

- `<html lang="ko">`가 남아 있는가
- `<title>Leva — 학습 로드맵</title>`이 남아 있는가
- `noindex`와 OG 태그가 남아 있는가
- `$FLUTTER_BASE_HREF`가 실제 경로(`/` 등)로 **치환됐는가**

치환 대상이 아닌 것이 사라졌다면 빌드가 `index.html`을 재생성하는 것이므로, 그 경우 **멈추고 보고한다.** 다른 방법(빌드 후 후처리)이 필요하다는 뜻이다.

- [ ] **Step 3: PR을 만든다**

```bash
git push -u origin <브랜치명>
gh pr create --base develop --title "fix(app): 진입 HTML의 기본 템플릿 메타를 고치고 색인을 막는다" --body "<스펙 링크와 변경 요약>"
```

- [ ] **Step 4: CI 확인 후 머지**

```bash
gh pr checks <번호>
gh pr merge <번호> --merge --delete-branch
```

red면 머지하지 않는다.

- [ ] **Step 5: 라이브 확인**

★홈페이지와 배포 경로가 다르다.★ 이 레포는 CI가 GHCR 이미지를 빌드하고 k3s가 그것을 서비스한다. **머지만으로 반영됐다고 보지 않는다.**

```bash
curl -sS -4 https://app.leva.ai.kr/ | grep -E "<title>|name=\"description\"|name=\"robots\""
```

Expected: 새 title·description·`noindex`.

`curl.exe -4`를 쓴다(이 환경의 `Invoke-WebRequest`는 DNS 오류를 낸다).

- 옛 값이 나오면 → 이미지가 아직 배포되지 않은 것이다. 배포 파이프라인(GHCR 태그·ArgoCD sync) 상태를 확인한다
- 반영됐으면 → **연속 두 라운드가 같은 값을 낼 때까지** 반복 측정한다

- [ ] **Step 6: 광고가 여전히 나오는지 확인한다**

`noindex`가 광고를 막지 않는다는 것은 문서로 확인했지만, 실제 화면에서도 확인한다. 로그인해 광고 슬롯이 있는 화면을 열고 광고가 그대로 노출되는지 본다.

노출되지 않으면 `noindex` 때문인지 다른 원인(재고 없음·심사 미승인)인지 가려야 한다. 심사가 아직 「준비 중」이라 광고가 안 나오는 것이 정상일 수 있으므로, **변경 전후를 비교**해 판단한다.

---

## Self-Review

**스펙 커버리지**

| 스펙 항목 | 태스크 |
|---|---|
| §4.1 `apps/web` 메타 7항목 | Task 1 |
| §4.2 `apps/admin` 메타 | Task 2 |
| §4.3 noindex와 광고의 관계 | Task 1 Step 3 주석, Task 3 Step 6 실측 |
| §5 테스트 (회귀·보호 가드 포함) | Task 1 Step 1, Task 2 Step 1 |
| §6 검증 | Task 3 |
| §7 위험: 애드센스 훼손 | Task 1의 보호 가드 |
| §7 위험: 빌드가 index.html 변형 | Task 3 Step 2 |
| §7 위험: 이미지 미재빌드 | Task 3 Step 5 |

**빠진 것을 하나 찾아 고쳤다.** 스펙 §7은 "빌드가 `index.html`을 변형"할 위험을 적었지만 확인 방법을 정하지 않았다. Task 3 Step 2에서 실제로 빌드해 산출물을 열어보고, 치환 대상이 아닌 것이 사라졌으면 **멈추고 보고**하도록 했다. 추측으로 넘어가면 배포하고 나서야 알게 된다.

**`base href` 가드를 추가했다.** 스펙에는 "자리표시자를 그대로 둔다"만 있었는데, 실수로 값을 박아 넣으면 배포 경로가 깨진다. 두 테스트 모두 `$FLUTTER_BASE_HREF` 존재를 단언한다. 이 단언은 구현 전에도 통과하므로, Step 2에서 **통과하는 단언의 개수**를 명시해 테스트가 제대로 실행되고 있는지 확인하게 했다.

**타입·이름 일관성** — 이 계획은 정적 HTML만 다루므로 코드 인터페이스가 없다. 파일 경로(`web/index.html`)는 테스트의 cwd가 패키지 루트라는 사실에 의존하며, Step 2에서 그것을 확인한다.

**Task 3 Step 6은 판단이 필요한 검증이다.** 광고가 안 나올 때 원인이 여럿일 수 있어(심사 미승인·재고 없음·`noindex`) 변경 전후 비교로 가리도록 했다. 단정할 수 없는 검증은 단정하지 않는다고 적어 두는 편이 낫다.
