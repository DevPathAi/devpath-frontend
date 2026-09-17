# 성능 기준선과 예산 (apps/web)

> N04(2026-09-17). mock 릴리스 빌드를 고정 조건에서 측정해 기준선(`perf/baseline.json`)을 만들고, 예산(`perf/budget.json`)과 회귀 게이트(`tools/perf/gate.mjs`, CI job `perf-gate`)를 건다. 측정기: `tools/perf/measure.mjs`.

## 측정 조건 (코드로 고정)

| 프로파일 | 뷰포트 | DPR | CPU | 다운/업 | RTT |
|---|---|---|---|---|---|
| mobile | 390×844 | 3 | 4× | 5 Mbps / 1.5 Mbps (Slow 4G) | 80 ms |
| desktop | 1440×900 | 1 | 1× | 30 Mbps / 10 Mbps | 20 ms |

- 빌드: `flutter build web --release --no-pub --no-web-resources-cdn --dart-define=USE_MOCK=true --dart-define=MISSION_SPINE_ENABLED=true --dart-define=MOCK_PROFILE=onboarded --dart-define=HOME_BASE_URL=http://127.0.0.1:1` (CanvasKit) / 같은 인자 + `--wasm` (wasm A/B).
- 서빙: 루프백 정적 서버, HTML 제외 자산은 `max-age=31536000`(warm 은 같은 컨텍스트의 두 번째 항법 = 브라우저 캐시 사용). 루프백 이외 요청 차단.
- 표본: 기준선은 라우트 × 프로파일 × cold/warm 각 3회(p75 = nearest-rank, 표본 3 이면 최댓값), CI `perf-gate` 는 5회(p75 = 4번째 값). 전송량은 결정적이라 표본 수와 무관하게 비교 가능하다. 모든 Playwright 대기는 명시적 타임아웃(120 s)을 쓴다 — `networkidle` 은 Slow 4G 에서 폰트 다운로드 때문에 기본 30 s 를 넘긴다(CI 실측 run 35174425725).
- 지표: `fcp_ms`(브라우저 first-contentful-paint), `ready_ms`(Flutter 시맨틱스 플레이스홀더가 붙는 시점 = 첫 상호작용 가능; CanvasKit 은 `<canvas>` 라 브라우저 LCP 후보가 없어 LCP 대용), `lcp_ms`(있으면), `inp_ms`(라우트 주 행동 클릭의 event duration 최댓값), `cls`. `null` 은 측정 불가이며 0 으로 적지 않는다.
- 전송량: CDP `Network.loadingFinished` 의 `encodedDataLength` 합. 종류: js / canvaskit_or_wasm / fonts / images / other.

## 예산과 게이트

`perf/budget.json`: LCP(또는 ready) ≤ 2500ms · INP ≤ 200ms · CLS ≤ 0.1 · 전송량 회귀 ≤ +5%(total 과 js+renderer 각각, 기준선의 같은 route·profile·phase 행 대비).

`enforce_absolute: false` — 첫 기준선이 절대 예산 밖(아래)이라 절대 임계 초과는 **경고**로만 남기고, 전송량 회귀는 **즉시 실패**로 강제한다. 절대 임계 안으로 들어오면 `true` 로 바꾼다(기준선을 낮춰 맞추지 않는다).

## 자산 인벤토리 (CanvasKit 빌드, 2026-09-17)

| 자산 | 크기 | 비고 |
|---|---|---|
| `main.dart.js` | 5.7 MB | 앱 코드 |
| `canvaskit/canvaskit.wasm` | 6.9 MB | 렌더러(로컬 번들, `--no-web-resources-cdn`) |
| Pretendard Regular/Medium/SemiBold/Bold (`.otf`) | 1.5 MB × 4 = 6.0 MB | FontManifest 등록 → **시작 시 전부 로드** |
| `D2Coding.ttf` | 4.0 MB | 코드 폰트, FontManifest 등록 → **시작 시 로드**(샌드박스 밖에서도) |
| MaterialIcons / Material Symbols / Cupertino | < 0.2 MB | 트리 셰이킹됨 |
| wasm 빌드 `main.dart.wasm` | 5.2 MB | + skwasm 렌더러 3.4–4.9 MB |

스모크 실측(runs=1): cold 총 전송 **약 22 MB**(fonts 10.4 MB · js 5.9 MB · canvaskit 5.7 MB), 모바일 FCP 약 40 s, 데스크톱 약 7 s. 초기 전송의 절반이 폰트다.

## 결과 (기준선, 2026-09-17, runs=3 → p75 = 최댓값)

기준선 = `perf/baseline.json`(CanvasKit, built_from 22f9dd2). wasm A/B = `perf/renderer-ab-2026-09-17.json`(built_from 6acc146). 단위 ms / KB. `—` 는 측정 불가(브라우저 LCP 후보 없음·주 행동 없음·FCP 미보고).

| 프로파일 | 단계 | 라우트 | CK ready | CK FCP | CK INP | CK 전송 | wasm ready | wasm FCP | wasm INP | wasm 전송 |
|---|---|---|---|---|---|---|---|---|---|---|
| mobile | cold | `/login` | 21485 | 40524 | — | 22000 | 15559 | 34012 | — | 19387 |
| mobile | warm | `/login` | 1310 | 1712 | — | 13 | 1002 | 1384 | — | 13 |
| mobile | cold | `/dashboard` | 21462 | — | — | 22000 | 15560 | 34104 | — | 19387 |
| mobile | warm | `/dashboard` | 819 | 1796 | — | 13 | 1274 | 1532 | — | 13 |
| mobile | cold | `/path` | 21442 | — | — | 22000 | 15560 | 34184 | — | 19387 |
| mobile | warm | `/path` | 2019 | 3108 | — | 13 | 1407 | 1412 | — | 13 |
| mobile | cold | `/mentor` | 21656 | 41052 | — | 22000 | 15583 | 34404 | — | 19387 |
| mobile | warm | `/mentor` | 2372 | 3180 | — | 13 | 921 | 1368 | — | 13 |
| mobile | cold | `/community` | 21444 | — | 376 | 22009 | 15576 | 34296 | 192 | 19395 |
| mobile | warm | `/community` | 699 | 2000 | 552 | 13 | 1336 | 1340 | 160 | 13 |
| desktop | cold | `/login` | 3779 | 7148 | — | 22000 | 2992 | 5972 | — | 19387 |
| desktop | warm | `/login` | 353 | 624 | — | 13 | 262 | 476 | — | 13 |
| desktop | cold | `/dashboard` | 3768 | 7212 | 176 | 22000 | 2992 | 6044 | 176 | 19387 |
| desktop | warm | `/dashboard` | 348 | 664 | 192 | 13 | 192 | 444 | 224 | 13 |
| desktop | cold | `/path` | 3760 | 7220 | 120 | 22000 | 2984 | 6028 | 120 | 19387 |
| desktop | warm | `/path` | 350 | 676 | 112 | 13 | 188 | 440 | 224 | 13 |
| desktop | cold | `/mentor` | 3773 | 7200 | — | 22000 | 2992 | 6012 | — | 19387 |
| desktop | warm | `/mentor` | 369 | 716 | — | 13 | 171 | 436 | — | 13 |
| desktop | cold | `/community` | 3779 | — | 64 | 22009 | 3008 | 6100 | 40 | 19395 |
| desktop | warm | `/community` | 364 | 760 | 264 | 13 | 189 | 488 | 264 | 13 |

### 자산 기여도 (cold, 첫 로드)

| 종류 | CanvasKit | wasm |
|---|---|---|
| JS | 5887 KB | 80 KB |
| 렌더러(canvaskit / wasm+skwasm) | 5710 KB | 8904 KB |
| 폰트 | 10389 KB | 10389 KB |
| 기타 | 14 KB | 14 KB |
| **합계** | **22000 KB** | **19387 KB** |

### 관찰

- CLS 는 전 구간 0(캔버스 렌더링). LCP 는 전 구간 미보고 → `ready_ms` 가 대용 지표.
- wasm 은 cold 전송 −12%(22.0→19.4 MB), 모바일 cold ready −27%(21.4→15.6 s), 데스크톱 −21%(3.8→3.0 s). 폰트 10.4 MB 는 동일.
- warm 은 두 렌더러 모두 13 KB(HTML+매니페스트)만 전송, 데스크톱 ready 0.2–0.4 s.
- `/login` 은 온보딩 완료 mock 세션이라 `/dashboard` 로 즉시 리다이렉트된다(진입점 비용으로 해석). `/mentor` 는 주 행동 버튼을 찾지 못해 INP 미측정.
- 모바일 cold FCP 가 ready 보다 늦거나 미보고되는 행이 있다: 브라우저 FCP 는 캔버스 첫 페인트 기준이라 Flutter 준비 시점과 어긋난다. 예산 판정은 ready 를 쓴다.


## 해석과 후속 과제

1. **폰트가 초기 전송의 절반**: Pretendard 를 한글 서브셋 woff2 로 바꾸고 가변 폰트 하나로 통합하거나 필요한 weight 만 남긴다. D2Coding 은 샌드박스 진입 시 지연 로드한다. 예상 절감 8 MB 이상.
2. **CanvasKit 6.9 MB**: wasm 빌드(skwasm 3.4 MB)와의 A/B 결과를 근거로 렌더러 전략을 정한다. 운영 빌드는 `--no-web-resources-cdn` 없이 gstatic CDN 을 쓰므로 CDN 캐시 효과는 별도로 측정해야 한다.
3. **main.dart.js 5.7 MB**: deferred loading(샌드박스·Monaco·에디터 경로) 후보.
4. 절대 예산(2.5 s) 은 위 세 가지가 반영된 뒤 `enforce_absolute: true` 로 전환한다.
