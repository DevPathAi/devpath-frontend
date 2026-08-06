# 핸드오프 — ①디자인 3-A, Task 10까지 완료 (16 Task 중 10)

> 작성 2026-08-06 · 브랜치 `feat/design-phase3a-shell-fixes` (develop 미머지)
> 스펙 `docs/superpowers/specs/2026-08-06-design-phase3a-shell-fixes-design.md`
> 계획 `docs/superpowers/plans/2026-08-06-design-phase3a-shell-fixes.md` (16 Task)
> SDD 워크스페이스 `.superpowers/sdd/2026-08-06-design-phase3a-shell-fixes/` — **ledger `progress.md`가 정본이다**

## 0. ★먼저 할 일★

**Task 10의 fix에 대한 scoped 재리뷰가 실시되지 않았다.** 다음 세션은 거기서 시작한다.

- fix diff: `d1ad476..a261fa8`
- 컨트롤러가 검증한 것: web **330 green** · 레포 루트 `dart format` **0 changed** · `flutter analyze` 0 issues
- 검증되지 않은 것: 코드·테스트의 실질(재리뷰어의 판단)

구현자가 fix를 만들고 **커밋 없이 멈춰서** 컨트롤러가 위 검증 후 커밋했다(`a261fa8`). 미커밋 변경을 워킹트리에 방치하지 않기 위한 조치다.

재리뷰 절차는 `.superpowers/sdd/…/task-10-review.md`의 발견 2건과 `task-10-report.md`의 fix 보고를 대조하면 된다. 재리뷰 프롬프트 형식은 `task-4-rereview.md`·`task-5-rereview.md`가 참고가 된다.

## 1. 지금까지 (Task 1~10)

브랜치에 커밋 12개. 각 Task는 **구현 → 컨트롤러 직접 검증 → 리뷰 → (필요시) fix 라운드 → scoped 재리뷰** 사이클을 거쳤다.

| Task | 커밋 | 결과 |
|---|---|---|
| 1 | `6961c60` | `DpRailBrand` 데이터형 — 브랜드 전경색 함정을 구조적으로 닫음 |
| 2 | `bb4c702` | web·admin 셸 brand 교체 |
| 3 | `50e528a` | 다크 레일 팔레트 5토큰 (fix 1라운드: format 게이트) |
| 4 | `94f0f6b` | 크롬바 축약 + `DpChromeAction` (fix 1라운드: 산술 8px 누락·주석 정직성) |
| 5 | `cd84cb1` | 브레드크럼 마지막 비링크 (fix 1라운드: 삭제된 회귀 테스트 복원) |
| 6 | `80e21bb` | compact 하단 바 무강조 |
| 7 | `3207c75` | 레일 토글 + `brandRow` — **계획 결함으로 설계 변경** (§3) |
| 8 | `35d4fcb` | `DpTag` 신설, `tag*` 배선 3곳 |
| 9 | `b79e1b0` | `filters` 슬롯 `Wrap` + admin 4화면 배치 통일 |
| 10 | `d1ad476`+`a261fa8` | 문서형 web 5화면 sliver 전환 (fix 1라운드: **§4** — 재리뷰 미실시) |

**현재 상태:** dp_design 158 · web **330** · admin 60 · mobile·dp_core 미변경, `analyze` 0, `format` 0 changed, 대비 미달 **0건**.

## 2. 남은 것 (Task 11~16)

계획 파일에 전문이 있다. 브리프는 `scripts/task-brief PLAN N`으로 뽑는다.

| Task | 내용 | 주의 |
|---|---|---|
| 11 | 커뮤니티 4화면 sliver 전환 | 작성 2화면은 폼 + `DpRichEditor`(flutter_quill) — 에디터 자체 스크롤과 중첩되지 않는지 확인 |
| 12 | admin 2화면(`dashboard`·`reports`) sliver | `users`·`ads`·`support`는 `DpDataTable`이라 **제외** |
| 13 | admin 제목 단일 출처화 | `AdminDestination`에 `headerTitle` 추가, 5화면 리터럴 제거 |
| 14 | 화면 잡정리 4건 | 샌드박스 탭 좌측 정렬 · 마이페이지 enum 한국어 라벨(**payload 값은 불변**) · 작성 문구 중복 · `beta_pending` 여백 |
| 15 | 커버리지·문서 정합 | `path_title_test` 동어반복 해소 · 샌드박스 헤더 커버 · 주석 교정 · `DESIGN.md` 헤더 스크롤 규칙 |
| 16 | **육안 확인** | 4폭 × 라이트·다크. 절차는 계획 Task 16에 전문 |

그다음 **최종 whole-branch 리뷰**(가장 강한 모델) → PR → **3-B**(차트 다중 시리즈).

## 3. ★Task 7 — 계획 결함과 설계 변경★

브리프대로 web에 `onToggleRail`을 배선하면 **접힘 레일에서 오버플로**한다:

- `railCollapsedWidth` 72 − `_buildTop` 패딩 20 = **가용 52px**
- 마크 22 + `IconButton` 최소 탭 타깃 48 = **70px 필요**
- Task 1이 세운 불변조건(「마크는 접힘에서도 남는다」)과 44px 탭 타깃을 **동시에 만족하는 가로 배치가 없다**

**사용자 결정: 접힘 상태에서만 마크 위에 토글을 세로로 쌓는다.** `_buildTop`이 `extended`면 `Row`, 접힘이면 `Column`으로 분기한다. 근거·검토한 대안은 계획 파일 Task 7 절에 기록했고, 코드 주석에도 수치와 「가로로 되돌리지 말 것」 경고를 남겼다.

**구현자가 이 결함을 발견한 방식이 모범적이다:** 브리프대로 구현 → `RenderFlex overflowed by 19 pixels` → **즉흥 우회 대신** `dp_design` 안에 격리 probe를 만들어 「apps/web과 무관한 `dp_nav_rail.dart` 자체의 결함」임을 증명 → 구현을 되돌리고 `BLOCKED` 보고.

## 4. ★Task 10 — 레이아웃 전환이 백엔드 데이터를 바꿨다★

이 브랜치에서 가장 주목할 발견이다. **순수 레이아웃 작업이 서버로 나가는 값을 조용히 바꿨다.**

`content_page.dart`의 `_scrollController`가 기존에는 본문 `SingleChildScrollView`에 붙어 있었는데, sliver 전환으로 `CustomScrollView`(헤더+본문)에 붙게 됐다. `_scrollPct = pixels / maxScrollExtent`의 **분자·분모 양쪽에 헤더 높이가 더해진다.**

**★리뷰어와 컨트롤러가 방향을 반대로 짚었고, 구현자가 교정했다★**

- 리뷰어·컨트롤러: "분모가 커지므로 진행률이 **낮게** 보고된다"
- 구현자(옳음): `a/b < 1`일 때 `(a+c)/(b+c) > a/b`이므로 **부풀려진다.** 실측 50% 지점에서 약 **0.514** 전송

해법: 헤더 박스 높이를 `GlobalKey`로 실측해 양쪽에서 빼 옛 의미를 복원(`pctOld = (pixelsNew − headerH) / (maxNew − headerH)`). 회귀 테스트 2건으로 고정. 계산 근거와 예시 수치를 코드 주석에 남겼다.

**교훈: 레이아웃 리팩터가 데이터 경로를 건드릴 수 있다.** 스크롤 컨트롤러·포커스·라이프사이클 훅이 붙은 위젯을 옮길 때는 그 관측 대상이 바뀌는지 물어라.

## 5. 이 브랜치에서 반복된 패턴

### 5.1 리뷰가 5번 실질적인 것을 잡았다

fix 라운드가 발생한 Task 3·4·5·10 전부, 리뷰가 **테스트 green 상태에서** 결함을 찾았다:

- Task 3: `dart format` 게이트 위반(CI 적색이 될 상태로 커밋됨)
- Task 4: 폭 예산에서 account 간격 8px 누락 — **테스트 4폭이 전부 이 경계에서 34px 이상 여유가 있어 green으로 통과**하고 있었다
- Task 5: 대칭 조건이 load-bearing임을 임시 테스트로 실측하고 **그 테스트를 삭제** — 앞 단계에서 실제 회귀를 낸 코드 경로가 CI에 안 잠긴 채 남을 뻔했다
- Task 10: 위 §4

### 5.2 「알고 있으면서 적어만 두고 넘어가기」가 두 번 나왔다

Task 5(삭제한 임시 테스트)와 Task 10(보고서 §우려의 "사각지대")에서, 구현자가 문제를 **정확히 인지하고 보고서에 적은 뒤 고치지 않고 넘겼다.** 2단계의 「60자 crumbs」와 같은 패턴이다.

**대응:** 리뷰 프롬프트에 「검증에 쓴 테스트를 지우지 마라」와 「보고서의 설계 근거도 주장이다 — 근거가 진술됐다는 사실이 심각도를 낮추지 않는다」를 명시했다. 공통 컨텍스트 파일(`common-context.md`)에도 넣었다.

### 5.3 운영

- **서브에이전트의 최종 메시지가 거의 항상 비어서 온다.** 리뷰어·재리뷰어 프롬프트에 **「보고서 전문을 파일로 쓰고 최종 메시지는 한 줄로」** 를 넣으면 해결된다. 구현자에게도 보고서 파일 경로를 항상 준다.
- **컨트롤러가 매 Task `git log`·테스트·`format`·대비 스크립트를 직접 재확인했다.** 구현자·리뷰어 보고를 그대로 믿지 않는다. `⚠️ Cannot verify from diff` 항목은 컨트롤러가 해소한다.
- **bash 호출 사이 cwd가 리셋되지 않고 남는다** — `cd apps/admin` 후 다음 호출에서 루트 명령을 돌리면 엉뚱한 위치에서 실행된다(`dart format`이 57개 파일만 검사, 대비 스크립트가 파일을 못 찾음). **매 호출에 `cd <레포 루트> &&`를 붙여라.**
- `melos`는 PATH에 없다 → `dart pub global run melos run <cmd>`. 단일 패키지는 `cd <pkg> && flutter test`가 빠르다.
- **`python`은 스텁이다** — 대비 스크립트는 `py`로.
- 공통 컨텍스트를 `common-context.md` 한 파일로 뽑아 dispatch 프롬프트를 짧게 유지했다. 재사용하라.

## 6. 3-B 예고 (실측 완료, 재조사 금지)

3-A 완료 후 착수한다. 스펙 §9에 전문이 있다.

- **★`chart1`은 `primary`와 값이 완전히 같다★**(라이트 `#B45309`, 다크 `#F59E0B`) — 「Bar·Line을 `chart1`로 이관」은 **픽셀 변화 0**이다. 색을 실제로 가르려면 `chart1` 값 자체를 재정의해야 하고 그러면 대비 재검증이 따라온다
- 계열 축 = **과제 유형별 + 마일스톤(주차)별 둘 다**(사용자 결정). 차트 3종이 모두 다중 계열이 되고 범례가 신설된다
- **스키마 마이그레이션도 `devpath-shared` 발행도 불필요**: `path_weekly_tasks`에 `task_type`(READ/PRACTICE/QUIZ CHECK)·`completed_at TIMESTAMPTZ`가 이미 있다(`V202606181006`). 마일스톤 진행률은 `/paths/current`가 이미 준다
- 확장 대상: `learning-svc`의 `DashboardService`·`DashboardTimeseries`·DTO + `dp_core` 모델. 백엔드 DTO의 `date`는 `String` ISO 유지(jsr310 미해결 회피)
- `track`은 사용자당 ACTIVE 경로가 1개라 계열 축으로 부적합
