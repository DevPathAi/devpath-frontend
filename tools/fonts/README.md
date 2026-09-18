# 패키지 폰트 서브셋 (tools/fonts)

`packages/dp_design/fonts/` 의 다섯 파일은 상류 원본이 아니라 `subset_fonts.py` 가 만든 **한국어 웹 서브셋**이다. 파일 이름과 자산 경로는 그대로라 부트스트랩의 CanvasKit fallback URL(`Pretendard-Regular.otf?`)과 ET13 잠금의 경로는 바뀌지 않고, 바이트·sha256 만 `evidence/et13/assets.lock.json` 과 `tools/et13_evidence.dart` 의 `_expectedAssets` 에 다시 고정한다.

## 원본

| 파일 | 상류 | 버전 |
|---|---|---|
| Pretendard-Regular/Medium/SemiBold/Bold.otf | https://github.com/orioncactus/pretendard (`Pretendard-1.3.9.zip` → `public/static/otf/`) | 1.3.9 (name 테이블 `Version 1.309`) |
| D2Coding.ttf | https://github.com/naver/d2codingfont | 1.3.2 (Build 20180524) |

## 유지하는 범위

`subset_fonts.py` 의 `UNICODES` 가 단일 원천이다. 한글 음절 11,172자(U+AC00–D7A3)와 자모(U+1100–11FF, U+3130–318F, U+A960–A97F, U+D7B0–D7FF)는 전부 남긴다 — 글리프가 없으면 CanvasKit 이 gstatic 에서 Noto fallback 을 내려받는데, ET13·browser-ux·perf 샌드박스는 외부 네트워크를 막는다. 라틴(기본·보충·확장 A), 구두점·통화·화살표·수학·도형·딩뱃, CJK 기호, 전각/반각, 변형 선택자를 유지한다. 제품이 그리지 않는 CJK 한자(D2Coding 4,620자)·가나·키릴·그리스·PUA 를 버린다.

## 실측 (2026-09-17)

| 파일 | 원본 | 서브셋 | brotli(참고) |
|---|---|---|---|
| Pretendard-Regular.otf | 1,574,352 | 1,391,260 | 694 KB |
| Pretendard-Medium.otf | 1,584,068 | 1,400,424 | — |
| Pretendard-SemiBold.otf | 1,583,704 | 1,400,032 | — |
| Pretendard-Bold.otf | 1,576,660 | 1,393,548 | — |
| D2Coding.ttf | 4,185,844 | 2,168,772 | 552 KB |

기각한 대안: Pretendard 변수 TTF 는 6.7 MB 로 정적 4개(6.3 MB)보다 크다. woff2(2.0 MB)·woff 는 CanvasKit(FreeType, brotli 없음)이 읽지 못한다. 한글을 KS X 1001 2,350자로 줄이는 것은 희귀 음절이 fallback 으로 빠져 기각.

## 재생성과 검증

```powershell
py -m pip install fonttools==4.65.0
py tools/fonts/subset_fonts.py --source <원본 디렉터리>            # 재생성
py tools/fonts/subset_fonts.py --source <원본 디렉터리> --check    # 패키지 바이트 == subset(원본) 검증
```

출력은 바이트 단위로 재현된다(`recalc_timestamp=False`, `recalc_bounds=False`, fontTools 버전 고정). 재생성 뒤에는 `dart run tools/et13_evidence.dart validate` 가 실패하므로 잠금 두 곳의 bytes/sha256 을 새 값으로 갱신하고, ET13 baseline 은 사람 승인으로만 다시 만든다.
