import 'package:devpath_web/src/analytics/journey_handoff.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> deterministicBytes(int length) => List.generate(length, (i) => i + 1);

void main() {
  group('opaque journeyId handoff', () {
    test('generates and validates an opaque identifier', () {
      final id = generateOpaqueJourneyId(randomBytes: deterministicBytes);
      expect(id, 'AQIDBAUGBwgJCgsMDQ4PEA');
      expect(isValidJourneyId(id), isTrue);
      expect(isValidJourneyId('person@example.com'), isFalse);
      expect(isValidJourneyId('short'), isFalse);
    });

    test('adds one handoff value while preserving query and fragment', () {
      final id = generateOpaqueJourneyId(randomBytes: deterministicBytes);
      final target = buildJourneyHandoffUri(
        Uri.parse(
          'https://app.leva.ai.kr/diagnostic?track=backend&journeyId=old&journeyId=collision#start',
        ),
        id,
      );

      expect(target.queryParametersAll['journeyId'], [id]);
      expect(target.queryParameters['track'], 'backend');
      expect(target.fragment, 'start');
    });

    test('stores a valid value and immediately removes it from visible URL', () {
      final store = MemoryJourneyIdStore();
      final id = generateOpaqueJourneyId(randomBytes: deterministicBytes);
      Uri? replacement;

      final captured = captureJourneyIdFromUri(
        Uri.parse(
          'https://app.leva.ai.kr/diagnostic?journeyId=$id&track=backend#start',
        ),
        store: store,
        replaceVisibleUri: (uri) => replacement = uri,
      );

      expect(captured, id);
      expect(store.read(), id);
      expect(
        replacement.toString(),
        'https://app.leva.ai.kr/diagnostic?track=backend#start',
      );
    });

    test('invalid or duplicate values are removed and not stored', () {
      for (final url in [
        'https://app.leva.ai.kr/diagnostic?journeyId=person%40example.com',
        'https://app.leva.ai.kr/diagnostic?journeyId=AQIDBAUGBwgJCgsMDQ4PEA&journeyId=AQIDBAUGBwgJCgsMDQ4PEA',
      ]) {
        final store = MemoryJourneyIdStore();
        Uri? replacement;
        expect(
          captureJourneyIdFromUri(
            Uri.parse(url),
            store: store,
            replaceVisibleUri: (uri) => replacement = uri,
          ),
          isNull,
        );
        expect(store.read(), isNull);
        expect(replacement!.queryParameters.containsKey('journeyId'), isFalse);
      }
    });

    test('does not overwrite an established browser journey on collision', () {
      final store = MemoryJourneyIdStore()..write('EREREREREREREREREREREQ');
      final incoming = generateOpaqueJourneyId(randomBytes: deterministicBytes);
      Uri? replacement;

      expect(
        captureJourneyIdFromUri(
          Uri.parse(
            'https://app.leva.ai.kr/diagnostic?journeyId=$incoming#start',
          ),
          store: store,
          replaceVisibleUri: (uri) => replacement = uri,
        ),
        isNull,
      );
      expect(store.read(), 'EREREREREREREREREREREQ');
      expect(replacement.toString(), 'https://app.leva.ai.kr/diagnostic#start');
    });
  });
}
