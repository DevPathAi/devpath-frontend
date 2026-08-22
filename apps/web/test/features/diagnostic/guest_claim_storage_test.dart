import 'package:devpath_web/src/features/diagnostic/application/guest_claim_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy raw guest key는 continuation으로 승격하지 않고 read에서 제거한다', () {
    final values = <String, String>{
      legacyGuestClaimStorageKey: '123e4567-e89b-42d3-a456-426614174000',
    };

    final result = readDiagnosticContinuationStorage(
      getItem: (key) => values[key],
      removeItem: values.remove,
    );

    expect(result, isNull);
    expect(values, isEmpty);
  });

  test('v1 read/write/clear는 legacy를 best-effort로 함께 정리한다', () {
    final values = <String, String>{
      legacyGuestClaimStorageKey: 'raw-legacy-id',
    };
    writeDiagnosticContinuationStorage(
      '{"version":1}',
      setItem: (key, value) => values[key] = value,
      removeItem: values.remove,
    );
    expect(values[diagnosticContinuationStorageKey], '{"version":1}');
    expect(values, isNot(contains(legacyGuestClaimStorageKey)));

    values[legacyGuestClaimStorageKey] = 'raw-legacy-id';
    expect(
      readDiagnosticContinuationStorage(
        getItem: (key) => values[key],
        removeItem: values.remove,
      ),
      '{"version":1}',
    );
    clearDiagnosticContinuationStorage(removeItem: values.remove);
    expect(values, isEmpty);
  });

  test('legacy remove 실패는 유효한 v1 read를 막지 않는다', () {
    final result = readDiagnosticContinuationStorage(
      getItem: (key) =>
          key == diagnosticContinuationStorageKey ? '{"version":1}' : null,
      removeItem: (_) => throw StateError('legacy storage denied'),
    );

    expect(result, '{"version":1}');
  });
}
