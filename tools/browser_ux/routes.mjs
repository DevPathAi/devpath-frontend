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

/// 같은 URL 이 한 라우트에서 몇 번까지 나갈 수 있는가. **폭주의 표지는 총량이 아니라
/// 반복이다** — 차단된 폰트 다운로드는 재시도 금지 목록에 들어가지 않아 레이아웃마다
/// 같은 URL 로 다시 나간다(2026-09-26 실측 한 URL 695회 · S3-P5 실측 5청크 × 약 435회).
/// 반면 정상적인 첫 폰트 로딩은 **서로 다른** 청크를 한 번씩 받는다(`/sandbox` 실측 +12).
/// 그래서 총량 상한만 두면 두 가지를 가를 수 없고, 실제로 `/community/1` 의 폭주는
/// 로컬에서 +5 라는 작은 모습으로 나타나 총량 상한을 그냥 지나갔다.
export const MAX_SAME_URL_REPEATS = 3;

/// 한 라우트가 내는 외부 요청 수의 두 번째 그물. 라우트당 정상값은 **2건**
/// (광고 스크립트 + 업데이트 피드 — S3-P5 실측에서 16라우트 전부가 정확히 2건씩)이고,
/// 폰트 청크를 처음 받는 라우트가 12건까지 간다. 16 은 그 실측값 위의 가장 가까운 여유다 —
/// 옛 값 40 은 정상값의 20배라 그 사이 구간을 통째로 흘려보냈다.
export const MAX_EXTERNAL_PER_ROUTE = 16;

/// 컨텍스트 총합의 상한은 라우트 수에 **비례**한다. 총합에 고정 상한(옛 40)을 두면
/// 라우트를 늘리는 것만으로 게이트가 붉어진다 — S3-P5 가 8→16 라우트로 넓히자 42 > 40
/// 으로 실패했고, 러너가 그 자리에서 멈춰 `/settings`·`/mypage` 를 **아예 재지 못했다**.
/// 그래도 총합을 버리지는 않는다: 모든 라우트가 조금씩 더 부르는 완만한 증가는
/// 라우트별 검사만으로는 잡히지 않는다.
export const MAX_EXTERNAL_PER_ROUTE_AVERAGE = 8;

/// 비례 총합의 **바닥**. 라우트가 하나뿐인 잡(`browser-ux-onboarding (consent)`)에서
/// 비례값만 쓰면 예산이 8 이 되어 폰트 청크 첫 수신(실측 12)보다 엄격해진다 —
/// 라우트 수에 따라 반대로 조여지는, 이 파일이 막으려는 바로 그 형태의 결함이다.
export const MIN_EXTERNAL_TOTAL_BUDGET = 32;

/// 외부 요청 예산을 넘겼으면 실패 문장, 아니면 `null`.
///
/// [added] 는 **이 라우트가 새로 낸** 요청 URL 목록이다(컨텍스트 누적값이 아니다).
/// [total] 은 컨텍스트 누적 총합, [routeCount] 는 이 실행이 도는 라우트 수다.
export function externalRequestFailure({ route, added, total, routeCount }) {
  const counts = new Map();
  for (const url of added) counts.set(url, (counts.get(url) ?? 0) + 1);
  let worstUrl = null;
  let worst = 0;
  for (const [url, n] of counts) {
    if (n > worst) {
      worst = n;
      worstUrl = url;
    }
  }
  if (worst > MAX_SAME_URL_REPEATS) {
    return `${route} external request repeated ${worst}x: ${worstUrl} (font fallback retry storm?)`;
  }
  if (added.length > MAX_EXTERNAL_PER_ROUTE) {
    return `${route} external requests +${added.length} > ${MAX_EXTERNAL_PER_ROUTE} in one route`;
  }
  const budget = Math.max(
    MIN_EXTERNAL_TOTAL_BUDGET,
    MAX_EXTERNAL_PER_ROUTE_AVERAGE * routeCount,
  );
  if (total > budget) {
    return `${route} external requests total ${total} > ${budget} (${routeCount} routes)`;
  }
  return null;
}

/// axe 가 막는 심각도. critical·serious 만 게이트로 삼는다 — moderate 인 `region` 은
/// Flutter 가 만드는 시맨틱스 트리 구조에서 전 화면에 나므로 게이트가 못 된다.
const BLOCKING_IMPACTS = new Set(['critical', 'serious']);

/// **원인이 서드파티에 있어 앱에서 고칠 수 없는** 위반만, 라우트·규칙 id·그리고
/// 그 원인이 만드는 **노드 수**까지 못박아 유보한다.
///
/// `rules` 의 값은 유보하는 노드 수의 상한이다. 규칙 이름만 유보하면 같은 라우트에서
/// **우리 코드가** 만든 새 위반이 같은 규칙으로 뭉쳐 들어와 조용히 사라진다 — 유보는
/// 낡지 않은 채로 회귀를 가릴 수 있다. 노드 수가 늘면 막는다(줄어드는 것은 허용한다 —
/// 반응형으로 버튼이 접힐 수 있다).
///
/// 낡은 유보는 그 자체가 실패다 — [staleWaiverFailures] 참조.
export const AXE_WAIVERS = [
  {
    routes: [
      '/community/post/10/edit',
      '/community/1/edit',
      '/community/new',
      '/community/new/post',
    ],
    rules: {
      'aria-command-name': 8,
      'aria-prohibited-attr': 8,
    },
    why:
      'flutter_quill 11.5.1 의 툴바 버튼이 툴팁을 이중으로 건다 — ' +
      'toggle_style_button.dart:121 이 UtilityWidgets.maybeTooltip(message: tooltip) 로 ' +
      'Tooltip 을 씌우고, 그 안의 QuillToolbarIconButton 이 IconButton(tooltip:) 으로 ' +
      '또 씌운다. 웹 시맨틱스에서 바깥 Tooltip 이 role 없는 라벨 전용 노드(aria-label, ' +
      'pointer-events:none)를, 안쪽 IconButton 이 라벨 없는 role="button" 노드를 만들어 ' +
      '이름과 역할이 서로 다른 노드에 놓인다. 앱에서 개별 버튼 위젯을 감쌀 자리가 없다. ' +
      '노드 수 8 은 2026-09-30 로컬 핀 컨테이너 실측이다.',
    followUp:
      '시안 `.bar2` 는 B·I·코드·링크·목록 **5버튼**인데 구현은 12버튼이다. ' +
      'QuillSimpleToolbarConfig.buttonOptions 의 childBuilder 로 5버튼을 직접 그리면 ' +
      '각 버튼에 한국어 라벨과 우리 Semantics 를 줄 수 있어 이 위반과 시안 divergence 가 ' +
      '함께 닫힌다(현재 툴팁은 "Bold"·"Italic" 등 영어다). flutter_quill 11.6.0 에서 ' +
      '이중 툴팁이 고쳐졌는지도 함께 확인한다.',
  },
];

/// 라우트별 유보 맵(규칙 id → 유보하는 노드 수 상한).
function waiverFor(route) {
  const caps = new Map();
  for (const w of AXE_WAIVERS) {
    if (!w.routes.includes(route)) continue;
    for (const [rule, cap] of Object.entries(w.rules)) {
      caps.set(rule, Math.max(caps.get(rule) ?? 0, cap));
    }
  }
  return caps;
}

function seenFor(seen, route) {
  let set = seen.get(route);
  if (!set) {
    set = new Set();
    seen.set(route, set);
  }
  return set;
}

/// 한 라우트·한 폭의 axe 결과를 실패 문장 배열로.
///
/// [seen] 은 라우트별로 **발생한 규칙 id** 를 모으는 누적자다. 낡은 유보 판정은 여기서
/// 하지 않는다 — axe 는 390 과 1240 두 폭에서 돌고, 폭마다 따로 판정하면 한 폭에서만
/// 나는 규칙이 다른 폭에서 하드 실패가 된다. 전 폭을 모아 [staleWaiverFailures] 가
/// 한 번만 판정한다.
export function axeFailures({ route, violations, seen }) {
  const caps = waiverFor(route);
  const failures = [];
  // 방문했다는 사실 자체를 남긴다 — 위반이 없어도 낡은 유보를 판정할 수 있어야 한다.
  const recorded = seenFor(seen, route);
  for (const v of violations) {
    // 심각도 필터보다 **먼저** 기록한다. axe-core 승급으로 유보 규칙이 moderate 로
    // 내려가면 여전히 발생하는데도 「낡은 유보」로 보고돼 버린다.
    recorded.add(v.id);
    if (!BLOCKING_IMPACTS.has(v.impact ?? 'minor')) continue;
    const cap = caps.get(v.id);
    if (cap === undefined) {
      failures.push(`${route} ${v.id}`);
      continue;
    }
    if (v.nodes > cap) {
      failures.push(
        `${route} ${v.id} ${v.nodes} nodes > waived ${cap} — a violation beyond the waived cause`,
      );
    }
  }
  return failures;
}

/// 전 폭을 다 돈 뒤 한 번만 부른다. 유보한 규칙이 **어느 폭에서도** 나지 않았으면 그
/// 유보는 낡았고, 남겨 두면 다음 회귀를 가린다. 방문하지 않은 라우트는 판정하지 않는다 —
/// 모른다고 실패시키면 안 된다.
export function staleWaiverFailures(seen) {
  const failures = [];
  for (const [route, recorded] of seen) {
    for (const rule of waiverFor(route).keys()) {
      if (!recorded.has(rule)) {
        failures.push(
          `${route} stale axe waiver: ${rule} no longer fires — remove it from AXE_WAIVERS`,
        );
      }
    }
  }
  return failures;
}
