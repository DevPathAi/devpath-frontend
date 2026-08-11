# 핸드오프 — ①디자인 3-A, Task 13까지 완료 (16 Task 중 13)

> 작성 2026-08-06 · 브랜치 `feat/design-phase3a-shell-fixes` (origin 동기화, develop 미머지)
> 스펙 `docs/superpowers/specs/2026-08-06-design-phase3a-shell-fixes-design.md`
> 계획 `docs/superpowers/plans/2026-08-06-design-phase3a-shell-fixes.md` (16 Task)
> SDD 워크스페이스 `.superpowers/sdd/2026-08-06-design-phase3a-shell-fixes/` — **ledger `progress.md`가 정본이다**
> 이전 핸드오프: `handoff-2026-08-06-design-phase3a-task10-done.md`

## 0. ★먼저 할 일★

**Task 13의 독립 리뷰가 실시되지 않았다.** 다음 세션은 거기서 시작한다.

- 리뷰 대상 diff: `4b55eab..df22641`
- 컨트롤러가 검증한 것: admin **71 green** · `flutter analyze` 0 · 레포 루트 `dart format` 483파일 0 changed
- 검증되지 않은 것: 코드·테스트의 실질(독립 리뷰어의 판단)

리뷰 프롬프트 형식은 `task-11-review.md`·`task-12-review.md`를 낸 dispatch가 참고가 된다(§5.2에 요지).
diff 파일은 `.superpowers/sdd/…/review-<base>..<head>.diff`로 만들어 넘긴다(`.superpowers/`는 gitignore).

그다음 Task 14 → 15 → 16 → 최종 whole-branch 리뷰 → PR → **3-B**(차트 다중 계열).

## 1. 이번 세션이 한 일 (Task 10 재리뷰 + Task 11·12·13)

| 커밋 | 내용 |
|---|---|
| `8b1908d` | Task 10 재리뷰에서 발견한 커버리지 공백을 메움(헤더 컬링 상태의 `scrollPct` 보정) |
| `74aa985` | **Task 11** 커뮤니티 4화면 sliver 전환 |
| `3a1623c` | Task 11 리뷰 지적 반영(드래그 제약 기록·폴백 분기 잠금) |
| `337b078` | **Task 12** admin 2화면 sliver 전환 |
| `4b55eab` | Task 12 리뷰 지적 반영(**대시보드 테스트가 stretch 잔상으로 통과 중이던 것**) |
| `df22641` | **Task 13** admin 제목 단일 출처화 |

**현재 상태:** dp_design **158** · web **340** · admin **71** green, `analyze` 0, `format` 0 changed.

## 2. 남은 것 (Task 14~16)

계획 파일에 전문이 있다. 브리프는 계획의 해당 절을 그대로 읽으면 된다.

| Task | 내용 | 주의 |
|---|---|---|
| 14 | 화면 잡정리 4건 | 샌드박스 탭 좌측 정렬 · 마이페이지 enum 한국어 라벨(**payload 값은 불변**) · 작성 문구 중복 · `beta_pending` 여백 |
| 15 | 커버리지·문서 정합 | `path_title_test` 동어반복 해소 · 샌드박스 헤더 커버 · 주석 교정 · `DESIGN.md` 헤더 스크롤 규칙 |
| 16 | **육안 확인** | 4폭 × 라이트·다크. 절차는 계획 Task 16에 전문 |

### Task 15에 이월된 항목 (이번 세션에서 발생)

- **web `page_header_scroll_test.dart`의 기존 5건**에 `_expectHeaderVisible`(드래그 전 사전 조건)이 없다.
  Task 11·12에서 추가한 6건에는 들어갔다. Task 10 산물이라 범위 잠금으로 남겨뒀다.
- ~~web 9건의 여유폭 확인~~ → **이미 실측 완료(§3.2). 다시 하지 말 것.**

### Task 16 육안 확인 체크리스트 추가분

- **admin 대시보드는 스크롤이 생기지 않는 것이 정상이다.** 운영 목 데이터가 4지표뿐이라
  4열 그리드가 한 줄에 들어간다(실측 `maxScrollExtent=0.0`). admin의 헤더 스크롤 관측은 `reports`에서 한다.

## 3. ★이번 세션의 최대 발견 — 테스트가 stretch 잔상으로 통과하고 있었다★

Task 12에서 admin 대시보드 헤더 스크롤 테스트를 지표 12개(3행)로 짰다. 독립 리뷰어가
**"green이 애니메이션 산물"** 이라고 지적했고, 컨트롤러가 probe로 전부 재확인했다:

```
metrics=12  headerH=84.0  max=83.125     ← max < header. 헤더가 0.875px 남는다
  / pump 1회(android)      bottom = -8.900022366638055  (통과)
  / pumpAndSettle(android) bottom = +0.875              (실패할 값)
  / windows(stretch 없음)  bottom = +0.875              (실제로 실패)
metrics=16  headerH=84.0  max=209.5
  / pump·pumpAndSettle·플랫폼 무관 -> headerFound=0 (컬링)
```

**원인:** flutter_test 기본 타깃 플랫폼이 android라 `StretchingOverscrollIndicator`가 300px
과잉 드래그로 콘텐츠를 늘려 놓고, `pump()` 한 번이 그 잔상 프레임을 샘플링한다.

**교훈 두 가지:**

1. **스크롤 테스트는 「본문이 헤더보다 길다」를 산술로 검산하라.** 필요 조건은 「줄 수」가 아니라
   `maxScrollExtent > 헤더 높이`다. 조건을 만들었다고 **선언**하는 것과 조건이 **성립**하는 것은 다르다.
2. 이 브랜치의 최상위 교훈(2단계 「60자 crumbs」)과 같은 형태다. 더 뼈아픈 건 컨트롤러가
   보고서에 "운영 목 데이터로는 스크롤이 안 생긴다"고 **자진 신고까지 해놓고도**
   테스트 조건 자체가 성립하는지는 검산하지 않았다는 점이다.

### 3.2 web 9화면 여유폭 — 실측 완료 (재조사 금지)

리뷰어가 `⚠️ Cannot verify`로 남긴 항목을 컨트롤러가 해소했다. **전부 안전하다.**

| 화면 | max | 헤더 | 여유 |
|---|---|---|---|
| Q&A 상세 | 4343.2 | 60 | 4283 |
| 게시글 상세 | 3686.3 | 60 | 3626 |
| 학습 콘텐츠 | 3340.0 | 84 | 3256 |
| 학습 경로 | 839.7 | ~84 | 755+ |
| web 대시보드 | 736.0 | ~84 | 652+ |
| 마이페이지 | 516.0 | ~84 | 432+ |
| 설정 | 480.0 | ~84 | 396+ |
| 질문 작성 | 329.0 | 84 | 245 |
| **자유글 작성**(최소) | **245.0** | **84** | **161** |

## 4. Task 11~13에서 반복된 패턴

### 4.1 sliver 전환은 매번 「상태 분기 커버리지 공백」을 만든다

전환 전 `Expanded(child: …)`는 레이아웃이 자명해 테스트가 없어도 안전했지만, 전환 후
`SliverFillRemaining`은 sliver 계약을 지켜야 한다. Task 11(web 4화면)·12(admin 2화면) 모두
로딩·실패 분기에 테스트가 **전무**했고, 각각 4건씩 추가했다.

**비-sliver를 넣으면 반드시 이 예외가 난다** — 회귀 테스트의 RED 근거로 쓸 수 있다:

```
A RenderViewport expected a child of type RenderSliver but received a child of type
RenderPositionedBox
```

### 4.2 독립 리뷰가 두 번 다 실질을 잡았다

- **Task 11**(Approved): `_dragOutsideEditor` 주석이 1차 제약을 빠뜨렸다. 실측 결과
  작성 화면에서 `find.byType(CustomScrollView)`가 **2개**를 매치한다(flutter_quill 툴바가
  `multiRowsDisplay:false`에서 내부 `CustomScrollView`를 만든다) — 표준 파인더는 애초에 못 쓴다.
  다만 리뷰어의 픽셀 계산(에디터 top≈226)은 틀렸다(실측 **194**, 뷰포트 중심 200이 에디터 안).
- **Task 12**(Needs fixes): §3의 stretch 발견.

**리뷰어의 계산도 실측으로 검증하라.** 두 번 다 리뷰어가 세운 수치 주장 중 일부가 어긋났고,
컨트롤러 probe가 교정했다. 리뷰 dispatch 프롬프트에 「계산으로 세운 주장은 가능한 한 실행으로
검증하고, 검증하지 않았으면 그렇게 표시하라」를 넣어두면 리뷰어가 스스로 표시해 준다(Task 12에서 실제로 그랬다).

### 4.3 배선은 「값을 바꿔 red가 나는가」로 증명한다

Task 13에서 상수의 `headerTitle`만 바꿔 실행하니 값 테스트 2건뿐 아니라
`reports_page_test`의 리터럴 단언까지 red가 났다 — 화면이 실제로 상수를 참조한다는 증거다
(리터럴이 남아 있었다면 그 테스트는 통과했을 것). 이 방식이 「배선을 검증하지 않으면
뒤바꿔도 통과한다」를 실제로 닫는다.

## 5. 운영

### 5.1 사고와 교훈

- **`sed`로 import를 일괄 삽입하다 기존 상대 경로 5건을 깨뜨렸다**(`../application/` →
  `../../application/`). 치환 앵커가 넓어 무관한 줄을 함께 먹었다. `git diff`로 즉시 발견·복구.
  **여러 파일에 같은 편집을 넣을 때도 Edit 도구가 안전하다.** `perl -0pi`는 한글·`·` 같은
  문자에서 정규식 수식자 오류로 실패한다(이번에 겪음).
- **`pumpAndSettle`은 로딩 상태를 고정한 테스트에서 타임아웃된다.** 원인은 `DpLoading`이
  아니라(그건 무애니메이션 `StatelessWidget`이다) **가짜 컨트롤러가 로딩을 영구 고정 +
  indeterminate `CircularProgressIndicator`(repeat)** 조합이다. 그 케이스만 `pump()` 한 번으로.
- **`debugDefaultTargetPlatformOverride`를 `setUpAll`에서 바꾸면 안 된다** —
  `The value of a foundation debug variable was changed by the test`로 전 테스트가 실패한다.
  각 테스트 안에서 설정하고 `addTearDown`으로 원복해야 한다(이걸 취약성으로 오독할 뻔했다).

### 5.2 리뷰 dispatch 요지

- 서브에이전트는 `general-purpose`(보고서 파일을 써야 하므로 `code-reviewer`는 부적합 — 쓰기 권한 없음)
- 프롬프트에 반드시: 범위 잠금 · 절대경로 · **보고서 전문은 파일로, 최종 메시지는 한 줄** ·
  「보고서 주장을 그대로 믿지 말고 코드로 재확인」 · 「계산 주장은 실행으로 검증, 못 했으면 ⚠️ 표시」
- 컨트롤러는 리뷰어 판정을 그대로 수용하지 않는다 — **핵심 발견은 직접 probe로 재확인**한다.

### 5.3 그 밖

- `melos`는 PATH에 없다 → `dart pub global run melos run <cmd>`. 단일 패키지는 `cd <pkg> && flutter test`.
- **`python`은 스텁이다** — 대비 스크립트는 `py`로.
- `.superpowers/`는 gitignore다 — SDD 산출물(보고서·리뷰·diff)은 커밋되지 않는다.

## 6. 백로그 (3-A 범위 밖, ledger에도 기록됨)

- **`semanticChildCount` 유실**: `ListView`/`GridView.count`는 자동 설정하지만 `CustomScrollView`는
  기본 `null`이다. Task 10·11·12에서 전환한 **11화면 전부** 스크린리더용 `scrollChildCount`
  메타데이터가 사라졌다. 시각적 회귀는 없음. 고칠 때는 11화면 일괄로.
- **content 화면 이탈(dispose) flush가 폴백을 쓴다**: `hasClients=false`라 정기 flush 임계(0.1)
  미만 진행분이 유실된다. **base `d1ad476`에서도 동일한 사전 존재 동작**이라 Task 10과 무관.
  실측: 실제 본문 48%인데 서버로 0.42(옛 값) 전송. 완료 임계(0.8) 근처에서 완료 처리 지연 가능.
- **작성 화면 에디터 위 휠 스크롤 무반응**: `DpRichEditor`(고정 260px)가 흡수한다. 에디터 내용이
  260px보다 짧으면 아무것도 움직이지 않는다. 전환 이전에도 동일. DESIGN 문서에 "의도"라는 근거는 없다.

## 7. 3-B 예고 (실측 완료, 재조사 금지)

3-A 완료 후 착수한다. 스펙 §9에 전문이 있다.

- **★`chart1`은 `primary`와 값이 완전히 같다★**(라이트 `#B45309`, 다크 `#F59E0B`) — 「Bar·Line을
  `chart1`로 이관」은 **픽셀 변화 0**이다. 색을 실제로 가르려면 `chart1` 값 자체를 재정의해야 하고
  그러면 대비 재검증이 따라온다
- 계열 축 = **과제 유형별 + 마일스톤(주차)별 둘 다**(사용자 결정). 차트 3종이 모두 다중 계열이 되고 범례가 신설된다
- **스키마 마이그레이션도 `devpath-shared` 발행도 불필요**: `path_weekly_tasks`에
  `task_type`(READ/PRACTICE/QUIZ CHECK)·`completed_at TIMESTAMPTZ`가 이미 있다(`V202606181006`).
  마일스톤 진행률은 `/paths/current`가 이미 준다
- 확장 대상: `learning-svc`의 `DashboardService`·`DashboardTimeseries`·DTO + `dp_core` 모델.
  백엔드 DTO의 `date`는 `String` ISO 유지(jsr310 미해결 회피)
- `track`은 사용자당 ACTIVE 경로가 1개라 계열 축으로 부적합
