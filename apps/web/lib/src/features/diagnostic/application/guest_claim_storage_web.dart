import 'package:web/web.dart' as web;

import 'guest_claim_storage.dart';

class _WebGuestClaimStorage implements GuestClaimStorage {
  @override
  String? read() => readDiagnosticContinuationStorage(
    getItem: (key) => web.window.sessionStorage.getItem(key),
    removeItem: (key) => web.window.sessionStorage.removeItem(key),
  );
  @override
  void write(String rawContinuation) => writeDiagnosticContinuationStorage(
    rawContinuation,
    setItem: (key, value) => web.window.sessionStorage.setItem(key, value),
    removeItem: (key) => web.window.sessionStorage.removeItem(key),
  );
  @override
  void clear() => clearDiagnosticContinuationStorage(
    removeItem: (key) => web.window.sessionStorage.removeItem(key),
  );
}

GuestClaimStorage createGuestClaimStorage() => _WebGuestClaimStorage();
