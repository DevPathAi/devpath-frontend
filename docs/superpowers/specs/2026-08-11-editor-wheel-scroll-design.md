# 설계 — 작성 화면 에디터 휠 스크롤 무반응 해소

## 1. 배경

①디자인 3-A가 남긴 백로그 마지막 실질 결함이다. 3-A 핸드오프의 서술:

> **작성 화면 에디터 위 휠 스크롤 무반응**: `DpRichEditor`(고정 260px)가 흡수한다. 에디터 내용이 260px보다 짧으면 아무것도 움직이지 않는다. 전환 이전에도 동일. DESIGN 문서에 "의도"라는 근거는 없다.

즉 마우스 커서가 에디터 위에 있으면 **페이지 전체가 멈춘 것처럼 보인다.** 내부에 스크롤할 내용이 없어도 휠 이벤트를 에디터가 소비한다.

`post_create_page.dart:123-124`와 `question_create_page.dart:160-161`의 주석은 이렇게 적혀 있다:

> 본문 에디터(DpRichEditor)는 고정 높이(260px)의 자체 스크롤 영역이라 sliver 안에서도 높이가 유한하고, **페이지 스크롤과 경쟁하지 않는다.**

**뒷문장은 사실이 아니다.** 경쟁하고, 에디터가 이긴다.

## 2. 목적

에디터 위에서 휠을 굴려도 **페이지가 스크롤된다.** 툴바는 본문 편집 중 계속 보인다.

## 3. 실측 (설계의 근거)

| 항목 | 값 | 확인 방법 |
|---|---|---|
| `QuillSimpleToolbar` 높이 | **42.0px** | 위젯 테스트에서 `tester.getSize` |
| 현재 에디터 뷰포트 높이 | 244.0px | `SizedBox(260)` − `Padding(8)×2` |
| `QuillEditorConfig.scrollable` | 기본 `true` | flutter_quill 11.5.1 문서 |
| 두 작성 화면의 외부 스크롤 | **이미 `CustomScrollView` 존재** | 소스 확인 |

flutter_quill 문서의 `scrollable`:

> When set to `false` the editor always expands to fit the entire content of the document and should normally be placed as a child of another scrollable widget.

`QuillSimpleToolbarConfig._toolbarSize`는 **private이라 외부에서 지정할 수 없다.** 따라서 툴바 높이는 실측값을 상수로 쓰고, 그 값이 유지되는지 테스트로 고정한다(라이브러리 버전이 올라 높이가 바뀌면 red).

## 4. 변경 내용

### 4.1 에디터가 내용만큼 늘어난다

`DpRichEditor`의 본문을 다음으로 바꾼다.

- `QuillEditorConfig(scrollable: false)` — 내부 스크롤 제거
- `SizedBox(height: 260)` → `ConstrainedBox(minHeight: 260)` — 빈 상태에서도 지금과 같은 크기를 유지하되 내용에 따라 늘어난다
- 자체 `ScrollController`는 **유지한다.** `QuillEditor`가 캐럿 추적에 요구하는 인자이고, `scrollable: false`여도 생성자에 필요하다

중첩 스크롤이 사라지므로 휠 이벤트가 상위 `CustomScrollView`로 간다.

### 4.2 툴바를 고정한다

`DpRichEditor`를 **툴바와 본문으로 분리 가능**하게 만든다. 위젯을 둘로 쪼개되, 지금처럼 한 덩어리로 쓰는 사용처가 깨지지 않도록 기존 `DpRichEditor`는 둘을 합쳐 놓은 형태로 남긴다.

- `DpRichEditorToolbar` — 툴바만. 높이 상수 `kDpRichEditorToolbarHeight = 42.0`를 노출한다
- `DpRichEditorBody` — 본문만(`scrollable: false` + `minHeight`)
- `DpRichEditor` — 위 둘을 `Column`으로 묶은 기존 형태(테스트·다른 사용처 보호)

작성 화면 두 곳은 `DpRichEditor` 대신 다음 구조를 쓴다.

```text
CustomScrollView
  SliverToBoxAdapter(헤더)
  SliverPadding
    SliverList.list([제목, ...])
  SliverPersistentHeader(pinned: true, 툴바)      ← 고정
  SliverPadding
    SliverToBoxAdapter(본문 에디터)
  SliverPadding
    SliverList.list([태그, 버튼, ...])
```

`SliverPersistentHeaderDelegate`의 `minExtent`·`maxExtent`는 **툴바 높이 + 구분선 1px = 43.0**으로 한다.

**테두리를 쪼갠다.** 지금은 툴바·구분선·본문이 **하나의 `DecoratedBox`**(`border` + `borderRadius: DpRadius.input`)에 들어 있다. 툴바를 sliver로 빼면 이 상자가 둘로 갈라지므로 각각 자기 테두리를 갖는다.

| | 테두리 | 모서리 |
|---|---|---|
| 툴바 | 좌·우·상 + 하단 구분선 | **위쪽만** 둥글게 |
| 본문 | 좌·우·하 | **아래쪽만** 둥글게 |

붙어 있을 때는 지금과 같은 하나의 상자로 보이고, 툴바가 고정돼 떨어질 때만 갈라진다.

**툴바에 배경색을 채운다.** 지금은 배경이 없어 뒤가 비친다. 고정된 채로 본문이 지나가면 글자가 겹쳐 보이므로 불투명해야 한다. 색은 기존 코드가 쓰는 토큰(`context.dpColors`)에서 표면색을 쓰고, 정확한 토큰명은 구현 시 `dp_design`의 정의를 확인해 고른다 — 추측하지 않는다.

### 4.3 ★알려진 부작용 — 수용하고 확인한다★

`pinned` 헤더는 **뒤따르는 sliver가 스크롤되는 동안 계속 상단에 붙어 있다.** 다음 pinned 헤더가 밀어내야 사라지는데 이 화면에는 없다.

따라서 **본문을 지나 태그 입력까지 내려가도 툴바가 남는다.** 작성 화면이 제목 → 본문 → 태그 → 버튼으로 짧아 실害는 크지 않다고 보지만, 이는 판단이지 확인이 아니다. **구현 후 캡처로 확인하고 사용자가 판단한다.** 어색하면 되돌리거나 다른 방식으로 간다.

### 4.4 틀린 주석을 고친다

두 화면의 "페이지 스크롤과 경쟁하지 않는다"를 실제 동작에 맞게 고친다.

## 5. 테스트

**결함을 먼저 재현한다.** 지금 코드에서 red가 나야 하고, 그것이 이 작업의 근거다.

| 대상 | 단언 |
|---|---|
| **휠 전파(재현)** | 에디터 위에서 휠 이벤트를 보내면 **바깥 `CustomScrollView`의 offset이 증가**한다. 현재 코드에서는 0으로 남아 red |
| 에디터 확장 | 내용이 길면 에디터 높이가 `minHeight`를 넘어 커진다 |
| 최소 높이 | 빈 문서에서 본문 높이가 260 이상이다 |
| **툴바 높이 상수** | `tester.getSize(툴바).height == kDpRichEditorToolbarHeight` — 라이브러리 버전이 올라 높이가 바뀌면 red |
| 툴바 고정 | 스크롤 후에도 툴바가 화면 상단 좌표에 남는다 |
| 기존 보호 | `DpRichEditor`의 기존 테스트(툴바·에디터 렌더, 버튼 화이트리스트)가 그대로 통과한다 |

## 6. 검증

1. `melos run format`(0 changed 눈으로 확인) · `analyze` · `test` 전부 통과
2. **육안 확인** — 두 작성 화면을 캡처해 ①툴바가 스크롤 중에도 보이는지 ②본문을 지난 뒤 툴바가 남는 모습이 어떤지(§4.3) 확인한다
3. 라이브 반영은 `develop → main` 릴리스를 거친다. 이 레포는 이미지 빌드·배포가 `main` 전용이다

## 7. 위험

| 위험 | 대응 |
|---|---|
| 툴바 높이 상수가 라이브러리 업데이트로 어긋남 | §5의 높이 단언 테스트가 잡는다 |
| `pinned` 툴바가 본문을 벗어나서도 남음 | §4.3 — 알려진 부작용. 캡처로 확인 후 사용자 판단 |
| `scrollable: false`로 캐럿 추적이 깨짐 | `ScrollController`를 유지한다. 위젯 테스트로 입력·렌더를 확인하고, 긴 문서에서 캐럿이 화면 밖으로 나가는지는 육안 확인 항목에 포함한다 |
| 두 화면의 구조 변경이 기존 테스트를 깸 | `post_create_page_test.dart`·`question_create_page_test.dart`가 이미 있다. 그것들을 먼저 돌려 무엇이 깨지는지 확인하고 진행한다 |
| 테두리 분할로 시각이 어긋남(이음매가 보임) | §4.2의 모서리 규칙. 캡처로 확인한다 — 붙어 있을 때 하나의 상자로 보여야 한다 |
