# HANDOFF — Leva 모바일 퍼스트 전면 리디자인

> 최종 업데이트: 2026-09-13
>
> 저장소: `devpath-frontend`
>
> 기준 브랜치: `develop` (`22330eb`)
>
> 작업 브랜치: `feat/mobile-first-redesign`
>
> 구현 커밋: `af1995c` (`feat: redesign Leva UI for mobile-first use`)

## 1. 현재 상태

- Leva v2 공통 디자인 시스템과 web 중심 반응형 화면 재구성은 완료됐다.
- 작업은 기존 사용자 작업 트리를 건드리지 않도록 아래 격리 worktree에서 수행했다.
  - `D:\workspace\dpa\.worktrees\frontend-mobile-first-redesign`
- 요청에 따라 gstack 계열 스킬은 사용하지 않았다.
- 운영 배포와 `develop` 병합은 아직 하지 않았다.
- 과거 React→Flutter 및 디자인 단계 기록은 `docs/superpowers/`의 기존 핸드오프 문서에 보존돼 있다.

## 2. 완료한 변경

- 인디고·슬레이트 기반 라이트/다크 팔레트, 타이포, 간격, 라운드, Material 컴포넌트 테마 재정의
- 새 `DpBrandMark`와 Leva 소유 `DpMobileNavigation` 구현
  - `selectedIndex == null`에서도 거짓 선택 시맨틱스를 만들지 않는다.
- 64px 상단 브랜드 바, 확장/축소 레일, 반응형 페이지 헤더 재구성
- 데스크톱 분할형·모바일 집중형 로그인 화면 재설계
- KPI, 목록 행, 태그, 인터랙티브 카드, 상태 화면, 미션 헤더/다음 행동, 대시보드 패널 개선
- web/admin/mobile PWA manifest 테마 색상 동기화
- 모바일·접근성 회귀 수정
  - 390px 진단 드롭다운 오버플로
  - 짧은 높이의 상태 화면 오버플로
  - admin 320px/200% KPI 및 긴 다이얼로그 오버플로
  - 로그인 제목과 버튼의 좌측 기준선 불일치
- 디자인 SSoT `DESIGN.md`를 Leva v2 기준으로 갱신

## 3. 검증 결과

최종 소스 기준으로 아래 명령을 통과했다.

```powershell
dart run melos run format
dart run melos run analyze
dart run melos run test
flutter build web --release
git diff --check
```

- format: 737 files, 0 changed
- analyze: web/admin/mobile/dp_design/dp_core 이슈 0건
- test: web 948, admin 156, dp_design 220, dp_core 174 및 mobile 전체 통과
- web release build 성공
- manifest JSON 3개 파싱 성공
- 구 팔레트 문자열 잔존 검색 결과 0건

## 4. 로컬 브라우저 리뷰

- 릴리스 빌드로 데스크톱 대시보드, compact 대시보드, 진단 화면을 확인했다.
- 데스크톱은 레일·상단 바·카드·차트의 위계와 정렬이 안정적이다.
- compact 화면은 단일 열 카드와 플로팅 하단 내비가 정상 전환된다.
- Windows Chrome headless는 최소 창 폭이 500px라 390px 캡처가 잘려 보였지만, 실제 390px 경계는 위젯 테스트로 검증했다.
- Windows UI 연결기는 `apps: []`, `browsers: []`를 반환했다. 직접 Chrome 실행과 헤드리스 캡처로 대체했다.
- 리뷰 캡처는 `apps/web/build/review-*.png`에 있으며 빌드 산출물이므로 커밋하지 않는다.

## 5. 다음 세션에서 할 큰 작업

다음 세션은 아래 항목부터 시작한다. 이번 핸드오프 세션에서는 범위를 확장하지 않는다.

1. 진단 시작 화면 고도화
   - 현재 대시보드보다 정보 밀도와 제품 서사가 약하고 빈 공간이 많다.
   - 단계 표시, 기대 결과, 진단 설명을 하나의 온보딩 surface로 재구성한다.
2. 모바일 대시보드 정보 밀도 검토
   - KPI가 모두 한 열이라 스크롤이 길다.
   - 390px에서 2열 KPI 또는 가로 요약 패턴을 RED 테스트부터 비교한다.
3. 라이트 테마 실브라우저 시각 리뷰
   - 대비 자동 테스트는 통과했지만 이번 실브라우저 캡처는 시스템 다크 테마 중심이었다.
4. 로그인 완료 이후 주요 경로 실브라우저 순회
   - Today → Path → Content → Sandbox → Mentor → Community 순서로 desktop/compact를 확인한다.
5. 리뷰 후 `develop` 대상 PR 생성 및 배포는 별도 승인된 세션에서 수행한다.

## 6. 다음 세션 시작 명령

```powershell
cd D:\workspace\dpa\.worktrees\frontend-mobile-first-redesign
git fetch origin
git switch feat/mobile-first-redesign
git status --short --branch
git log -3 --oneline --decorate
```

예상 상태:

- `feat/mobile-first-redesign`가 `origin/feat/mobile-first-redesign`를 추적
- worktree clean
- HEAD가 이 핸드오프 커밋

착수 전에는 `HANDOFF.md` §5의 첫 항목만 선택해 실패 테스트를 먼저 만든다.
