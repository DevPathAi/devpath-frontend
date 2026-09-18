# 폰트 다이어트 (apps/web 초기 전송량, N04 후속 1)

> 2026-09-17. `docs/design/perf-baseline.md` 가 지목한 "초기 전송의 절반이 폰트(10.4 MB)" 를 줄인다. 서브셋 스크립트·원본·범위는 `tools/fonts/README.md` 가 원천이다.

## 결정

| 항목 | 결정 | 근거(실측) |
|---|---|---|
| Pretendard 4 weight | **정적 OTF 4개 유지 + 한국어 웹 서브셋** (각 1.57 → 1.39 MB) | 변수 폰트 `PretendardVariable.ttf` 는 6.7 MB 로 정적 합(6.3 MB)보다 크다. woff2(2.0 MB)·woff 는 CanvasKit(FreeType, brotli 없음)이 읽지 못한다. 한글 11,172자를 KS X 1001 2,350자로 줄이면 희귀 음절이 gstatic Noto fallback 으로 빠져 기각. |
| D2Coding | **서브셋(4.19 → 2.17 MB) + 지연 로드** | CJK 한자 4,620자·PUA 를 제거. FontManifest 에서 빼고 `DpCodeFont.ensureLoaded()` 가 코드 스타일이 처음 그려질 때(DpMarkdown·샌드박스·Monaco stub·admin 시작) `FontLoader` 로 등록한다. 자산 경로는 그대로라 ET13 `loadEt13EvidenceAssetFonts` 는 계속 명시 로드한다. |
| weight 축소(w500 제거) | 하지 않음 | `labelSmall` 등이 w500 을 쓴다. 디자인 변경 없이 얻는 절감(−1.4 MB)은 별도 결정. |

`FontWeight` 는 변수 폰트의 `wght` 축에 자동 매핑되지만(Flutter 문서 "FontWeight also controls the weight attribute of variable fonts"), 크기 때문에 변수 폰트 자체를 쓰지 않는다.

## 결과 (desktop `/dashboard`, 단일 표본, `tools/perf/measure.mjs`)

| 단계 | 전 | 후 |
|---|---|---|
| cold 총 전송 | 22,000 KB | **17,199 KB** (−22%) |
| cold fonts | 10,389 KB | **5,584 KB** (Pretendard 4개만) |
| warm 총 전송 | 13 KB | 13 KB |
| `/content/c1` 코드 블록 | — | D2Coding 이 그 화면에서만 지연 로드되고(요청 로그 실측) 코드 블록은 고정폭으로 그려진다 |

기준선 `perf/baseline.json` 은 이 빌드로 runs=3 재측정해 갱신했다(전송량은 결정적이라 게이트는 새 값 대비 +5% 회귀를 본다).

## 지연 로드가 드러낸 시맨틱스 함정

PR CI 의 `browser-ux` 가 390px `/content/future-async-await` 에서 axe `scrollable-region-focusable`(serious) 로 실패했다. 코드 블록이 처음엔 fallback 폰트로 배치돼 가로 스크롤 범위가 생기고, D2Coding 이 등록되며 텍스트는 다시 배치되지만 **스크롤 시맨틱 노드는 `overflow-x: scroll` 로 남았다**(로컬 재현: 로드 4 s 뒤 재스캔에도 유지, 화면은 두 빌드가 동일). `DpCodeFont.loaded`(ValueNotifier) 를 `DpMarkdown` 이 듣고 로드 완료 시 서브트리를 새 키로 다시 만들어 시맨틱스를 새로 생성한다(테스트 `dp_code_font_test.dart`). 수정 후 axe 390/1240 통과.

## ET13 영향

- `evidence/et13/assets.lock.json` 과 `tools/et13_evidence.dart` `_expectedAssets` 의 다섯 폰트 bytes/sha256 을 재고정하고 `derived_by: tools/fonts/subset_fonts.py` 를 적었다. `validate` 와 계약 테스트 통과.
- 부트스트랩의 CanvasKit fallback URL(`Pretendard-Regular.otf?`)·producer 계약 테스트의 폰트 경로는 변경 없음.
- baseline 은 `pending_external_review` 그대로. 폰트 바이트가 바뀌었으므로 다음 baseline 승인은 이 서브셋으로 캡처된 것이어야 한다.

## 측정 중 드러난 더 큰 지렛대 (미수행, 결정 필요)

운영(`https://app.leva.ai.kr`, nginx 1.31.3)이 **모든 자산을 무압축·`Cache-Control` 없이** 서빙한다(2026-09-17 실측: `main.dart.js` 5,969,649 B `Content-Type: application/javascript`, 압축 헤더 없음 · 폰트 `application/octet-stream` · `canvaskit.wasm` 7,229,467 B). 로컬 brotli 실측으로 폰트만 5.6 MB → 약 3 MB, `main.dart.js`·`canvaskit.wasm` 은 통상 1/3~1/4 로 줄어 cold 전송이 17 MB → 약 6–7 MB 가 된다. `apps/web/nginx.conf` 에 사전 압축(`gzip_static`/brotli) 과 `ETag` 재검증 캐시 헤더를 넣는 것이 폰트 서브셋보다 큰 효과이며, `web-image-release-contract` 와 측정기(압축 서빙 재현)를 함께 바꿔야 한다.

그 밖에 남은 것은 `docs/design/perf-baseline.md` §해석과 후속 과제 2–4(렌더러 전략·deferred loading·`enforce_absolute`).
