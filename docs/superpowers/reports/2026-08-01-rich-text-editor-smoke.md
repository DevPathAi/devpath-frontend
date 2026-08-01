# 서식 에디터(WYSIWYG) 검증 리포트 — 2026-08-01

> 대상 브랜치 `feat/rich-text-editor` · 플랜 `docs/superpowers/plans/2026-08-01-rich-text-editor.md` · spec `docs/superpowers/specs/2026-07-31-rich-text-editor-design.md`

## 패키지 해석 결과 (Task 1 실측)

| 패키지 | 해석 버전 | 비고 |
|---|---|---|
| flutter_quill | **11.5.1** | spec §5.1 기대와 일치, 핀 불필요 |
| markdown_quill | **4.3.0** | `flutter_quill: ^11.0.0` 요구 → 충족 |
| markdown | **7.3.1** | **전이 의존**(직접 의존 추가하지 않음) |

로컬 툴체인 Flutter 3.44.1 / Dart 3.12.1 — flutter_quill 11.5.1 요구(`flutter >=3.44.0`, `sdk ^3.12.0`) 충족.

## 변환 실측 (Task 1 — PROBE로 실제 출력 관찰, 추측 없음)

| 서식 | 출력 마크다운 |
|---|---|
| 굵게 | `**굵게**` |
| 기울임 | `_기울임_` |
| **취소선** | `~~취소선~~` → **`showStrikeThrough` = ON** |
| H1 / H2 | `# 제목` / `## 제목2` |
| 불릿 / 번호 | `- 항목` / `1. 항목` |
| 인용 | `> 인용` |
| 코드블록 | 백틱 3개 펜스 |
| 인라인코드 | `` `code` `` |
| 링크 | `[DevPath](https://leva.ai.kr)` |
| 한글 평문 | `한글 본문입니다` (그대로 보존) |

**취소선이 무손실 변환됨을 실측**했으므로 플랜의 잠정값(OFF)을 뒤집어 툴바에 노출했다. 이 관찰값들은 전부 `quill_markdown_test.dart`에 고정 회귀 테스트로 박혀 있다.

## 툴바 화이트리스트 (Task 2)

- **ON(12)**: bold · italic · **strikeThrough** · header(H1~H3) · bulletList · numberList · quote · codeBlock · inlineCode · link · undo · redo
- **OFF(15)**: fontFamily · fontSize · color · backgroundColor · underline · listCheck · subscript · superscript · small · lineHeight · alignment · direction · indent · clearFormat · search

`QuillSimpleToolbarConfig`는 기본값 `true`인 플래그가 많아 **27개 전부를 명시적으로 설정**했다(리뷰어가 1:1 대조로 누락·반전 없음 확인).

## 자동 검증 (컨트롤러 직접 실행)

| 항목 | 결과 |
|---|---|
| `melos run format` | **0 changed** (408 files) |
| `melos run analyze` | **5개 패키지 전부 No issues found** |
| `melos run test` | **전부 통과** — admin 42 · dp_design 54 · mobile 100 · **web 246** · dp_core 68 |
| `flutter build web` | **성공**(83.7s) — `main.dart.js` **5.61 MB**, `build/web` 총 54 MB. 폰트 tree-shaking 정상 동작(MaterialSymbols 99%+ 감소) |

기존 테스트 회귀 없음: localizations delegate 추가(Task 2) 후에도 245/245 유지, 작성 페이지 통합(Task 3) 후 246개(기존 4 → 신규 5로 +1), Task 4 후 246개 유지.

## 브라우저 한글 IME 스모크 (필수 AC)

> `cd apps/web && flutter run -d chrome` 으로 실제 브라우저에서 직접 조작해 확인한다.
> **IME 조합은 OS 레벨 입력이라 위젯 테스트·자동화 입력으로 대체할 수 없다.**

| 항목 | 결과 | 비고 |
|---|---|---|
| 1. 본문에 **한글 타이핑** | **PASS(조건부)** | 최초 1회 조합이 어색하나 **제목 `TextField`(일반 위젯)에서도 동일** → flutter_quill 고유 문제 아님. 아래 §플랫폼 제약 참조 |
| 2. 한글 선택 후 **굵게** 적용 | **PASS** | 즉시 렌더 확인 |
| 3. **제목·불릿·인용·코드블록** 적용 | **PASS** | 전부 정상 |
| 4. 게시 → 상세에서 서식 렌더 | **부분** | **게시 자체는 성공**(201, id 반환). 상세 조회에서 `no mock: GET /community/posts/30` — 목 픽스처 결함(아래 §기존 결함) |
| 5. 질문 화면 유사질문 패널·맥락 카드 | **FAIL → 수정 완료** | 🔴 **실제 버그 발견·수정**(아래 §발견·수정 버그) |
| 6. 본문 안내 문구 위치·가독성 | 확인됨 | 기능상 문제 없음 |
| 7. 에디터 레이아웃 | "단순함" | 차단 사유 아님. 디자인 개선은 별도 과제(§범위 밖 피드백) |

**판정: ✅ 채택** — spec §6 Fork 3 폴백으로 전환하지 않는다.

> 판정 근거: 폴백 전환 조건은 "flutter_quill 때문에 한글 입력이 망가지는가"였다. **대조 실험 결과 동일 증상이 일반 `TextField`에서도 재현**되므로 이는 Flutter Web(CanvasKit) 공통 특성이며, 폴백(역시 `TextField` 기반)으로 바꿔도 해결되지 않는다. 서식 적용·마크다운 변환·게시는 전부 정상 동작했다.

## 🔴 발견·수정한 버그 (스모크의 실제 성과)

**증상**: 질문 작성 화면에서 제목 입력 → 유사질문 패널이 뜨는 순간 본문 에디터가 파괴되고 IME가 터짐. 그 예외로 유사질문 패널 렌더까지 실패.

**브라우저 스택트레이스**:
```
question_create_page.dart:75   setState (유사질문 결과 반영)
  → raw_editor_state.dart:963  dispose         ← QuillEditor 재생성
  → closeConnectionIfNeeded                     ← IME 연결 끊김
  → text_input.dart:1178 assertion
     "Range start 9 is out of text of length 1"
```

**근본 원인**: 유사질문 카드가 `if (_similar.isNotEmpty) ...[위젯 2개]`로 조건부 삽입되면 뒤따르는 형제 위젯의 리스트 인덱스가 2칸 밀린다. `DpRichEditor`에 `Key`가 없어 Flutter의 multi-child element 매칭이 위치 기반으로 오매칭 → 에디터 element가 재사용되지 못하고 통째로 재생성. 기존 `TextField`는 컨트롤러가 외부에 있어 텍스트가 보존돼 증상이 드러나지 않았다.

**수정**(커밋 `52eda14`): 두 작성 화면의 `DpRichEditor`에 안정적 `const ValueKey` 부여. 재현 테스트를 먼저 작성해 **수정 전 실패(`Expected: true / Actual: <false>`) → 수정 후 통과**를 확인했다.

## ⚪ 기존 결함 (이번 작업과 무관, 범위 밖)

목 픽스처의 **생성 응답 id와 상세 조회 id가 불일치**한다: `POST /community/posts`는 `id: 30`을 반환하는데 `GET /community/posts/30` 픽스처가 없다(`/10`만 존재). 질문도 동일(`99` vs `1`). 그 결과 목 프로토에서 **작성 → 상세 이동 흐름이 `no mock` 404로 끊긴다.** 이번 변경은 요청 바디의 `bodyMd` 산출 방식만 바꿨으므로 이 결함과 무관하며, 별도 과제로 남긴다.

## ⚪ 플랫폼 제약 (기존부터 존재)

한글 IME **최초 1회 조합이 어색**한 현상은 `QuillEditor`와 일반 `TextField`(제목 입력칸) 양쪽에서 동일하게 재현된다 → **Flutter Web(CanvasKit)의 공통 IME 특성**이며 이번 변경이 만든 회귀가 아니다. 개선하려면 렌더러/IME 레벨 대응이 필요하므로 별도 과제.

## 📋 범위 밖 사용자 피드백 (별도 과제로 기록)

스모크 중 제기된 항목 — 이번 PR 범위가 아니며 별도로 다룬다:
1. 커뮤니티 **검색 기능 부재**
2. 게시판 **문제/신고 페이지 부재**
3. 각 페이지 **오류 신고 메뉴 부재**
4. **전반적 디자인/테마 품질 불만** — 대시보드 외 화면 디자인 미흡, 대시보드도 만족스럽지 않음

## 커밋 이력

| Task | 커밋 | 내용 |
|---|---|---|
| 1 | `ee870e9` | flutter_quill·markdown_quill 도입 + `quillToMarkdown` 헬퍼 + 변환 고정 테스트 9개 |
| 2 | `c7c6f5c` | `DpRichEditor`(제약 툴바) + `app.dart` localizations 배선 + 위젯 테스트 3개 |
| 3 | `1dc9b0b` | 일반글 작성 본문 전환 + 테스트 인덱스 재배치(5개) |
| 4 | `6eb2d70` | 질문 작성 본문 전환(유사질문·LCS 로직 무손상) |
| fix | `52eda14` | 유사질문 조건부 삽입 시 에디터 재생성 방지(`ValueKey`) + 재현 테스트 |

## 알려진 이월 사항

- **변환 회귀 테스트 커버리지 공백**: PROBE로 실측한 12개 서식 중 고정 테스트는 9개. `italic`·`h2`·`ordered`·`codeBlock` 4개는 툴바에 노출되지만 변환 고정 테스트가 없다(플랜 스켈레톤이 그렇게 설계됨). 머지 전 추가 여부 판단 필요.
