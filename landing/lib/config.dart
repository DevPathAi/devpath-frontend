/// web 앱 진입 URL(CTA 대상). 배포 시 실제 도메인으로 주입.
const String kWebAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'https://app.devpath.ai',
);
