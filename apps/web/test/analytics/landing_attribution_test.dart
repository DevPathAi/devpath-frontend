import 'package:devpath_web/src/analytics/landing_attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const valid = LandingAttribution(
    source: 'leva.ai.kr',
    medium: 'cta',
    content: 'hero_diagnostic',
  );

  test('landing UTM 세 값을 한 묶음으로 session store에 보존한다', () {
    final store = MemoryLandingAttributionStore();

    final captured = captureLandingAttributionFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/diagnostic'
        '?utm_source=leva.ai.kr&utm_medium=cta&utm_content=hero_diagnostic',
      ),
      store: store,
    );

    expect(captured, valid);
    expect(store.read(), valid);
  });

  test('OAuth callback처럼 UTM 없는 URL에서도 저장된 값을 복원한다', () {
    final store = MemoryLandingAttributionStore()..write(valid);

    expect(
      captureLandingAttributionFromUri(
        Uri.parse('https://app.leva.ai.kr/auth/callback?code=opaque'),
        store: store,
      ),
      valid,
    );
  });

  test('새 유효 UTM은 이전 랜딩 위치를 교체한다', () {
    final store = MemoryLandingAttributionStore()..write(valid);
    const next = LandingAttribution(
      source: 'leva.ai.kr',
      medium: 'cta',
      content: 'pricing_mentor',
    );

    expect(
      captureLandingAttributionFromUri(
        Uri.parse(
          'https://app.leva.ai.kr/login'
          '?utm_source=leva.ai.kr&utm_medium=cta&utm_content=pricing_mentor',
        ),
        store: store,
      ),
      next,
    );
    expect(store.read(), next);
  });

  test('누락·중복·허용되지 않은 값은 저장하지 않고 기존 값을 지킨다', () {
    final store = MemoryLandingAttributionStore()..write(valid);
    final invalidUris = [
      'https://app.leva.ai.kr/diagnostic?utm_source=leva.ai.kr&utm_medium=cta',
      'https://app.leva.ai.kr/diagnostic?utm_source=leva.ai.kr&utm_medium=other&utm_content=hero',
      'https://app.leva.ai.kr/diagnostic?utm_source=other.example&utm_medium=cta&utm_content=hero',
      'https://app.leva.ai.kr/diagnostic?utm_source=leva.ai.kr&utm_source=duplicate&utm_medium=cta&utm_content=hero',
      'https://app.leva.ai.kr/diagnostic?utm_source=leva.ai.kr&utm_medium=cta&utm_content=contains%20space',
      'https://app.leva.ai.kr/diagnostic?utm_source=leva.ai.kr&utm_medium=cta&utm_content=${List.filled(65, 'a').join()}',
    ];

    for (final raw in invalidUris) {
      expect(
        captureLandingAttributionFromUri(Uri.parse(raw), store: store),
        valid,
      );
      expect(store.read(), valid);
    }
  });

  test('storage codec은 정확한 스키마와 길이 제한만 허용한다', () {
    expect(decodeLandingAttribution(null), isNull);
    expect(decodeLandingAttribution(encodeLandingAttribution(valid)), valid);
    expect(decodeLandingAttribution('[]'), isNull);
    expect(
      decodeLandingAttribution(
        '{"source":"leva.ai.kr","medium":"cta","content":"hero","extra":"x"}',
      ),
      isNull,
    );
    final tooLong = List.filled(65, 'a').join();
    expect(
      decodeLandingAttribution(
        '{"source":"leva.ai.kr","medium":"cta","content":"$tooLong"}',
      ),
      isNull,
    );
    expect(decodeLandingAttribution('not-json'), isNull);
  });

  test('플랫폼 저장소도 같은 탭 생명주기에서 값을 왕복한다', () {
    final store = landingAttributionStore();
    addTearDown(store.clear);
    store.clear();

    store.write(valid);

    expect(store.read(), valid);
  });
}
