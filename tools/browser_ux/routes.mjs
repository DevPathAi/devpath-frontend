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

/// 한 라우트가 내는 외부 요청의 상한. 라우트당 정상값은 **2건**이다(광고 스크립트 +
/// 업데이트 피드 — S3-P5 실측에서 16라우트 전부가 정확히 2건씩이었다). 폰트 청크를
/// 처음 받는 라우트가 12건까지 간다. 폰트 폴백 폭주는 이 자릿수가 아니다 —
/// 2026-09-26 실측은 한 라우트에서 230건, 심할 때 695건(notosanssymbols)이었다.
export const MAX_EXTERNAL_PER_ROUTE = 40;

/// 컨텍스트 총합의 상한은 라우트 수에 **비례**한다. 총합에 고정 상한(옛 40)을 두면
/// 라우트를 늘리는 것만으로 게이트가 붉어진다 — S3-P5 가 8→16 라우트로 넓히자 42 > 40
/// 으로 실패했고, 러너가 그 자리에서 break 해 /settings·/mypage 를 **아예 재지 못했다**.
/// 그래도 총합을 버리지는 않는다: 모든 라우트가 조금씩 더 부르는 느린 증가는
/// 라우트별 증가분만으로는 잡히지 않는다.
export const MAX_EXTERNAL_PER_ROUTE_AVERAGE = 8;

/// 외부 요청 예산을 넘겼으면 실패 문장, 아니면 `null`.
export function externalRequestFailure({ route, delta, total, routeCount }) {
  if (delta > MAX_EXTERNAL_PER_ROUTE) {
    return `${route} external requests +${delta} in one route (font fallback retry storm?)`;
  }
  const budget = MAX_EXTERNAL_PER_ROUTE_AVERAGE * routeCount;
  if (total > budget) {
    return `${route} external requests total ${total} > ${budget} (${routeCount} routes x ${MAX_EXTERNAL_PER_ROUTE_AVERAGE})`;
  }
  return null;
}

/// axe 가 막는 심각도. critical·serious 만 게이트로 삼는다 — moderate 인 `region`
/// 은 Flutter 가 만드는 시맨틱스 트리 구조에서 전 화면에 나므로 게이트가 못 된다.
const BLOCKING_IMPACTS = new Set(['critical', 'serious']);

/// **원인이 서드파티에 있어 앱에서 고칠 수 없는** 위반만, 라우트와 규칙 id 를 함께
/// 못박아 유보한다. 규칙 하나·라우트 하나 단위로만 적는다 — 넓은 예외는 게이트를
/// 썩게 만든다. 유보가 **낡으면 실패한다**(`axeFailures` 참조): 위반이 사라졌는데
/// 항목이 남아 있으면 그 자체가 실패다. 그렇지 않으면 고쳐진 뒤에도 예외가 남아
/// 다음 회귀를 가린다.
export const AXE_WAIVERS = [
  {
    routes: [
      '/community/post/10/edit',
      '/community/1/edit',
      '/community/new',
      '/community/new/post',
    ],
    rules: ['aria-command-name', 'aria-prohibited-attr'],
    why:
      'flutter_quill 11.5.1 의 툴바 버튼이 툴팁을 이중으로 건다 — ' +
      'toggle_style_button.dart:121 이 UtilityWidgets.maybeTooltip(message: tooltip) 로 ' +
      'Tooltip 을 씌우고, 그 안의 QuillToolbarIconButton 이 IconButton(tooltip:) 으로 ' +
      '또 씌운다. 웹 시맨틱스에서 바깥 Tooltip 이 role 없는 라벨 전용 노드(aria-label, ' +
      'pointer-events:none)를, 안쪽 IconButton 이 라벨 없는 role="button" 노드를 만들어 ' +
      '이름과 역할이 서로 다른 노드에 놓인다. 앱에서 개별 버튼 위젯을 감쌀 자리가 없다.',
    followUp:
      '시안 `.bar2` 는 B·I·코드·링크·목록 **5버튼**인데 구현은 12버튼이다. ' +
      'QuillSimpleToolbarConfig.buttonOptions 의 childBuilder 로 5버튼을 직접 그리면 ' +
      '각 버튼에 한국어 라벨과 우리 Semantics 를 줄 수 있어 이 위반과 시안 divergence 가 ' +
      '함께 닫힌다(현재 툴팁은 "Bold"·"Italic" 등 영어다). flutter_quill 11.6.0 에서 ' +
      '이중 툴팁이 고쳐졌는지도 함께 확인한다.',
  },
];

function waiverFor(route) {
  const rules = new Set();
  for (const w of AXE_WAIVERS) {
    if (w.routes.includes(route)) for (const r of w.rules) rules.add(r);
  }
  return rules;
}

/// 한 라우트의 axe 결과를 실패 문장 배열로. 유보한 규칙은 빼고, **낡은 유보**는 더한다.
export function axeFailures({ route, violations }) {
  const waived = waiverFor(route);
  const seen = new Set();
  const failures = [];
  for (const v of violations) {
    if (!BLOCKING_IMPACTS.has(v.impact ?? 'minor')) continue;
    seen.add(v.id);
    if (waived.has(v.id)) continue;
    failures.push(`${route} ${v.id}`);
  }
  for (const rule of waived) {
    if (!seen.has(rule)) {
      failures.push(
        `${route} stale axe waiver: ${rule} no longer fires — remove it from AXE_WAIVERS`,
      );
    }
  }
  return failures;
}
