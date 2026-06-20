# CLAUDE.md — devpath-frontend

> 프론트엔드 모노레포(Flutter): `apps/web`·`apps/admin`(Flutter Web) + `apps/mobile`(Flutter 앱) + 공용 패키지 `packages/dp_core`(순수 Dart)·`packages/dp_design`(디자인 시스템). **Dart pub workspaces + melos 7**로 단일 해석.

## 🚫 절대 조건 — 모든 작업에 예외 없이 적용

아래 세 가지는 이 레포의 **어떤 작업에도 우선하는 최상위 규칙**이다. 개별 지시가 이를 명시적으로 면제하지 않는 한 항상 따른다.

### 1. 추측·예상 금지
- 코드·설정·동작·의존성을 **추측하지 않는다.** 모르면 파일을 읽고 명령을 실행해 사실을 확인한 뒤 행동한다.
- "아마 ~일 것이다", "보통 ~하다" 같은 가정에 기반한 변경·답변·커밋을 금지한다.
- 확인이 불가능하면 진행을 멈추고 묻는다. 모르는 것을 아는 척하지 않는다.

### 2. 테스트 코드 우선 (Test-First)
- 모든 기능 추가·수정은 **실패하는 테스트를 먼저 작성**하고, 그 테스트를 통과시키는 최소 구현을 작성한다.
- 테스트 없는 구현 변경을 금지한다. 변경 후에는 반드시 테스트를 실행해 통과를 **눈으로 확인**한다.
- 구체적 테스트·검증 명령은 아래 "빌드·테스트" 절을 따른다.

### 3. 문제 발생 시 코드 분석 우선
- 버그·테스트 실패·예상 밖 동작이 생기면 **추측으로 고치지 않는다.** 먼저 관련 코드·로그·스택트레이스를 읽어 근본 원인을 규명한다.
- 증상만 덮는 임시방편(땜질)을 금지한다. 원인을 설명할 수 있을 때만 수정한다.

### 4. 신규 작업은 무조건 신규 브랜치
- 모든 신규 작업은 시작 전 `develop`에서 **새 작업 브랜치**(`feat/*`·`fix/*`·`chore/*`·`docs/*`)를 분기해 그 위에서 진행한다. `develop`·`main` 등 공유/통합 브랜치에서 **직접 작업하지 않는다**.
- 이유: **여러 세션이 동시에 작업할 때 파일 관리 충돌을 예방**한다. 미커밋 변경을 공유 브랜치 working tree에 방치하지 않는다.

### 5. 결과를 자화자찬하지 않는다 — 항상 검증·테스트로 확인
- 작업 결과를 스스로 칭찬·과신하지 않는다. "완료했다", "문제없다"는 **검증·테스트로 확인한 근거가 있을 때만** 말한다.
- 당장 문제가 없어 보여도 **모든 작업은 항상 엄격하게 검증·테스트**해 결과를 확인한다. 검증되지 않은 성공·완료를 보고하지 않는다.

### 6. 서브에이전트 작업 범위 강제 (Scope Lock)
- 서브에이전트(Task/Agent)에 작업을 위임할 때는 **수행할 작업의 경계를 명시적으로 못박는다.** 지시문에 "이 작업만 수행하고, 끝나면 보고 후 정지하라. 다른 Task로 진행하거나 명세에 없는 코드를 임의 구현하지 말라"를 항상 포함한다.
- 서브에이전트는 **부여된 단일 Task의 명세만** 구현한다. 플랜의 다음 단계로 넘어가거나, 제공되지 않은 스펙을 추측·즉흥(improvise)하는 것을 **금지**한다. 명세가 부족하면 멈추고 `NEEDS_CONTEXT`로 보고한다.
- 위임 결과는 **항상 컨트롤러가 직접 검증**한다(커밋 로그·파일 구조·테스트). 서브에이전트의 완료 보고를 그대로 신뢰하지 않는다.
- 범위를 벗어난 산출물이 발견되면 수용하지 말고, 미푸시 상태라면 정상 지점으로 reset 후 플랜대로 재구현한다.

## 🔀 Git 브랜치 전략 — 모든 작업에 예외 없이 적용

`main`은 **보호 브랜치**다. 직접 커밋·푸시·force-push를 **금지**한다(GitHub 브랜치 보호 설정 여부와 무관하게 규칙으로 강제한다). `develop`이 통합 브랜치다.

**흐름(2단계 PR):**
1. **작업 브랜치 분기**: `develop`에서 `feat/*`·`fix/*`·`chore/*`·`docs/*` 브랜치를 만든다.
2. **develop으로 PR → 머지**: 작업 브랜치 → `develop` PR을 올리고 CI 통과 후 머지한다.
3. **main으로 PR → 머지(릴리스)**: 릴리스 시점에 `develop` → `main` PR을 올려 머지한다. main에는 오직 이 경로로만 들어간다.

**규칙:**
- 작업 브랜치는 항상 `develop`에서 분기하고 `develop`으로 PR한다. `main`을 직접 base로 PR하지 않는다(릴리스 PR 제외).
- `main`·`develop`에 직접 push 금지. 모든 변경은 PR을 거친다.
- 머지 전 CI(`melos run analyze`·`melos run test`)가 **녹색**임을 확인한다(실패 시 머지 금지).
- 이력 보존을 위해 머지는 기본 **merge commit**(스쿼시·리베이스 머지는 명시 요청 시에만).

## 빌드·테스트 (모노레포 루트에서 melos로 실행)

> 구조: **Dart pub workspaces + melos 7**. 멤버 = `packages/dp_core`(순수 Dart)·`packages/dp_design`(Flutter 디자인 시스템) + `apps/{web,admin,mobile}`(Flutter). `web`·`admin`은 **Flutter Web**. 설정은 루트 `pubspec.yaml`의 `workspace:`+`melos:` 키(과거 `melos.yaml` 대체). 사용법 요약은 `melos_README.md`.

- 의존성 동기화: `melos bootstrap` (별칭 `melos bs`)
- 정적 분석: `melos run analyze` (Flutter=`flutter analyze`, 순수 Dart=`dart analyze`)
- 테스트: `melos run test` (Flutter=`flutter test --exclude-tags golden`, 순수 Dart=`dart test`)
- 포맷: `melos run format`(CI 게이트, `dart format --set-exit-if-changed .`) / 적용 `melos run fix`
- 단일 앱 실행: `cd apps/web && flutter run -d chrome`(admin 동일) · `cd apps/mobile && flutter run`
- melos 호출: 최초 1회 `dart pub global activate melos 7.0.0`; PATH 미설정 환경에선 `dart pub global run melos <cmd>`.

테스트는 **Flutter 테스트 스택**으로 작성한다(`flutter_test` + `flutter_riverpod`의 `ProviderContainer`/위젯 테스트). 실패 테스트를 먼저 쓰고 `melos run test`로 통과를 눈으로 확인한다(절대 조건 2). 위젯 테스트의 폭 의존은 `tester.view.physicalSize`, `context.dpColors`를 쓰는 위젯엔 `theme: DpTheme.light()`를 준다.

## 환경 변수

- 런타임 설정(API 엔드포인트·`useMock` 등)은 **`--dart-define`(또는 `--dart-define-from-file`)** 로 주입하고 `AppConfig.fromEnvironment`(`String.fromEnvironment`/`bool.fromEnvironment`)로 읽는다. 기본값은 목 프로토. 비밀값(키·토큰)은 절대 커밋하지 않는다.
- 화면 설계: [storyboard](https://github.com/DevPathAi/storyboard) · [documents/06_화면_기능_정의서](https://github.com/DevPathAi/documents/blob/main/06_화면_기능_정의서.md)

## 공통 규칙

- Git: Conventional Commits — [documents/09_Git_규칙_정의서](https://github.com/DevPathAi/documents/blob/main/09_Git_규칙_정의서.md). 브랜치 전략은 위 "🔀 Git 브랜치 전략" 절을 따른다(main 직접 금지, develop 경유 2단계 PR).
- 코드 리뷰: [documents/12_코드_리뷰_규칙](https://github.com/DevPathAi/documents/blob/main/12_코드_리뷰_규칙.md)
- 비밀값(Claude API 키·OAuth·결제 키)은 절대 커밋하지 않는다.

