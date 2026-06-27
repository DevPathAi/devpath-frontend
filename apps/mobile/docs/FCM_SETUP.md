# 실 FCM 결선 가이드 (devpath_mobile)

> 슬라이스 #10 Build D 후속. **클라이언트 결선은 완료**되어 있고, 남은 것은 **외부 설정**
> (Firebase 프로젝트 생성·설정 파일 배치·APNs 키)뿐이다. 아래 단계만 마치면
> `--dart-define=USE_MOCK=false` 로 실 FCM이 동작한다.

## 0. 현재 레포에 결선되어 있는 것 (코드 변경 불필요)

| 항목 | 위치 | 상태 |
|------|------|------|
| 푸시 추상화 `PushService` / `PushMessage` | `lib/src/services/push_service.dart` | ✅ |
| 실 구현 `FcmPushService` (토큰·`onMessage`) | 〃 | ✅ |
| 백그라운드 핸들러 `firebaseMessagingBackgroundHandler` | 〃 (`@pragma('vm:entry-point')`) | ✅ |
| `USE_MOCK` 분기 Provider | 〃 `pushServiceProvider` | ✅ |
| `main`의 초기화 게이팅 (`USE_MOCK=false`일 때만 `Firebase.initializeApp`) | `lib/main.dart` | ✅ |
| 의존성 `firebase_core` / `firebase_messaging` | `pubspec.yaml` | ✅ |
| Android `POST_NOTIFICATIONS` 권한 | `android/app/src/main/AndroidManifest.xml` | ✅ |
| Android google-services 플러그인 (조건부 적용) | `android/settings.gradle.kts` · `android/app/build.gradle.kts` | ✅ |
| iOS 백그라운드 모드 + `Runner.entitlements` | `ios/Runner/Info.plist` · `ios/Runner/Runner.entitlements` | ✅ |

> **목/CI 안전장치**: 설정 파일이 없으면 `main`은 Firebase를 호출하지 않고(기본 `USE_MOCK=true`),
> Android google-services 플러그인도 `google-services.json` 부재 시 **적용되지 않아** 빌드가 깨지지 않는다.
> 따라서 아래 파일들을 배치하기 전까지는 평소처럼 목 모드로 빌드·테스트된다.

식별자(앱 등록 시 그대로 사용):
- Android `applicationId` / iOS `BUNDLE_ID`: **`ai.devpath.devpath_mobile`**

---

## 1. Firebase 프로젝트 생성

1. <https://console.firebase.google.com> → **프로젝트 추가**.
2. 프로젝트 이름 지정(예: `devpath-ai`). Analytics는 선택.

## 2. Android 결선

1. Firebase 콘솔 → 프로젝트 → **앱 추가 → Android**.
   - **Android 패키지 이름**: `ai.devpath.devpath_mobile`
2. **`google-services.json` 다운로드** → `apps/mobile/android/app/google-services.json` 에 저장.
   - 이 파일은 `.gitignore` 처리되어 있다(**커밋 금지**). 구조는 `google-services.json.example` 참조.
3. 끝. 추가 Gradle 편집 불필요 — 파일이 존재하면 `app/build.gradle.kts`의 조건부 분기가
   `com.google.gms.google-services` 플러그인을 자동 적용한다.
4. (선택) 빌드 호환: 본 레포는 AGP `9.0.1` / Kotlin `2.3.20`. google-services 플러그인은
   `settings.gradle.kts`에 `4.4.2`로 선언되어 있다. `flutter build apk` 시 플러그인 버전
   충돌이 나면 해당 버전만 호환값으로 조정한다.

## 3. iOS 결선

> Apple Developer 계정(유료) 필요 — APNs 키와 Push Notifications capability 때문.

1. Firebase 콘솔 → **앱 추가 → iOS**.
   - **번들 ID**: `ai.devpath.devpath_mobile`
2. **`GoogleService-Info.plist` 다운로드** → `apps/mobile/ios/Runner/GoogleService-Info.plist` 에 저장.
   - `.gitignore` 처리(**커밋 금지**). 구조는 `GoogleService-Info.plist.example` 참조.
   - **중요**: Xcode에서 `Runner` 타깃을 선택하고 *Add Files to "Runner"* 로 이 파일을 추가해야
     번들에 포함된다(파일을 폴더에 두는 것만으로는 부족).
3. **APNs 인증 키 생성·업로드**:
   - [Apple Developer → Certificates, Identifiers & Profiles → Keys] 에서 **APNs Auth Key(.p8)** 생성.
   - Firebase 콘솔 → 프로젝트 설정 → **Cloud Messaging → Apple 앱** → APNs 키 업로드(Key ID, Team ID 함께).
4. **Push Notifications capability 연결**:
   - Xcode → `Runner` 타깃 → *Signing & Capabilities* → **+ Capability → Push Notifications** 추가.
   - 이러면 `CODE_SIGN_ENTITLEMENTS` 가 `Runner/Runner.entitlements` 로 연결된다(이미 레포에 포함).
   - 릴리스(App Store) 빌드는 `Runner.entitlements`의 `aps-environment`를 `production`으로 변경.
5. (CocoaPods) `cd apps/mobile/ios && pod install` 로 Firebase pod 동기화.

## 4. 실행 / 활성화

```bash
cd apps/mobile
# 실 API + 실 FCM
flutter run \
  --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=https://<실제 백엔드>
```

`USE_MOCK=false` 이면 `main`이 `Firebase.initializeApp()` 호출 + 백그라운드 핸들러를 등록하고,
`pushServiceProvider`가 `FcmPushService`를 주입한다. 알림센터는 `FirebaseMessaging.onMessage`
(포그라운드) 스트림을 구독한다.

> dart-define이 많아지면 `--dart-define-from-file=config.json`(gitignore 대상)로 묶어도 된다.

## 5. 검증 체크리스트

- [ ] `flutter run --dart-define=USE_MOCK=false` 부팅 시 크래시 없음(설정 파일 인식).
- [ ] 기기/에뮬레이터에서 알림 권한 허용 후 `getToken()` 토큰 수신(로그 확인).
- [ ] Firebase 콘솔 *Cloud Messaging → 테스트 메시지 전송*(토큰 지정) → 포그라운드 수신 시
      알림센터 목록·미읽음 배지 증가 확인.
- [ ] 앱 백그라운드 상태에서 알림 트레이 표시 확인(iOS는 실기기 + APNs 필요).
- [ ] 목 모드 회귀: 인자 없이 `flutter run` 시 기존처럼 동작(Firebase 미접촉).

## 6. 후속(스펙 확정 시)

- **서버 토큰 등록**: `getToken()` 결과를 백엔드에 등록하는 API 연동(타깃 발송용).
- **data 메시지 처리**: `firebaseMessagingBackgroundHandler`에 data payload 처리 로직 추가
  (현재는 `Firebase.initializeApp()`만 — 알림형은 OS 트레이가 자동 표시).
- **알림 채널(Android)**: 커스텀 채널/사운드가 필요하면
  `com.google.firebase.messaging.default_notification_channel_id` meta-data + 채널 리소스 추가.

## 7. CI / 릴리스 빌드에서의 설정 주입

`google-services.json` / `GoogleService-Info.plist` 는 커밋하지 않으므로, 실 빌드를 굽는
파이프라인에서는 **시크릿으로 주입**해 빌드 직전에 해당 경로로 복원한다(예: base64 시크릿 →
파일 디코드). 주입이 없으면 google-services 플러그인이 비적용되어 FCM 없이 빌드된다.
