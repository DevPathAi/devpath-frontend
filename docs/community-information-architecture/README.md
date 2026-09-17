# 커뮤니티 IA 및 Flutter Web 제품 품질 작업 문서

> 최종 갱신: 2026-09-17 KST
>
> 제품 화면: `https://app.leva.ai.kr`
>
> 구현 상태: 운영 배포 및 운영 화면 검증 완료
>
> 문서 상태: 구현·검증·배포·장애 대응·후속 과제를 재현 가능한 형태로 정리 완료

## 1. 이 문서 세트의 목적

이 디렉터리는 다음 두 요구사항을 하나의 작업 단위로 추적한다.

1. Flutter로 만든 `app.leva.ai.kr`가 React 기반의 완성도 높은 웹 앱과 동등한 화면 디자인과
   제품 구성을 갖추는 방법을 검토하고, 실제 구현 원칙과 검증 게이트로 구체화한다.
2. 기존의 `커뮤니티 → 게시판 → QA / 자유 / 피드백` 구조를
   `커뮤니티 → 자유게시판 / Q/A / 피드백` 구조로 교정한다.

여기서 **React급**은 React 프레임워크로 재작성한다는 뜻이 아니다. 정보 구조, 반응형 구성,
URL·브라우저 동작, 상호작용 상태, 접근성, 성능, 시각 회귀 방지 수준이 현대적인 웹 제품의
기대치에 도달한다는 뜻이다. 검토 결과 Flutter 3.44.1과 현재의 `dp_design`으로 달성 가능하며,
프레임워크 교체보다 공용 셸·라우팅 상태·디자인 토큰·검증 체계를 강화하는 편이 비용과 회귀 위험이
낮다.

## 2. 문서 지도

| 문서 | 역할 | 언제 읽는가 |
|---|---|---|
| [task.md](./task.md) | 요구사항을 실행 가능한 작업, 산출물, 합격 기준으로 분해한 기준 문서 | 구현 범위와 완료 여부를 판단할 때 |
| [workflow.md](./workflow.md) | 브랜치 생성부터 테스트, 화면 캡처, 배포, 장애 복구까지의 재현 절차 | 같은 작업을 다시 수행하거나 회귀를 수정할 때 |
| [history.md](./history.md) | 실제 결정, 커밋, PR, CI, 릴리스, 장애와 해결의 시간순 기록 | “무엇을 왜 했는가”와 증적을 감사할 때 |
| [handoff.md](./handoff.md) | 현재 상태, 남은 일, 다음 세션 시작 명령, 금지 사항 | 다른 작업자가 즉시 이어받을 때 |
| [기존 운영 감사](../superpowers/reports/2026-09-16-flutter-react-grade-production-audit.md) | 운영 화면의 React급 품질 진단과 원칙 | 설계 배경을 검토할 때 |
| [기존 전체 계획](../superpowers/plans/2026-09-15-flutter-web-react-grade-design.md) | 전체 앱의 단계별 고도화 계획 | 커뮤니티 밖의 후속 범위를 선택할 때 |

## 3. 요구사항의 정확한 해석

### 3.1 변경 전

```text
커뮤니티
  └─ 게시판
      ├─ 전체
      ├─ QA
      ├─ 자유
      └─ 피드백
```

문제는 게시판이 페이지 내부 필터에만 존재해 데스크톱 사이드바가 현재 위치를 설명하지 못하고,
`전체`가 기본값이어서 URL·화면 제목·선택 상태가 사용자의 실제 목적과 분리된다는 점이었다.

### 3.2 변경 후

```text
커뮤니티
  ├─ 자유게시판  /community?board=FREE
  ├─ Q/A         /community?board=QNA
  └─ 피드백      /community?board=FEEDBACK
```

- 데스크톱: 세 게시판을 사이드바의 독립 목적지로 항상 노출한다.
- 모바일: 하단 내비게이션은 `오늘 / 학습 경로 / AI 멘토 / 커뮤니티` 네 항목을 유지하고,
  커뮤니티 페이지의 제목 메뉴(44px 이상, compact 전용)로 세 게시판을 전환한다. 페이지 안 세그먼트는 2026-09-17 에 제거했다(history D07).
- `/community` 또는 알 수 없는 `board` 값은 자유게시판으로 해석한다.
- `전체`는 사용자에게 노출되는 주요 게시판에서 제외한다.
- URL, 사이드바 선택, H1, 설명, 브레드크럼, 상세·작성 화면의 복귀 문맥은 같은 `board` 값을 쓴다.

## 4. 현재 운영 상태 요약

| 항목 | 현재 값 |
|---|---|
| 프론트엔드 운영 소스 | `8d19a0bf1170085fa238eaddeae40aa7b8f08b90` |
| 기능 PR | [#203](https://github.com/DevPathAi/devpath-frontend/pull/203) — `develop` 병합 |
| 릴리스 PR | [#204](https://github.com/DevPathAi/devpath-frontend/pull/204) — `main` 병합 |
| 릴리스 ID | `ms-20260916-community-ia` |
| mission-on 이미지 | `sha256:a204810fb509a9e68090b078d5720a23aab1feba53625943de038290733f839e` |
| mission-off 롤백 이미지 | `sha256:ff158b7fadf6df4d233e4230d6fd2b4a98a3d5e11fb3607aa093f4f26d4366e8` |
| 운영 승격 | [GitOps run 35114312986](https://github.com/DevPathAi/devpath-gitops/actions/runs/35114312986) — 성공 |
| Landing-last | [GitOps run 35119923465](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119923465) — 성공 |
| 운영 UI | FREE, QNA, FEEDBACK 데스크톱 및 QNA 모바일 캡처 검증 완료 |

## 5. 코드의 단일 진실 원천

| 책임 | 파일 |
|---|---|
| 데스크톱·모바일 목적지, 선택 인덱스, 브레드크럼 | `apps/web/lib/src/features/shell/presentation/app_shell.dart` |
| 기본 게시판, URL 동기화, 제목·설명(compact 제목 메뉴), 정렬, 게시판별 CTA | `apps/web/lib/src/features/community/presentation/community_home_page.dart` |
| compact/desktop 목적지 분리 계약 | `packages/dp_design/lib/src/shell/dp_app_shell.dart` |
| 정보 구조 회귀 테스트 | `apps/web/test/features/community/community_information_architecture_test.dart` |
| 데스크톱·모바일 계층 테스트 | `apps/web/test/features/community/community_navigation_hierarchy_test.dart` |
| 쿼리·기본값·전환 테스트 | `apps/web/test/features/community/community_home_page_test.dart` |
| 브레드크럼 테스트 | `apps/web/test/features/shell/app_shell_breadcrumb_test.dart` |
| 공용 셸 adaptive 테스트 | `packages/dp_design/test/shell/dp_app_shell_adaptive_destinations_test.dart` |

## 6. 다음 작업자가 지켜야 할 핵심 원칙

1. `develop` 최신 상태에서 별도 worktree와 기능 브랜치를 만든다. 기존의 더러운 작업 트리를 정리하거나
   덮어쓰지 않는다.
2. 화면 문자열만 바꾸지 않는다. URL, 선택 상태, H1, 브레드크럼, 상세·작성 복귀 경로를 한 묶음으로
   검증한다.
3. 데스크톱 목적지 목록을 compact 하단 내비게이션에 그대로 재사용하지 않는다.
4. `CommunityBoard.all`은 데이터 계층 호환성 때문에 남아 있어도 사용자 선택 목록에는 넣지 않는다.
5. 스타일을 feature에 하드코딩하지 않고 `DpColors`, `DpSpacing`, `DpTypography`, 공용 셸·상태
   컴포넌트를 사용한다.
6. 변경은 실패하는 테스트부터 만들고, 대상 테스트 → 패키지 테스트 → 전체 analyze/test → release build
   순으로 넓힌다.
7. 운영 캡처는 URL, 뷰포트, 시각 결과, 파일 SHA-256을 함께 남긴다.
8. 비밀값은 문서·로그·커밋에 기록하지 않는다. 자격 증명 문제는 종류와 조치만 기록한다.

## 7. 30분 종료 규칙

한 세션에서 전체 앱 고도화까지 확장하지 않는다. 30분 종료 시점에는 다음 네 가지를 반드시 남긴다.

1. 현재 Task의 상태와 검증 결과를 문서에 반영한다.
2. 남은 큰 작업은 [handoff.md](./handoff.md)의 다음 세션 큐로 이동한다.
3. 문서 또는 코드 변경을 전용 브랜치에 커밋하고 원격에 푸시한다.
4. 로컬 `context-save` 체크포인트에 브랜치, 커밋, 남은 작업, 시작 명령을 기록한다.

이 원칙은 “시간이 부족하므로 검증을 생략한다”는 뜻이 아니다. 현재 세션에서 안전하게 끝낼 수 있는
작업의 경계를 명확히 하고, 나머지를 재현 가능한 입력과 합격 기준을 갖춘 다음 세션 Task로 넘긴다는
뜻이다.
