# App Links / Universal Links 적용 체크리스트 (하드닝 트랙 B)

> 상태: **체크리스트(구현 보류)**. custom scheme `devpath://callback`은 OS가 소유권을 검증하지
> 않아 동일 스킴을 등록한 악성 앱이 콜백을 가로챌 수 있다(RFC 8252). 이를 **OS가 도메인
> 소유권을 검증하는 https 링크**(Android App Links / iOS Universal Links)로 대체한다.
> 설계 배경: devpath-platform-svc `docs/mobile-auth-hardening.md`(PR #15) 트랙 B.
> 트랙 A(일회용 code + PKCE, PR #16/#50)와 결합하면 "https 링크 + 1회용 code"로 노출·가로채기를 모두 차단.

## 0. 먼저 정해야 할 것 (팀 결정)

> **결정 현황(2026-06-27)**: ① 콜백 도메인 **아직 미확보 → 트랙 B 전체 보류 유지**(도메인 확보 시 재개). ② Android 서명 = **Google Play App Signing 사용 예정**(지문은 Play Console에서 확보).

- [ ] **콜백 도메인/호스트** *(미확보 — 현재 보류 사유)*: 두 well-known 파일을 HTTPS로 서빙할 도메인. 후보: `devpath-landing-page`(정적 호스팅) 또는 `devpath-gateway`. 예: `https://devpath.ai/auth/mobile-callback`.
- [x] **Android 서명 지문 출처 = Google Play App Signing**: 출시 시점에 **Play Console → 앱 무결성 → 앱 서명**의 SHA-256 지문을 `assetlinks.json`에 등록. 내부 테스트/디버그 검증용으로는 debug 키 지문(`~/.android/debug.keystore`)도 함께 등록 가능. (현재 `android/app/build.gradle.kts` release는 debug 키 사용 중 — Play 업로드 키 도입 시 교체.)
- [ ] **iOS Team ID + Bundle ID**: `<TeamID>.ai.devpath.devpath_mobile`(Apple Developer 계정 필요).

## 1. 호스팅할 well-known 파일 (도메인 측)

### Android — `https://<도메인>/.well-known/assetlinks.json`
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "ai.devpath.devpath_mobile",
    "sha256_cert_fingerprints": ["<DEBUG_SHA256>", "<RELEASE_SHA256>", "<PLAY_SIGNING_SHA256>"]
  }
}]
```
- 지문 추출: `keytool -list -v -keystore <keystore> -alias <alias> | grep SHA256`
  (debug 키: `~/.android/debug.keystore`, alias `androiddebugkey`, 비번 `android`).
- **Content-Type `application/json`, 리다이렉트 금지, 200 직접 응답.**

### iOS — `https://<도메인>/.well-known/apple-app-site-association` (확장자 없음)
```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "<TEAM_ID>.ai.devpath.devpath_mobile",
      "paths": ["/auth/mobile-callback"]
    }]
  }
}
```
- **Content-Type `application/json`(또는 무확장 정적), 리다이렉트 금지.** Apple CDN 캐시 주의.

## 2. 앱 네이티브 설정

### Android (`android/app/src/main/AndroidManifest.xml`)
- [ ] MainActivity에 https intent-filter 추가(기존 `devpath://callback`는 전환기 폴백으로 유지 가능):
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="https" android:host="<도메인>" android:pathPrefix="/auth/mobile-callback"/>
</intent-filter>
```

### iOS
- [ ] Xcode → Runner 타깃 → Signing & Capabilities → **Associated Domains** 추가 → `applinks:<도메인>`.
  (`ios/Runner/Runner.entitlements`에 `com.apple.developer.associated-domains` 항목 생성됨.)

## 3. 백엔드 (devpath-platform-svc)

- [ ] `OAuth2LoginSuccessHandler` 모바일 분기의 리다이렉트 타깃을 `devpath://callback?code=` 에서
      `https://<도메인>/auth/mobile-callback?code=` 로 변경(또는 `AuthProperties.mobileRedirectUri` 값만 교체).
      트랙 A의 일회용 code 전달은 그대로 유지.
- [ ] 전환기에는 기존 custom scheme도 한동안 허용(앱 롤아웃 대비).

## 4. 앱 코드 (devpath-frontend)

- [ ] `parseAuthCallbackCode`(현재 `devpath://callback`)가 https 콜백도 받아들이도록 스킴/호스트/경로 조건 확장(전환기엔 custom scheme도 허용).
- [ ] `app_links`는 https 딥링크를 동일 스트림으로 전달하므로 추가 의존성 불필요.

## 5. 검증

- [ ] Android: `adb shell pm verify-app-links --re-verify ai.devpath.devpath_mobile` 후
      `adb shell pm get-app-links ai.devpath.devpath_mobile` 로 `verified` 확인.
- [ ] iOS: 실기기에서 https 링크 탭 → 앱 오픈 확인. Apple **AASA Validator**로 파일 점검.
- [ ] E2E: 로그인 → https 콜백으로 앱 복귀 → 트랙 A code 교환 → 세션 복원.

## 6. 주의

- 서명 지문은 **키스토어마다** 다르다(debug/release/Play 앱서명). 셋 다 등록하지 않으면 해당 빌드에서 검증 실패.
- AASA/assetlinks는 리다이렉트·잘못된 Content-Type·CDN 캐시로 자주 실패한다 — 배포 후 즉시 검증 도구로 확인.
- App Links 미검증 시 OS가 링크를 브라우저로 열어버리므로(앱 미오픈), 전환기 custom scheme 폴백을 유지.
