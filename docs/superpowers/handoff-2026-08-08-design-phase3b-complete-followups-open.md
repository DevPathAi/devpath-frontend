# 핸드오프 — ①디자인 3-B 완결 + 후속 3건 PR 대기

> 작성 2026-08-08
> 3-B: **머지 완료** — frontend #110(`de388e8`) · learning-svc #43(`a0b0f4a`) · 문서 #109(`58a2d84`)
> 후속: **PR #111 OPEN**(`fix/content-progress-loss`, 3커밋)
> 이전 핸드오프: `handoff-2026-08-06-design-phase3a-task13-done.md`

## 0. 지금 상태

| | 상태 |
|---|---|
| ①디자인 1단계(토큰)·2단계(셸)·3-A(결함+tag)·3-B(차트) | **전부 완결** |
| 3-B 후속 3건 | PR #111 — CI 확인 후 머지하면 끝 |
| 로컬 develop | frontend·learning-svc 둘 다 origin과 동기 |

**①디자인 전체가 이번으로 마무리된다.** 다음 세션은 §4의 백로그에서 고르거나 새 영역으로 간다.

## 1. 3-B가 한 일 (요약)

차트 팔레트를 브랜드에서 분리했다. 3-A까지는 `chart1`이 `primary`와 값이 같아 「차트를 chart1로
이관」해도 픽셀이 하나도 바뀌지 않았다. 이제 앰버 브랜드와 데이터 색이 화면에서 갈린다.

- 팔레트: 파랑 `#1D4ED8`/`#60A5FA` · 자홍 `#BE185D`/`#F472B6` · 보라 `#7E22CE`/`#D8B4FE`
- 진행률 추세: 유형별 3계열(읽기·실습·퀴즈) + `DpChartLegend`, 반투명 채움 제거
- 주차별 진행률 카드 신설(학습 경로 화면). 12주를 계열이 아니라 **X축**에 둔다
- 백엔드: `ProgressPoint.byType`(optional이라 선배포 불필요)
- 판정 스크립트 `docs/superpowers/specs/2026-08-07-chart-palette-check.py`가 6개 기준을 기계로 검사

## 2. ★이번에 실측이 뒤집은 것 — 세 단계 모두에서★

### 2.1 착수 전 계획 검토 (결함 8건, 커밋 `8fb4542`)

**파일·행 참조는 전부 정확했다. 문제는 「계획이 다루지 않은 파급」이었다.**

가장 값진 둘:

- **record 확장은 접근자 호환이지 생성자 호환이 아니다.** `ActivePathCompletions`에 필드를 더하니
  `DashboardServiceTest` 3곳의 `new ...(2-인자)`가 컴파일 불가가 됐다. 계획의 「기존 필드가 유지되므로
  기존 테스트 green」 전제가 여기서 깨졌다.
- **`chart5`(`#8B857D`)가 코드와 기존 대비 스크립트에는 있는데 3-B 스펙 전체에 없었다.**

### 2.2 육안 확인 (결함 2건, 위젯 테스트 전부 green인 상태)

- **「주차별 진행률」이 모든 신규 사용자에게 빈 상자였다.** 경로를 막 만들면 12주가 전부 0%라 막대
  높이가 0이다. 테스트는 `toY: 0`을 정확히 검증해 green이었다 — **3-A에서 세 번 반복된 계열의 네 번째.**
  → 배경 트랙을 깔아 해결.
- **의미론상 옳은 토큰 교체가 가시성을 떨어뜨렸다.** `border`→`surfaceMuted`가 다크에서 1.32→**1.08:1**로
  내려가 축소 캡처에서는 아예 보이지 않았다. 사용자 결정으로 환원하고 스펙에 §4.3을 신설했다.

### 2.3 후속 작업 (PR #111)

- 3-A 백로그의 「11화면 일괄 복원」이 틀렸다 — 실측하니 동적 목록은 2곳뿐이고 나머지는 넣으면 안 된다
- 3-A가 우려한 「셸 밖 4화면 범위 확장」도 과대평가였다 — 실제 결함은 diagnostic 두 곳뿐

**패턴: 앞 단계가 남긴 「~일 것이다」는 대부분 실측에서 범위가 줄거나 뒤집혔다. 먼저 재현부터 한다.**

## 3. 운영 지식 (다음 세션이 바로 쓸 것)

### 3.1 learning-svc 로컬 테스트

```bash
cd devpath-shared && docker compose up -d postgres redis
export DB_URL=jdbc:postgresql://localhost:5432/devpath_3btest   # 전용 DB
cd ../devpath-learning-svc && ./gradlew test
```

- **Redis가 없으면 3건이 실패한다**(헬스체크 503 → `SecurityConfigTest.healthIsPublic` 등). DB만으로는 부족하다.
- **공유 `devpath` DB로 반복 실행하면 `FlywayMigrationTest` 3건이 깨진다** — 통합 테스트가 `contents`를
  TRUNCATE하는데 Flyway는 적용된 마이그레이션을 다시 실행하지 않아 시드가 복원되지 않는다.
- Docker Desktop 자체가 꺼져 있을 수 있다(이번 세션 시작 시 그랬다).

### 3.2 캡처 (3-A 교훈에 추가)

- **`py -m http.server`가 죽으면 폰트가 `ERR_EMPTY_RESPONSE`로 실패해 「아이콘이 □로 깨진 화면」이
  찍힌다.** 나머지는 그럴듯하게 렌더돼 **구현 결함으로 오진하기 쉽다**(이번에 실제로 그럴 뻔했다).
  `curl -s -o /dev/null -w '%{http_code}'` + `$B console --errors`로 즉시 갈린다.
- **`$B reload`는 앱을 초기 상태로 되돌린다**(해시 라우트 유실 → 빈 화면). 재확인은 `goto`로.
- CanvasKit은 브라우저 스크롤이 없다 → 접힌 영역은 **뷰포트 높이를 키워** 캡처(500x1800).
- 라우트는 해시: `http://127.0.0.1:PORT/#/path`

### 3.3 테스트 수치

| 대상 | 값 |
|---|---|
| web | **359** |
| dp_design | **165**(직접) / **163**(`melos run test`) |
| dp_core | 99 · admin 72 · mobile 100 |
| learning-svc | 172 |

**`melos run test`는 `--exclude-tags golden`이라 dp_design을 직접 실행보다 2건 적게 센다.**
두 수치를 섞으면 회귀로 오독한다.

## 4. 남은 백로그

### 4.1 처리 완료 (PR #112, merge `e56f3b7`)

| 항목 | 결과 |
|---|---|
| admin 목 모드 세션 복원 픽스처 부재 | `POST /auth/refresh` 추가 + **픽스처-계약 일치 테스트** 신설. 기존 `bootstrap_callback_test`는 자체 목 어댑터를 써서 픽스처가 비어 있어도 green이었다 |
| 작성 화면 「게시」 버튼 폭 | 재현하니 **1368px**. `Align(centerLeft)`로 감쌌다(자유글·질문 2화면) |

### 4.2 남은 것

| 항목 | 출처 | 실측 결과 |
|---|---|---|
| 작성 화면 에디터 위 휠 스크롤 무반응 | 3-A §6 | `rich_editor.dart`가 `height: 260` 고정 `SizedBox` 안에 `QuillEditor.basic`을 넣고 자체 `ScrollController`를 준다. **flutter_quill 내부 스크롤 전파 동작 조사가 선행**돼야 해 분리했다 |
| 목 마일스톤이 전부 0% | 3-B 보고서 §6 | 진행분 있는 막대를 캡처로 못 본다. 위젯 테스트가 100/50/0%를 덮으므로 캡처 편의 성격이다 |

### 4.3 ★2단계 이월 5건 — 실측 결과 즉시 처리할 실질 결함이 없다★

`handoff-2026-08-05-design-phase2-shell-complete.md` §3이 3단계로 넘긴 항목들을 하나씩 확인했다.
**막연히 「이월 5건」으로 남겨두면 다음 세션이 같은 조사를 반복한다.**

| 항목 | 상태 |
|---|---|
| §3.1 구조적 함정(앱이 `textTheme.*`를 Layer 2 슬롯에 넘기면 슬롯의 전경색이 진다) | 원칙 문제. **현재 실해 사례가 확인되지 않는다.** 새 슬롯을 만들 때 설계 지침으로 쓸 것 |
| §3.2 I2 — `DpChromeBar` 우측 그룹 오버플로 | **현재 도달 불가**(web 액션 1개·admin 0개). 좌측 그룹은 `Expanded`로 개선돼 있다. actions가 늘어나는 시점에 red-repro부터 세울 것 |
| §3.3 I1 잔여 — compact 하단 탭 오표시 | **시각적 부분은 이미 해결**(`dp_app_shell.dart:92-105`가 인디케이터를 투명으로, 아이콘·라벨 색을 비선택과 같게 덮는다). 남은 건 스크린리더 `selected` 플래그뿐이고, 코드 주석대로 **하단 바 자체 구현이 필요**해 범위가 크다 |
| §3.4 문서·주석 정확성 | 핵심이던 **admin 제목 단일 출처는 3-A Task 13에서 해결**됐다(`admin_shell.dart`가 `headerTitle`을 레코드로 갖는다). 남은 줄번호·주석 문구는 사소하다 |

**2단계 스펙 §3의 「`tag*`·`chart*` 3단계 이월」도 3-A(tag)·3-B(chart)에서 전부 소비됐다.**

## 5. 다음 세션 시작 방법

1. `git -C devpath-frontend pull` — PR #111·#112 모두 머지됐다(`7ea8fc3`·`e56f3b7`)
2. **§4.2의 2건 외에는 ①디자인 백로그가 비어 있다.** 새 영역으로 가도 된다
3. **어떤 항목이든 착수 전에 재현부터 한다** — §2가 보여주듯 앞 단계의 서술은 자주 범위가 어긋난다

### 5.1 검증 명령 (CI와 동일하게)

```bash
dart pub global run melos run analyze
dart pub global run melos run format   # ★ dart format --output=none 이 아니라 이것으로 확인할 것
dart pub global run melos run test
```

**`dart format --output=none --set-exit-if-changed`는 검사만 한다** — 출력의 `(1 changed)`는
「고쳤다」가 아니라 「아직 어긋나 있다」는 뜻이다. 이번에 그걸 통과로 오독해 CI format 게이트를
한 번 red로 만들었다. CI가 쓰는 `melos run format`으로 확인하고 **0 changed를 눈으로 본다.**
