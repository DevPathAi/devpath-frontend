# ET13 커뮤니티 fixture 확대(N06) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ET13 시각/접근성 증거 카탈로그에 커뮤니티 FREE / QNA / FEEDBACK 게시판 fixture 3종(`web-community-free`, `web-community-qna`, `web-community-feedback`)을 추가한다. 기존 visual matrix(폭 320/600/840/1240 × light/dark) 가 compact 와 desktop 을 모두 덮으므로 fixture 는 게시판당 1개다. 카탈로그 계약은 v1 을 유지한 채 fixture 수 12→15, visual case 96→120, a11y case 24→30 으로 확장하고, baseline 상태는 `pending_external_review` 로 두어 사람 승인·provenance 없이는 baseline 을 갱신하지 않는다.

**Architecture:** ET13 계약은 fixture id 순서를 6곳이 동시에 잠근다 — `tools/et13_evidence.dart`(`_fixtureIds`, `_visualSurfaceCounts`, `_a11ySurfaceCounts`, `expectedOwners/Distributions`, `fixtures.length != 12`, `case_count 96`), `evidence/et13/catalog.v1.json`(`fixtures`, `projection_matrix`, `projection_contract_sha256`), 4개 schema(`prefixItems` 12 → 15, `minItems/maxItems` 96/24 → 120/30), `apps/web/test/app/et13_evidence_catalog_contract_test.dart`(`_fixtureIds`, 96/24 단언), `apps/web/lib/src/evidence/et13_web_evidence_app.dart`(`fixtureIds`, `buildEt13WebFixture`), `apps/web/test/evidence/et13_web_evidence_app_test.dart`. 한 PR 에서 전부 같이 바꾸고 `dart run tools/et13_evidence.dart generate && validate` 로 생성 카탈로그·projection sha 를 재계산한다. fixture 본체는 `CommunityHomePage` 의 목록 본문을 provider 없이 그리는 순수 projection 위젯 `WebCommunityBoardProjection(board, posts)` 를 추출해 쓴다(ET13 원칙: "controller/provider state replaced by approved deterministic fixture").

**Tech Stack:** Dart(`tools/et13_evidence.dart`), JSON schema, Flutter web evidence entry(`apps/web/lib/et13_evidence_main.dart`), GitHub Actions `et13-evidence.yml`(PR 은 diagnostic 모드라 baseline 없이 캡처만 수행).

**Spec:** `task.md` §5 N06 · `handoff.md` §9.5.

## Global Constraints

- 브랜치 `feat/et13-community-fixtures-20260917`(develop 에서 분기). 커밋 Conventional Commits + Co-Authored-By.
- fixture id 순서는 기존 12개 **뒤에** 3개를 append 한다(기존 case id·artifact 경로 불변).
- `baseline_status` 는 `pending_external_review` 유지. release_ready 모드 baseline 갱신은 `et13-baseline-approval.yml` 경로(사람 승인)로만.
- 생성 파일(`evidence/et13/generated/*.json`)은 손으로 편집하지 않고 `dart run tools/et13_evidence.dart generate` 로만 만든다.
- `projection_contract_sha256` 은 도구가 계산한 값을 `_projectionContractSha256` 상수와 catalog 에 동일하게 반영한다(도구 `validate` 가 두 값을 대조).

---

### Task 1: `WebCommunityBoardProjection` 추출

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/web_community_board_projection.dart`
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart`(목록 본문 렌더를 projection 호출로 치환)
- Test: `apps/web/test/features/community/web_community_board_projection_test.dart`

**Interfaces:**
- `class WebCommunityBoardProjection extends StatelessWidget { const WebCommunityBoardProjection({super.key, required this.board, required this.posts, required this.onOpenPost, required this.onCompose}); final CommunityBoard board; final List<CommunityPost> posts; final ValueChanged<CommunityPost> onOpenPost; final VoidCallback onCompose; }` — H1/설명/`_BoardFilterBar`(선택 상태) + `DpListRow` 목록 + 빈 상태(`DpEmpty`). 데이터 모델 타입은 `community_home_page.dart` 가 실제로 쓰는 타입을 읽어 맞춘다(추측 금지).

- [ ] Step 1 실패 테스트: 세 게시판 각각에 대해 H1 텍스트('자유게시판'/'Q/A'/'피드백'), 선택된 세그먼트, 항목 수가 렌더되는지. Step 3 구현(페이지에서 위젯 추출, 페이지 동작 불변). Step 4 community 테스트 디렉터리 전체 PASS(기존 IA 테스트가 회귀 방지). 커밋 `refactor(web): extract WebCommunityBoardProjection for deterministic evidence`.

---

### Task 2: fixture 3종 배선(evidence app)

**Files:** `apps/web/lib/src/evidence/et13_web_evidence_app.dart`, `apps/web/test/evidence/et13_web_evidence_app_test.dart`, `apps/web/lib/src/data/web_mock_fixtures.dart`(결정적 게시글 3건 헬퍼 `mockCommunityPosts(board)` 없으면 추가)

- [ ] Step 1 실패 테스트: `Et13WebEvidenceApp.fixtureIds` 가 15개이고 끝 3개가 `web-community-free/qna/feedback`; 각 fixture 가 `WebCommunityBoardProjection` 을 렌더하고 `ET13_READY:<id>` 라벨을 노출. Step 3 구현: `fixtureIds` append, `buildEt13WebFixture` 에 3개 case(`Scaffold(body: WebCommunityBoardProjection(board: CommunityBoard.free, posts: mockCommunityPosts(CommunityBoard.free), onOpenPost: (_) {}, onCompose: () {}))` 등). 커밋 `feat(web): add community board ET13 fixtures`.

---

### Task 3: 카탈로그·스키마·도구 계약 확장

**Files:** `evidence/et13/catalog.v1.json`, `evidence/et13/{catalog,evidence,manifest,generated-cases,baseline-approval}.schema.json`, `tools/et13_evidence.dart`, `apps/web/test/app/et13_evidence_catalog_contract_test.dart`, `evidence/et13/generated/{visual,a11y}-cases.v1.json`(생성)

- [ ] Step 1 계약 테스트를 먼저 갱신(`_fixtureIds` 15개, `fixtures.length * 4 * 2 == 120`, `* 2 == 30`, `'web': 72`, schema `minItems/maxItems` 120/30) → `flutter test test/app/et13_evidence_catalog_contract_test.dart` 실패 확인.
- [ ] Step 3: `tools/et13_evidence.dart` — `_fixtureIds` 3개 append, `_visualSurfaceCounts['web']=72`, `_a11ySurfaceCounts['web']=18`, `expectedOwners['web']=9`, `expectedDistributions['web']=11`, `fixtures.length != 15`, `case_count 120/30`, `stdout 'visual=120 a11y=30'`. catalog.v1.json — `fixtures` 3개(`owner:'web', distribution:'web', route:'/?fixture=<id>', ready_semantics_label:'ET13_READY:<id>', surface_label:'<id>', capture_scope:'body_projection', source_widget:'WebCommunityBoardProjection', substitutions:[…]`), `projection_matrix` 3행. 5개 schema 의 `prefixItems` 에 3개 const 추가, 12→15, 96→120, 24→30.
- [ ] Step 4: `dart run tools/et13_evidence.dart generate` → 출력된 canonical projection sha 로 `_projectionContractSha256` 과 catalog `projection_contract_sha256` 갱신 → `dart run tools/et13_evidence.dart validate` OK → 계약 테스트 PASS → `dart run melos run test` 전체 PASS.
- [ ] 커밋 `feat(et13): extend the evidence catalog with community board fixtures`.

---

### Task 4: PR 과 diagnostic 캡처 확인

- [ ] push, PR → develop. `et13-evidence.yml` 이 PR(diagnostic 모드)에서 15 fixture × 8 visual + 2 a11y 를 캡처해 통과하는지 확인(baseline 비교 없음). 실패 시 로그의 fixture id 로 원인을 좁혀 고친다(폰트·네트워크 차단·readiness 라벨).
- [ ] 문서 `docs/design/et13-community-fixtures.md`: 추가 fixture 표, baseline 승인 절차(사람 승인 + provenance), release_ready 전환 조건. 커밋 `docs: describe community ET13 fixtures and baseline approval`.
- [ ] CI 녹색 후 merge commit.
