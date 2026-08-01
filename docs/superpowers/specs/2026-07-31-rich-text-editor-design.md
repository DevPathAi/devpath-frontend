# 서식 텍스트 에디터(WYSIWYG) — 설계 (Design)

> 날짜: 2026-07-31 (**개정 2026-08-01 — spec 검토 반영**) · 범위: 커뮤니티 작성(질문/일반글) 본문 입력을 WYSIWYG 에디터로 전환(저장은 마크다운 유지) · 성격: 신규 패키지 도입(로드맵 §1.3 재검토) · 파급 레포: `devpath-frontend` 단일(백엔드·dp_core·shared 불변)
>
> **개정 이력 (2026-08-01, 코드·pub.dev 실측 검토)**: ①§7 기존 테스트 영향 **정정** — 라벨이 아니라 `TextField` 인덱스 의존(갱신 범위 확대) ②**§5.4 localizations 배선 신설**(flutter_quill 11 필수, 앱 루트에 미존재 — 누락 시 실패) ③§5.2 툴바 플래그 **전체 열거**(기본 true 다수) ④§5.1 Fork 1 버전 호환 **실측 해소** + 유지보수 리스크 기록 ⑤§5.1 `markdown` 직접 의존 **제외**(전이 의존으로 충분)

## 1. 배경 / 목표

커뮤니티 작성 화면은 본문을 `TextField`로 **마크다운 원문** 입력한다. 사용자는 **서식이 입력 중 즉시 보이는 WYSIWYG** 에디터를 원한다. UI/UX 로드맵 §1.3은 과거 "마크다운 방향, flutter_quill 미도입"을 확정했으나, 이번 요구로 그 방향을 **재검토**해 WYSIWYG를 도입한다.

- **완료 정의**: 커뮤니티 질문/일반글 작성 시 툴바로 굵게·제목·목록 등을 적용하면 에디터에 서식이 즉시 렌더된다. 게시하면 **기존과 동일한 마크다운(`bodyMd`)** 으로 저장되고, 상세 렌더는 기존 `DpMarkdown`이 그대로 표시한다.

## 2. 현재 상태 (검증된 사실 — 2026-07-31 최초 실측 + 2026-08-01 재검증)

- 작성 화면 2개(모두 `apps/web/.../community/presentation/`): `post_create_page.dart`(FREE/FEEDBACK), `question_create_page.dart`(QNA). 둘 다 본문은 `_bodyCtrl`(`TextEditingController`) + `TextField`(minLines 5·maxLines 12·라벨 "본문 (Markdown)"). `_submit()`가 `_bodyCtrl.text.trim()` → `bodyMd`로 create provider 호출.
- `question_create_page`는 추가로 유사질문 디바운스·`LcsContextCard` 보유(본문 외 로직).
- 렌더: `DpMarkdown`(`dp_design/lib/src/content/dp_markdown.dart`, `markdown_widget ^2.3.2` 기반 `MarkdownBlock`). 상세 화면이 소비.
- 백엔드 create 계약: `POST /community/posts`·`POST /community/questions` 모두 `bodyMd`(마크다운 문자열). **어느 접근이든 유지**.
- `flutter_quill`/`markdown_quill` 미도입. dp_design content 레이어에 `dp_markdown.dart`만.
- 편집(기존 글 수정) 화면 없음 → **작성만** 대상(마크다운→Delta 로드는 범위 외).
- **기존 위젯 테스트는 라벨이 아니라 `find.byType(TextField)` 인덱스에 의존**(2026-08-01 실측 정정 — §7 참조): `post_create_page_test.dart:52` `findsNWidgets(3)`·`:101~103` `.at(0)/.at(1)/.at(2)`, `question_create_page_test.dart:62` `.first`·`:92~94`·`:198~199` `.at(0)/.at(1)`.
- **`apps/web/lib/src/app/app.dart:16`의 `MaterialApp.router`에 `localizationsDelegates`가 없다**(§5.4 필수 작업의 근거). 앱 pubspec에 `flutter_localizations`도 없음.

## 3. 범위 / 비범위

**범위**: `flutter_quill`+`markdown_quill` 도입, `DpRichEditor` 신설(apps/web), 두 작성 화면의 본문 입력 전환, 저장 시 Delta→마크다운 변환.

**비범위**:
- 기존 글 **편집** 화면(현재 없음) → 마크다운→Delta 로드 미구현.
- 색상·폰트·이미지 임베드 등 **마크다운 비표현 서식**(툴바에서 비활성 — 무손실 변환 보장).
- 상세 렌더 변경(기존 `DpMarkdown` 유지).
- mobile/admin 에디터(웹 커뮤니티 작성 전용).

## 4. 데이터/계약

- **계약 불변**: create provider의 `bodyMd`(마크다운 문자열)은 그대로. 백엔드·dp_core·shared **무변경**.
- **에디터 내부 표현**: flutter_quill `Document`/`Delta`(메모리 전용, 저장 안 함). 저장 직전 `DeltaToMarkdown().convert(controller.document.toDelta())`로 마크다운 산출.

## 5. 설계 (devpath-frontend, apps/web)

### 5.1 패키지 (apps/web pubspec)
- `flutter_quill`(WYSIWYG 에디터), `markdown_quill`(Delta→md). 전부 MIT/BSD.
- **`markdown` 직접 의존은 넣지 않는다**(2026-08-01 정정): `md.Document`는 `MarkdownToDelta`(마크다운→Delta 로드 = **범위 외**)에만 필요하다. 저장 경로(`DeltaToMarkdown`)는 `markdown`을 직접 import하지 않으며, markdown_quill이 전이 의존(`markdown: ^7.2.1`)으로 이미 가진다. 구현 중 실제 import가 필요해지면 그때 추가.
- **✅ Fork 1(버전 호환) — 2026-08-01 pub.dev 실측으로 리스크 해소**:
  - `markdown_quill` 최신 **4.3.0**(2025-03-08) → `flutter_quill: ^11.0.0`
  - `flutter_quill` 최신 **11.5.1**(2026-05-20) → `^11.0.0` 범위 안 ⇒ **핀 불필요 전망**
  - 로컬 툴체인 **Flutter 3.44.1 / Dart 3.12.1**, flutter_quill 11.5.1 요구 = `flutter >=3.44.0`·`sdk ^3.12.0` ⇒ **충족(여유 없음 — Flutter 다운그레이드 금지)**
  - 그래도 `flutter pub add` 실제 해석 결과를 리포트에 기록하고, 어긋나면 flutter_quill 핀으로 폴백.
- **⚠️ 유지보수 리스크(기록)**: markdown_quill은 4.3.0 이후 **1년 5개월 무갱신**. flutter_quill 12가 나오면 정체될 수 있다. 현 시점 도입은 문제없으나 장기 업그레이드 시 재평가 대상.

### 5.2 `DpRichEditor` (apps/web widget)
- 위치: `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart` (**⚠️ Fork 2**: dp_design Layer2 아님 — flutter_quill 무게 + 웹 작성 전용이라 apps/web 격리. dp_design의 `DpMarkdown` 렌더는 불변).
- 구성: 부모가 소유한 `QuillController`(기존 `_bodyCtrl` 자리) + `QuillSimpleToolbar` + `QuillEditor.basic`(고정 높이·스크롤). `kIsWeb` 시 web 빌더 설정.
- **툴바 제약(무손실)** — `QuillSimpleToolbarConfig`는 **기본값이 `true`인 플래그가 많으므로**(Context7 확인: `showFontFamily`·`showFontSize`·`showColorButton`·`showBackgroundColorButton`·`showUnderLineButton`·`showStrikeThrough`·`showListCheck`·`showSearchButton`·`showSubscript`·`showSuperscript`·`showIndent`·`showClearFormat`·`showInlineCode`·`showLink`·`showUndo`·`showRedo` 등) **끄는 항목을 빠짐없이 명시**한다. 열거하지 않으면 마크다운 비표현 서식이 조용히 노출된다.

  **허용(ON)** — 마크다운으로 무손실 표현 가능:
  `showBoldButton`·`showItalicButton`·`showHeaderStyle`(H1~H3)·`showListBullets`·`showListNumbers`·`showQuote`·`showCodeBlock`·`showInlineCode`·`showLink`·`showUndo`·`showRedo`

  **차단(OFF=false)** — 마크다운 비표현 또는 범위 외:
  `showFontFamily`·`showFontSize`·`showColorButton`·`showBackgroundColorButton`·`showUnderLineButton`(md에 밑줄 없음)·`showListCheck`(체크리스트)·`showSubscript`·`showSuperscript`·`showSmallButton`·`showLineHeightButton`·`showAlignmentButtons`·`showDirection`·`showIndent`·`showClearFormat`·`showSearchButton`

  **미확정 1건 — `showStrikeThrough`**: `markdown_quill`이 취소선을 `~~…~~`로 변환하는지 **구현 시 `quillToMarkdown` 단위 테스트로 실측**해 결정한다(변환되면 ON, 아니면 OFF). 추측으로 켜지 않는다.

### 5.3 저장 변환 + 작성화면 통합
- 헬퍼 `String quillToMarkdown(QuillController c) => DeltaToMarkdown().convert(c.document.toDelta());`(순수, 단위 테스트 대상).
- `post_create_page`·`question_create_page`: `_bodyCtrl`(TextField) → `QuillController _bodyController = QuillController.basic()`(+ `dispose()`). 본문 위젯을 `DpRichEditor(controller: _bodyController)`로 교체. `_submit()`의 `final body = _bodyCtrl.text.trim()` → `final body = quillToMarkdown(_bodyController).trim()`. 빈 검사는 `_bodyController.document.toPlainText().trim().isEmpty`. 페이지 내 나머지 로직(제목/태그/유사질문/LCS/제출/에러) 불변.
- **⚠️ 단, 앱 루트는 불변이 아니다 → §5.4**.

### 5.4 localizations 배선 (**2026-08-01 추가 — 필수, 누락 시 런타임 실패**)

flutter_quill 11.x는 `FlutterQuillLocalizations.delegate` 등록을 **요구**한다(Context7: README·`doc/migration/10_to_11.md`). 현재 `apps/web/lib/src/app/app.dart:16` `MaterialApp.router`에는 `localizationsDelegates`가 **없다**.

- **앱**: `app.dart`의 `MaterialApp.router`에 `localizationsDelegates` 추가.
- **의존**: `Global*Localizations`를 쓰려면 `flutter_localizations`(SDK) 추가가 필요하다. 이 앱은 한국어 단일 UI이고 Quill 툴바 툴팁만 대상이므로 **1순위 = SDK 의존 없이 `Default*Localizations` + `FlutterQuillLocalizations.delegate`**(문서상 지원 조합), Material 위젯 한국어화가 필요해지면 그때 `flutter_localizations`로 승격.
  ```dart
  localizationsDelegates: const [
    DefaultCupertinoLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
  ```
- **테스트**: 작성 페이지를 pump하는 `post_create_page_test`·`question_create_page_test`의 `_host()` `MaterialApp.router`에도 **동일 delegate를 추가**해야 위젯 테스트가 통과한다(다른 테스트 파일은 Quill을 렌더하지 않으므로 대상 아님).

## 6. 결정 기록 (Forks)

- **Fork 1 — 버전 호환**: ✅ **2026-08-01 pub.dev 실측으로 사실상 결론**(markdown_quill 4.3.0 ↔ flutter_quill 11.5.1 호환, 로컬 Flutter 3.44.1 충족 — §5.1). `flutter pub add` 결과로 최종 확인, 어긋나면 flutter_quill 핀.
- **Fork 2 — 위치 = apps/web**(dp_design 아님). flutter_quill 격리(admin/mobile 무부담). DpMarkdown 렌더는 dp_design 유지.
- **Fork 3 — 웹 한글 IME(최대 리스크)**: flutter_quill CanvasKit에서 한글 IME/전각 입력을 **브라우저 스모크로 실측(필수 AC)**. **실패 시 폴백 = 마크다운 툴바+프리뷰(Approach A)** — bodyMd 계약 동일이라 저비용 회귀.
- 저장 포맷 = **마크다운 유지**(로드맵 §1.3 정합, 에디터만 WYSIWYG).

## 7. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **단위**: `quillToMarkdown` 변환(알려진 Delta/문서 → 기대 마크다운: 굵게·기울임·제목·목록·인용·코드블록·인라인코드·링크 + **취소선 실측**으로 §5.2 미확정 1건 결론).
- **위젯**: `DpRichEditor` 렌더(QuillEditor·QuillSimpleToolbar 존재 + 차단 버튼 부재 검증).
- **★기존 테스트 갱신 — 2026-08-01 실측 정정(이전 서술 오류)**: 이전 spec/핸드오프는 *"기존 테스트가 '본문 (Markdown)' 라벨에 의존"* 이라 했으나 **틀렸다. 실제 의존은 `find.byType(TextField)` 인덱스**이며, 본문이 TextField가 아니게 되면 **3개→2개로 줄어 인덱스가 전부 시프트하고 `.at(2)`는 범위 밖 예외**가 된다. 따라서 갱신 범위는 서술보다 크다:
  - `post_create_page_test.dart`
    - `:52` `expect(find.byType(TextField), findsNWidgets(3))` → **`findsNWidgets(2)`** + `QuillEditor` 존재 검증 추가
    - `:101~103` `.at(0)`=제목·`.at(1)`=본문·`.at(2)`=태그 → **`.at(0)`=제목·`.at(1)`=태그**, 본문은 `QuillController`에 직접 문서 주입
  - `question_create_page_test.dart`
    - `:62` `.first`(제목) — 인덱스 0 유지라 **영향 없음**
    - `:92~94`·`:198~199` → 위와 동일 재배치(본문은 controller 주입)
  - 본문 주입 방식: 테스트에서 `QuillController`에 접근할 수 없으므로 **`DpRichEditor` 내부의 `QuillEditor`를 찾아 `tester.enterText`** 하거나, 페이지가 controller를 주입받도록 하지 않는 한 **plain text 입력 → `quillToMarkdown` 결과 검증**으로 한다. 구현 시 실제 동작하는 쪽을 실측해 채택(추측 금지).
  - **`_host()`의 `MaterialApp.router`에 `FlutterQuillLocalizations.delegate` 추가 필수**(§5.4).
- **브라우저 스모크(필수 AC)**: `cd apps/web && flutter run -d chrome` → 한글 본문 입력·서식 적용·게시 → 저장된 `bodyMd` 마크다운 확인(가능하면 목 모드 캡처). 실패 시 Fork 3 폴백.
- **게이트**: `melos run format`→`analyze`→`test`. flutter_quill 도입으로 web 빌드가 커지므로 `flutter build web` 스모크 권장.

## 8. 작업 분해 / 레포 / 브랜치

- **레포 1곳**: `devpath-frontend`(apps/web). 백엔드·dp_core·shared 불변.
- **브랜치**: `feat/rich-text-editor` → `develop` PR.
- **순서**: 패키지 도입(버전 실측) → **localizations 배선(§5.4)** → `quillToMarkdown` 헬퍼+테스트(취소선 실측 포함) → `DpRichEditor`(툴바 화이트리스트 §5.2) → post/question 작성화면 통합 + **기존 테스트 인덱스 재배치(§7)** → 브라우저 한글 IME 스모크.

## 9. 참조

- 로드맵 spec(§1.3 마크다운 방향): `devpath-frontend/docs/superpowers/specs/2026-07-30-web-admin-uiux-elevation-roadmap-design.md`
- 핸드오프: `documents/docs/superpowers/handoff-2026-07-31-uiux-roadmap-complete-next-contract-expansion.md`(§D)
- 선행 A/B/C spec(계약확장 3건): `2026-07-31-dashboard-timeseries-design.md`·`2026-07-31-community-excerpt-preview-design.md`·`2026-07-31-admin-bulk-actions-design.md`
- 패키지: flutter_quill(`/singerdmx/flutter-quill`)·markdown_quill(`/tarekkma/markdown_quill`) — Context7 API 확인 완료.
- 관련 코드: `apps/web/lib/src/features/community/presentation/{post_create_page,question_create_page}.dart` · `packages/dp_design/lib/src/content/dp_markdown.dart`
