# P7 — landing (Jaspr, SEO 정적 랜딩) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `landing/`에 **Jaspr(Dart)** 기반 SEO 정적 랜딩을 TDD로 구현한다 — `lang="ko"` + SEO/OG 메타, Hero(헤드라인 + **CTA→web 앱**), Features, Footer. **SSG(정적 생성)** 로 빌드해 검색엔진 색인·초기 로딩을 최적화(스펙 B′의 "랜딩만 분리").

**Architecture:** **워크스페이스 밖 독립 프로젝트**(T-LANDING-WORKSPACE 결정 = standalone). Jaspr는 Flutter와 의존성 해석 충돌 위험 + 앱과 코드/상태 무공유(스펙 §10) → melos 워크스페이스 비편입, 자체 `pubspec`·`dart pub get`. 앱 연결은 **URL(CTA)** 뿐. 디자인은 MARKETING 전용(dp_design 미사용 — Jaspr는 Flutter 아님), 자체 CSS.

**Tech Stack:** **Jaspr 0.22.x**(SSG) · jaspr_builder(codegen) · jaspr_test · 자체 CSS. (Flutter/dp_* 미사용.)

---

> **선행:** 없음(독립). 단 스펙 B′(랜딩 분리)·§4(SEO 메타·OG·데모영상·CTA→web)·§10(landing=MARKETING, 앱 토큰 밖). **T-LANDING-WORKSPACE 해소**: standalone 채택(본 플랜).
> **참조:** Jaspr API는 **Context7 검증**(`StatelessComponent.build`→`div(classes:,[...])`, `Jaspr.initializeApp`+`runApp(Document(...))`, `jaspr_test` `testComponents`/`pumpComponent`/`find`). 
> **YAGNI/추측 경계:** 랜딩 카피·데모영상·브랜드 비주얼은 마케팅 후속(스펙 §10 "랜딩 디자인은 별도 세션"). 본 플랜은 **SEO 구조 + CTA 연결 + SSG 빌드** 골격. web 앱 URL은 환경값(`--define`/상수)로 주입.
> **CI 주의:** landing은 워크스페이스 밖 → `melos run test`에 안 잡힘. CI에 landing 전용 job(`cd landing && dart test` + `jaspr build`) 추가 필요(P1 ci.yml 후속 — T 후보).

---

## File Structure (P7에서 생성)

```
landing/                                  # 워크스페이스 밖 독립 Jaspr 프로젝트
├─ pubspec.yaml                           # jaspr deps + SSG 설정 — Task 1
├─ web/
│  └─ styles.css                          # 마케팅 CSS — Task 3
├─ lib/
│  ├─ main.dart                           # 서버 엔트리(Document·SEO) — Task 2
│  ├─ jaspr_options.dart                  # (생성물) codegen — Task 1
│  └─ components/
│     ├─ app.dart                         # 루트 조립 — Task 3
│     ├─ hero.dart                        # 헤드라인 + CTA→web — Task 3
│     ├─ features.dart                    # 기능 소개 — Task 3
│     └─ footer.dart                      # 푸터 — Task 3
└─ test/landing_test.dart                 # jaspr_test — Task 4
```

---

## Task 1: Jaspr 독립 프로젝트 골격 (T-LANDING-WORKSPACE = standalone)

**Files:**
- Create: `landing/pubspec.yaml`
- (생성물) `landing/lib/jaspr_options.dart`

- [ ] **Step 1: `pubspec.yaml`(SSG 모드)**

Create `landing/pubspec.yaml`:
```yaml
name: devpath_landing
description: DevPath AI 공개 랜딩(Jaspr SSG). 워크스페이스 밖 독립 프로젝트.
publish_to: none
version: 0.0.1

environment:
  sdk: ^3.12.1

# ⚠️ resolution: workspace 를 두지 않는다 — 독립 해석(T-LANDING-WORKSPACE=standalone).

dependencies:
  jaspr: ^0.22.0

dev_dependencies:
  jaspr_builder: ^0.22.0
  jaspr_test: ^0.22.0
  build_runner: ^2.4.13
  lints: ^5.0.0

jaspr:
  mode: static        # SSG — SEO·정적 HTML 생성
```
> 루트 `pubspec.yaml`의 workspace `members`에 **landing을 추가하지 않는다**(Flutter↔Jaspr 해석 충돌 회피). melos도 무관.

- [ ] **Step 2: 의존성 + codegen 골격**

Run (landing에서):
```bash
cd landing && dart pub get && dart run build_runner build --delete-conflicting-outputs ; cd ..
```
Expected: `lib/jaspr_options.dart` 생성(서버 옵션). (컴포넌트가 아직 없으면 빈 옵션 — Task 3 후 재생성.)

- [ ] **Step 3: 커밋**
```bash
git add landing/pubspec.yaml landing/lib/jaspr_options.dart
git commit -m "build(landing): Jaspr SSG 독립 프로젝트 골격(T-LANDING-WORKSPACE=standalone)"
```

---

## Task 2: 서버 엔트리 + SEO Document

**Files:**
- Create: `landing/lib/main.dart`

- [ ] **Step 1: 엔트리포인트(SEO·OG·lang=ko)**

Create `landing/lib/main.dart`:
```dart
import 'package:jaspr/server.dart';

import 'components/app.dart';
import 'jaspr_options.dart';

/// web 앱 진입 URL(CTA 대상). 배포 시 실제 도메인으로 주입.
const String kWebAppUrl =
    String.fromEnvironment('WEB_APP_URL', defaultValue: 'https://app.devpath.ai');

void main() {
  Jaspr.initializeApp(options: defaultJasprOptions);

  runApp(Document(
    title: 'DevPath AI — 개발자를 위한 AI 학습 플랫폼',
    lang: 'ko',
    charset: 'utf-8',
    viewport: 'width=device-width, initial-scale=1.0',
    meta: {
      'description': '한국 개발자를 위한 AI 학습 경로·코드 샌드박스·AI 멘토. GitHub 분석으로 12주 맞춤 경로를 만드세요.',
      'og:title': 'DevPath AI',
      'og:description': 'AI가 만드는 맞춤 학습 경로 — 진단부터 멘토까지.',
      'og:type': 'website',
    },
    head: [
      link(rel: 'stylesheet', href: 'styles.css'),
    ],
    body: const App(),
  ));
}
```
> `defaultJasprOptions`는 Task 1 codegen 산출(`jaspr_options.dart`). `Document`의 `title`/`lang`/`meta`가 SEO·OG를 박는다.

- [ ] **Step 2: 커밋(컴포넌트 Task 3 후 함께 green)**
```bash
git add landing/lib/main.dart
git commit -m "feat(landing): 서버 엔트리 + SEO/OG Document(lang=ko)"
```

---

## Task 3: 컴포넌트 (Hero·Features·Footer) + CSS

**Files:**
- Create: `landing/lib/components/app.dart`, `hero.dart`, `features.dart`, `footer.dart`, `landing/web/styles.css`

- [ ] **Step 1: `hero.dart`(헤드라인 + CTA→web)**

Create `landing/lib/components/hero.dart`:
```dart
import 'package:jaspr/jaspr.dart';

import '../main.dart' show kWebAppUrl;

class Hero extends StatelessComponent {
  const Hero({super.key});

  @override
  Component build(BuildContext context) {
    return section(classes: 'hero', [
      h1([text('GitHub를 분석해 12주 학습 경로를 만들어요')]),
      p(classes: 'sub', [
        text('진단 → AI 경로 생성 → 코드 샌드박스 → AI 멘토까지, 한 곳에서.'),
      ]),
      a(href: kWebAppUrl, classes: 'cta', [text('무료로 시작하기')]),
    ]);
  }
}
```

- [ ] **Step 2: `features.dart`**

Create `landing/lib/components/features.dart`:
```dart
import 'package:jaspr/jaspr.dart';

class Features extends StatelessComponent {
  const Features({super.key});

  static const _items = [
    ('맞춤 경로', 'GitHub 분석으로 약점을 매핑해 12주 경로를 생성합니다.'),
    ('코드 샌드박스', '브라우저에서 바로 작성·실행하고 AI 리뷰를 받습니다.'),
    ('AI 멘토', '막힌 부분을 실시간 스트리밍으로 질문하세요.'),
  ];

  @override
  Component build(BuildContext context) {
    return section(classes: 'features', [
      for (final (title, desc) in _items)
        div(classes: 'feature', [
          h3([text(title)]),
          p([text(desc)]),
        ]),
    ]);
  }
}
```

- [ ] **Step 3: `footer.dart`**

Create `landing/lib/components/footer.dart`:
```dart
import 'package:jaspr/jaspr.dart';

class SiteFooter extends StatelessComponent {
  const SiteFooter({super.key});

  @override
  Component build(BuildContext context) {
    return footer(classes: 'footer', [
      p([text('© 2026 DevPath AI')]),
    ]);
  }
}
```

- [ ] **Step 4: `app.dart`(조립)**

Create `landing/lib/components/app.dart`:
```dart
import 'package:jaspr/jaspr.dart';

import 'features.dart';
import 'footer.dart';
import 'hero.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return main_(classes: 'landing', [
      const Hero(),
      const Features(),
      const SiteFooter(),
    ]);
  }
}
```
> `main_`은 jaspr의 `<main>` 헬퍼(`main`은 Dart 예약어 회피 명명). 미존재 시 `DomComponent(tag: 'main', ...)` 또는 `section`으로 대체(설치 버전 dom API 확인).

- [ ] **Step 5: `styles.css`(마케팅)**

Create `landing/web/styles.css`:
```css
:root { --indigo: #4f46e5; --ink: #0f172a; --muted: #64748b; --bg: #f8fafc; }
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, 'Pretendard', sans-serif; color: var(--ink); background: var(--bg); }
.hero { text-align: center; padding: 96px 24px 48px; }
.hero h1 { font-size: 40px; line-height: 1.3; margin: 0 0 16px; }
.hero .sub { color: var(--muted); font-size: 18px; }
.cta { display: inline-block; margin-top: 24px; padding: 14px 28px; background: var(--indigo); color: #fff; border-radius: 8px; text-decoration: none; font-weight: 600; }
.features { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; max-width: 960px; margin: 48px auto; padding: 0 24px; }
.feature { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 24px; }
.footer { text-align: center; color: var(--muted); padding: 48px 24px; }
@media (max-width: 720px) { .features { grid-template-columns: 1fr; } .hero h1 { font-size: 30px; } }
```
> 마케팅 색은 앱 토큰과 별개(스펙 §10). 인디고 시드만 공유(브랜드 일관).

- [ ] **Step 6: codegen 재실행(컴포넌트 반영)** — Run: `cd landing && dart run build_runner build --delete-conflicting-outputs ; cd ..`

- [ ] **Step 7: 커밋**
```bash
git add landing/lib/components landing/web/styles.css landing/lib/jaspr_options.dart
git commit -m "feat(landing): Hero(CTA→web)·Features·Footer + 마케팅 CSS"
```

---

## Task 4: 컴포넌트 테스트 (jaspr_test)

**Files:**
- Create: `landing/test/landing_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `landing/test/landing_test.dart`:
```dart
import 'package:jaspr_test/jaspr_test.dart';

import 'package:devpath_landing/components/app.dart';
import 'package:devpath_landing/components/hero.dart';

void main() {
  group('landing', () {
    testComponents('Hero는 헤드라인과 CTA 링크를 렌더한다', (tester) async {
      await tester.pumpComponent(const Hero());
      expect(find.text('무료로 시작하기'), findsOneComponent);
      expect(find.tag('a'), findsOneComponent); // CTA <a>
    });

    testComponents('App은 Hero·Features·Footer를 포함한다', (tester) async {
      await tester.pumpComponent(const App());
      expect(find.text('GitHub를 분석해 12주 학습 경로를 만들어요'), findsOneComponent);
      expect(find.text('AI 멘토'), findsOneComponent);
      expect(find.textContaining('DevPath AI'), findsOneComponent); // footer
    });
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd landing && dart test test/landing_test.dart ; cd ..` → FAIL(컴포넌트 미구현 시) 또는 PASS(Task 3 완료 시). Task 3 후이므로 green 목표.

- [ ] **Step 3: 통과 확인** — Run: `cd landing && dart test ; cd ..` → PASS
> `jaspr_test`의 `find.text`/`find.tag`/`findsOneComponent`는 Context7 확인 API. `Hero`가 `main.dart`의 `kWebAppUrl`을 import하므로 테스트도 해당 심볼 해석 필요(같은 패키지라 OK).

- [ ] **Step 4: 커밋**
```bash
git add landing/test/landing_test.dart
git commit -m "test(landing): Hero·App 컴포넌트 렌더 테스트(jaspr_test)"
```

---

## Task 5: SSG 빌드 + 검증

**Files:** (산출물만)

- [ ] **Step 1: 정적 빌드**

Run:
```bash
cd landing && dart pub global activate jaspr_cli && jaspr build ; cd ..
```
(또는 전역설치 없이: `cd landing && dart run jaspr_cli:jaspr build ; cd ..`)
Expected: `landing/build/jaspr/`에 정적 HTML(`index.html`) + `styles.css` 생성. `index.html`에 `<html lang="ko">`·`<meta name="description">`·`<meta property="og:title">`·CTA `<a href=".../app...">` 포함.

- [ ] **Step 2: 산출물 점검(SEO 핵심)**

Run:
```bash
grep -o 'lang="ko"' landing/build/jaspr/index.html && \
grep -o 'og:title' landing/build/jaspr/index.html && \
grep -o '무료로 시작하기' landing/build/jaspr/index.html && echo "OK: SEO/CTA 정적 렌더 확인"
```
Expected: `OK: SEO/CTA 정적 렌더 확인`

- [ ] **Step 3: 커밋(빌드 산출물은 제외 — `.gitignore`)**

`landing/.gitignore`에 `/build/`·`/.dart_tool/` 추가 후:
```bash
git add landing/.gitignore
git commit -m "chore(landing): build/.dart_tool gitignore"
```

---

## 검증 기준 (Definition of Done)

- [ ] `cd landing && dart test` — Hero·App 렌더 테스트 PASS
- [ ] `jaspr build` — `build/jaspr/index.html` 정적 생성
- [ ] 정적 HTML에 `lang="ko"` · `meta description`/`og:*` · CTA `<a href>`(web 앱) 포함(SEO·연결)
- [ ] 반응형 CSS(<720px 1열), 마케팅 디자인(앱 토큰과 분리, 스펙 §10)
- [ ] **워크스페이스 비편입** 확인(루트 `pubspec.yaml` members에 landing 없음) — T-LANDING-WORKSPACE=standalone

## 리스크 / 후속 (명시)

- **CI 분리**: landing은 melos 밖 → `melos run test`에 미포함. **CI에 landing 전용 job 추가 필요**(`cd landing && dart test` + `jaspr build`) — P1 ci.yml 후속(T 후보).
- **마케팅 디자인 골격만**: 카피·데모영상·OG 이미지·브랜드 비주얼은 마케팅 세션(스펙 §10). 본 플랜은 SEO 구조 + CTA + SSG.
- **Jaspr API 드리프트**: `main_`/`dom` 헬퍼·`Document` 파라미터·`jaspr_test` finder는 0.22.x 기준 — 설치 버전 문서(Context7)로 정렬. `jaspr_cli` 빌드 명령(`jaspr build`)도 버전별 상이 가능.
- **web 앱 URL 주입**: `kWebAppUrl`은 `--define=WEB_APP_URL=...`로 배포 환경 주입. 미주입 시 기본 도메인.
- **배포**: SSG 산출물(`build/jaspr/`)을 정적 호스팅(Netlify/CF Pages 등). 배포 파이프라인은 운영화 단계(T-DEPLOY-REINTRO와 별개 — landing은 정적).
- **딥링크/공유 상태 없음**: 스펙대로 앱과 무상태 — CTA URL 연결만.
