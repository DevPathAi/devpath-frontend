// browser-ux 러너가 순회하는 라우트와 그 선택 논리.
//
// playwright 를 끌어오지 않는 순수 모듈이다. CI 가 의존성 설치보다 **먼저**
// `node --test tools/browser_ux/run.test.mjs` 를 돌리므로(.github/workflows/ci.yml
// 「Unit-test the runner」), run.mjs 를 import 하는 테스트는 그 단계에서
// `require('playwright')` 로 죽는다. serve.mjs·report.mjs 와 같은 분리다.

export const ROUTES = [
  '/dashboard',
  '/path',
  '/community',
  '/community?board=QNA',
  '/community?board=FEEDBACK',
  '/mentor',
  '/sandbox',
  '/content/future-async-await',
  // S3-P4 가 바꿨는데 이 러너가 한 번도 방문하지 않던 화면들. mock id 는
  // web_mock_fixtures.dart 의 `GET /community/posts/10`·`/questions/1` 이다.
  '/community/post/10',
  '/community/post/10/edit',
  '/community/1',
  '/community/1/edit',
  '/community/new',
  '/community/new/post',
  '/settings',
  '/mypage',
];

/// 실행할 라우트. `--routes=/a,/b` 로 덮을 수 있다 — 온보딩·미인증 화면은 라우터
/// 게이트 때문에 다른 mock 프로필로 빌드해야 도달하므로 별도 잡이 그 목록을
/// 넘긴다(`browser-ux-onboarding`).
///
/// 「없음」과 「빈 값」을 가른다. `--routes=` 를 빈 값으로 준 것은 사용자 실수이고,
/// falsy 검사로 기본값을 돌려주면 그 잡이 한 라우트가 아니라 전부를 재고도
/// 초록으로 끝난다.
export function routesOf(options) {
  const raw = options.routes;
  if (raw === undefined || raw === null) return ROUTES;
  const list = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!list.length) throw new Error('--routes= was empty');
  return list;
}
