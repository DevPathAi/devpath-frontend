@TestOn('browser')
library;

import 'package:devpath_web/src/features/diagnostic/application/guest_claim_storage.dart';
import 'package:devpath_web/src/features/diagnostic/application/guest_claim_storage_web.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('browser sessionStorage read/write/remove는 v1 key와 legacy 정리를 보존한다', () {
    final storage = web.window.sessionStorage;
    final subject = createGuestClaimStorage();
    addTearDown(subject.clear);
    subject.clear();

    storage.setItem(legacyGuestClaimStorageKey, 'legacy-id');
    subject.write('{"version":1}');

    expect(storage.getItem(diagnosticContinuationStorageKey), '{"version":1}');
    expect(storage.getItem(legacyGuestClaimStorageKey), isNull);
    expect(subject.read(), '{"version":1}');

    storage.setItem(legacyGuestClaimStorageKey, 'legacy-id');
    subject.clear();
    expect(storage.getItem(diagnosticContinuationStorageKey), isNull);
    expect(storage.getItem(legacyGuestClaimStorageKey), isNull);
  });
}
