import 'guest_claim_storage_web.dart'
    if (dart.library.io) 'guest_claim_storage_stub.dart';

const diagnosticContinuationStorageKey = 'leva.diagnostic.continuation.v1';
const legacyGuestClaimStorageKey = 'pending_guest_assessment_id';

typedef GuestStorageGetItem = String? Function(String key);
typedef GuestStorageSetItem = void Function(String key, String value);
typedef GuestStorageRemoveItem = void Function(String key);

String? readDiagnosticContinuationStorage({
  required GuestStorageGetItem getItem,
  required GuestStorageRemoveItem removeItem,
}) {
  final current = getItem(diagnosticContinuationStorageKey);
  try {
    removeItem(legacyGuestClaimStorageKey);
  } catch (_) {}
  return current;
}

void writeDiagnosticContinuationStorage(
  String rawContinuation, {
  required GuestStorageSetItem setItem,
  required GuestStorageRemoveItem removeItem,
}) {
  try {
    removeItem(legacyGuestClaimStorageKey);
  } catch (_) {}
  setItem(diagnosticContinuationStorageKey, rawContinuation);
}

void clearDiagnosticContinuationStorage({
  required GuestStorageRemoveItem removeItem,
}) {
  try {
    removeItem(diagnosticContinuationStorageKey);
  } catch (_) {}
  try {
    removeItem(legacyGuestClaimStorageKey);
  } catch (_) {}
}

/// Versioned DiagnosticContinuation JSON을 OAuth 전체 리로드 너머로 보관한다.
///
/// web은 same-tab sessionStorage, VM 테스트는 메모리 구현을 사용한다. 이 경계는
/// codec을 모르게 raw JSON만 다루며 raw answer/provider credential은 받지 않는다.
abstract interface class GuestClaimStorage {
  String? read();
  void write(String rawContinuation);
  void clear();
}

GuestClaimStorage guestClaimStorage() => createGuestClaimStorage();
