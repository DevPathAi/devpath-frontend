# 서식 텍스트 에디터(WYSIWYG) — 설계 (Design)

> 날짜: 2026-07-31 · 범위: 커뮤니티 작성(질문/일반글) 본문 입력을 WYSIWYG 에디터로 전환(저장은 마크다운 유지) · 성격: 신규 패키지 도입(로드맵 §1.3 재검토) · 파급 레포: `devpath-frontend` 단일(백엔드·dp_core·shared 불변)

## 1. 배경 / 목표

커뮤니티 작성 화면은 본문을 `TextField`로 **마크다운 원문** 입력한다. 사용자는 **서식이 입력 중 즉시 보이는 WYSIWYG** 에디터를 원한다. UI/UX 로드맵 §1.3은 과거 "마크다운 방향, flutter_quill 미도입"을 확정했으나, 이번 요구로 그 방향을 **재검토**해 WYSIWYG를 도입한다.

- **완료 정의**: 커뮤니티 질문/일반글 작성 시 툴바로 굵게·제목·목록 등을 적용하면 에디터에 서식이 즉시 렌더된다. 게시하면 **기존과 동일한 마크다운(`bodyMd`)** 으로 저장되고, 상세 렌더는 기존 `DpMarkdown`이 그대로 표시한다.

## 2. 현재 상태 (검증된 사실, 2026-07-31 코드 실측)

- 작성 화면 2개(모두 `apps/web/.../community/presentation/`): `post_create_page.dart`(FREE/FEEDBACK), `question_create_page.dart`(QNA). 둘 다 본문은 `_bodyCtrl`(`TextEditingController`) + `TextField`(minLines 5·maxLines 12·라벨 "본문 (Markdown)"). `_submit()`가 `_bodyCtrl.text.trim()` → `bodyMd`로 create provider 호출.
- `question_create_page`는 추가로 유사질문 디바운스·`LcsContextCard` 보유(본문 외 로직).
- 렌더: `DpMarkdown`(`dp_design/lib/src/content/dp_markdown.dart`, `markdown_widget ^2.3.2` 기반 `MarkdownBlock`). 상세 화면이 소비.
- 백엔드 create 계약: `POST /community/posts`·`POST /community/questions` 모두 `bodyMd`(마크다운 문자열). **어느 접근이든 유지**.
- `flutter_quill`/`markdown_quill` 미도입. dp_design content 레이어에 `dp_markdown.dart`만.
- 편집(기존 글 수정) 화면 없음 → **작성만** 대상(마크다운→Delta 로드는 범위 외).

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
- `flutter_quill`(WYSIWYG 에디터), `markdown_quill`(Delta↔md), `markdown`(파서 `md.Document`). 전부 MIT/BSD.
- **⚠️ Fork 1 — 버전 호환**: `markdown_quill`이 최신 `flutter_quill`을 못 따라갈 수 있음. `flutter pub add flutter_quill markdown_quill markdown` 시 pub 해석에 맡기고, 충돌 시 **`flutter_quill`을 `markdown_quill` 지원 버전으로 핀**. 도입 결과를 리포트에 기록.

### 5.2 `DpRichEditor` (apps/web widget)
- 위치: `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart` (**⚠️ Fork 2**: dp_design Layer2 아님 — flutter_quill 무게 + 웹 작성 전용이라 apps/web 격리. dp_design의 `DpMarkdown` 렌더는 불변).
- 구성: 부모가 소유한 `QuillController`(기존 `_bodyCtrl` 자리) + `QuillSimpleToolbar` + `QuillEditor.basic`(고정 높이·스크롤). `kIsWeb` 시 web 빌더 설정.
- **툴바 제약(무손실)**: `QuillSimpleToolbarConfig`로 굵게/기울임/제목(H1~H3)/불릿·번호목록/인용/코드블록/인라인코드/링크만 노출. `showColorButton`·`showBackgroundColorButton`·`showFontFamily`·`showFontSize` 등 마크다운 비표현 버튼 **비활성**.

### 5.3 저장 변환 + 작성화면 통합
- 헬퍼 `String quillToMarkdown(QuillController c) => DeltaToMarkdown().convert(c.document.toDelta());`(순수, 단위 테스트 대상).
- `post_create_page`·`question_create_page`: `_bodyCtrl`(TextField) → `QuillController _bodyController = QuillController.basic()`(+ `dispose()`). 본문 위젯을 `DpRichEditor(controller: _bodyController)`로 교체. `_submit()`의 `final body = _bodyCtrl.text.trim()` → `final body = quillToMarkdown(_bodyController).trim()`. 빈 검사는 `_bodyController.document.toPlainText().trim().isEmpty`. 나머지(제목/태그/유사질문/LCS/제출/에러) 불변.

## 6. 결정 기록 (Forks)

- **Fork 1 — 버전 호환**: pub 해석 우선, 충돌 시 flutter_quill 핀. 도입 시 실측.
- **Fork 2 — 위치 = apps/web**(dp_design 아님). flutter_quill 격리(admin/mobile 무부담). DpMarkdown 렌더는 dp_design 유지.
- **Fork 3 — 웹 한글 IME(최대 리스크)**: flutter_quill CanvasKit에서 한글 IME/전각 입력을 **브라우저 스모크로 실측(필수 AC)**. **실패 시 폴백 = 마크다운 툴바+프리뷰(Approach A)** — bodyMd 계약 동일이라 저비용 회귀.
- 저장 포맷 = **마크다운 유지**(로드맵 §1.3 정합, 에디터만 WYSIWYG).

## 7. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **단위**: `quillToMarkdown` 변환(알려진 Delta/문서 → 기대 마크다운: 굵게·제목·목록·인용·코드).
- **위젯**: `DpRichEditor` 렌더(QuillEditor·QuillSimpleToolbar 존재), 작성화면 회귀(**기존 `post_create_page_test`·`question_create_page_test`가 "본문 (Markdown)" TextField 의존 → QuillEditor 기반으로 갱신**: 본문 입력은 controller에 Delta 주입 또는 텍스트 입력 후 제출 검증).
- **브라우저 스모크(필수 AC)**: `cd apps/web && flutter run -d chrome` → 한글 본문 입력·서식 적용·게시 → 저장된 `bodyMd` 마크다운 확인(가능하면 목 모드 캡처). 실패 시 Fork 3 폴백.
- **게이트**: `melos run format`→`analyze`→`test`. flutter_quill 도입으로 web 빌드가 커지므로 `flutter build web` 스모크 권장.

## 8. 작업 분해 / 레포 / 브랜치

- **레포 1곳**: `devpath-frontend`(apps/web). 백엔드·dp_core·shared 불변.
- **브랜치**: `feat/rich-text-editor` → `develop` PR.
- **순서**: 패키지 도입(버전 실측) → `quillToMarkdown` 헬퍼+테스트 → `DpRichEditor` → post/question 작성화면 통합+테스트 갱신 → 브라우저 스모크.

## 9. 참조

- 로드맵 spec(§1.3 마크다운 방향): `devpath-frontend/docs/superpowers/specs/2026-07-30-web-admin-uiux-elevation-roadmap-design.md`
- 핸드오프: `documents/docs/superpowers/handoff-2026-07-31-uiux-roadmap-complete-next-contract-expansion.md`(§D)
- 선행 A/B/C spec(계약확장 3건): `2026-07-31-dashboard-timeseries-design.md`·`2026-07-31-community-excerpt-preview-design.md`·`2026-07-31-admin-bulk-actions-design.md`
- 패키지: flutter_quill(`/singerdmx/flutter-quill`)·markdown_quill(`/tarekkma/markdown_quill`) — Context7 API 확인 완료.
- 관련 코드: `apps/web/lib/src/features/community/presentation/{post_create_page,question_create_page}.dart` · `packages/dp_design/lib/src/content/dp_markdown.dart`
