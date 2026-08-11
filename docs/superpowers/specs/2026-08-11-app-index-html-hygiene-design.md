# 설계 — 앱 진입 HTML 위생 (`apps/web` · `apps/admin`)

## 1. 배경

`app.leva.ai.kr`이 크롤러와 링크 미리보기에 다음을 내보내고 있다(라이브 실측, 2026-08-11):

```text
title:       devpath_web
description: A new Flutter project.
robots 태그: 없음 (색인 대상)
<body> 텍스트: 0자
```

Flutter 기본 템플릿 값이 그대로 배포돼 있다. 브랜드명조차 없다. `apps/admin`도 동일하다(`devpath_admin` / `A new Flutter project.`).

즉 지금 이 주소를 공유하면 미리보기에 "A new Flutter project."가 뜨고, 본문이 빈 채로 검색 색인 대상이다.

## 2. 목적

1. **링크 공유 시 미리보기를 정상화**한다
2. **빈 페이지가 검색에 색인되는 것을 막는다** — 앱은 로그인 뒤 서비스이고, 공개 콘텐츠와 검색 유입은 홈페이지(`leva.ai.kr`)가 전담하기로 이미 정했다

## 3. 범위

**대상:** `apps/web/web/index.html`, `apps/admin/web/index.html`

**범위 밖:**
- `apps/mobile/web/` — 웹으로 배포되지 않는다(Flutter 앱 프로젝트의 기본 생성물)
- **로그인 전 정적 콘텐츠 삽입** — `<body>`에 소개 HTML을 넣어 크롤러가 읽게 하는 방안. 홈페이지가 공개 콘텐츠를 전담하기로 정했으므로 내용이 이중화되고, Flutter 부팅이 `<body>`를 어떻게 다루는지 검증하는 비용이 이득보다 크다
- 애드센스 스크립트, Monaco 로더, `flutter_bootstrap.js`, `$FLUTTER_BASE_HREF` — **건드리지 않는다.** 이번 변경은 `<head>` 메타에 한정한다

## 4. 변경 내용

### 4.1 `apps/web` (사용자 앱)

| 항목 | 현재 | 변경 후 |
|---|---|---|
| `<html>` | lang 속성 없음 | `lang="ko"` |
| `<title>` | `devpath_web` | `Leva — 학습 로드맵` |
| `description` | `A new Flutter project.` | `적응형 진단 결과에서 시작하는 맞춤 학습 로드맵과, 학습 맥락을 아는 AI 멘토를 제공하는 Leva 앱입니다.` |
| `robots` | 없음 | `noindex` |
| OG (7개) | 없음 | `og:type`·`og:site_name`·`og:title`·`og:description`·`og:url`·`og:image`·`og:locale` |

`og:image`는 홈페이지의 것을 절대 URL로 재사용한다(`https://leva.ai.kr/assets/og-image.png`). 앱 레포에 이미지를 중복해 두지 않는다.

제목은 홈페이지(`Leva — 내 수준에 맞는 다음 단계를 AI가 안내`)보다 담백하게 둔다. 마케팅 문구는 홈페이지가 담당하고, 앱은 이미 들어온 사람이 보는 화면이다.

### 4.2 `apps/admin` (관리자)

`lang="ko"`, `<title>Leva 관리자</title>`, description은 `Leva 서비스 운영을 위한 관리자 도구입니다.`, `noindex`.

**OG는 넣지 않는다.** 관리자 도구는 링크 공유 대상이 아니다(YAGNI).

### 4.3 `noindex`와 광고의 관계

`noindex`를 넣어도 **광고 게재에는 영향이 없다.** Google 공식 문서 근거:

> `<meta name="robots" content="noindex">` rule applies to **all search engine crawlers**. To target specific **non-search crawlers like AdsBot-Google**, you can specify the crawler's user agent token in the name attribute.

광고 크롤러는 검색 크롤러와 분리돼 있어 별도 토큰으로 지정해야 적용된다. 또한 `noindex`는 색인 지시이지 크롤 차단이 아니다("These methods must be available during the crawling process").

## 5. 테스트

이 레포는 **테스트 없는 구현 변경을 금지**한다(CLAUDE.md 절대 조건 2). `index.html`은 정적 파일이므로 파일을 읽어 검사한다.

| 대상 | 단언 |
|---|---|
| `apps/web` | `lang="ko"` · 브랜드 title · description 교정 · `noindex` · OG 7개 |
| `apps/web` 회귀 가드 | `A new Flutter project.`·`devpath_web` **부재** |
| `apps/web` 보호 가드 | **애드센스 스크립트와 퍼블리셔 ID가 여전히 존재** — 메타를 정리하다 지우는 사고를 막는다 |
| `apps/admin` | `lang="ko"` · `Leva 관리자` · `noindex` · 기본 문자열 부재 |

테스트는 각 앱의 `test/` 아래 두고 `melos run test`로 함께 돈다.

## 6. 검증

1. `melos run format` · `melos run analyze` · `melos run test` 전부 통과
2. PR → CI green → `develop` 머지
3. **라이브 확인** — ★**`develop` 머지로는 라이브에 반영되지 않는다.**★ `.github/workflows/ci.yml`에서 이미지 빌드(`web-image`·`admin-image`)와 배포(`web-deploy`) 잡은 `if: github.ref == 'refs/heads/main'`이라 **`main` 푸시에서만** 실행된다(실측: PR·develop에서는 `skipping`). 라이브 반영은 `develop → main` **릴리스**를 거쳐야 하며, 그것은 이 스펙의 범위가 아니다. 릴리스 시점에 `app.leva.ai.kr`의 `title`·`description`·`robots`를 직접 조회해 확인한다
4. 배포 직후 단발 측정으로 판단하지 않는다 — 값이 안정될 때까지 반복 측정한다

## 7. 위험

| 위험 | 대응 |
|---|---|
| 메타 정리 중 애드센스 스크립트 훼손 | §5의 보호 가드 |
| `flutter build web`이 `index.html`을 변형 | 빌드가 치환하는 것은 `$FLUTTER_BASE_HREF`뿐이다. 빌드 산출물(`build/web/index.html`)에서 변경이 살아 있는지 확인한다 |
| 이미지가 재빌드되지 않아 라이브 미반영 | **확인됨(위험이 아니라 사실이다)** — 이미지·배포 잡은 `main` 전용이다. `develop` 머지 시점에는 라이브가 바뀌지 않는 것이 정상이고, 릴리스 때 함께 반영된다 |
| `noindex`가 광고를 막을 것이라는 오해 | §4.3에 공식 근거를 남겼다 |
