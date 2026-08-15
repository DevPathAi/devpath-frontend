import 'package:web/web.dart' as web;

import 'guest_claim_storage.dart';

class _WebGuestClaimStorage implements GuestClaimStorage {
  @override
  String? read() => readDiagnosticContinuationStorage(
    getItem: web.window.sessionStorage.getItem,
    removeItem: web.window.sessionStorage.removeItem,
  );
  @override
  void write(String rawContinuation) => writeDiagnosticContinuationStorage(
    rawContinuation,
    setItem: web.window.sessionStorage.setItem,
    removeItem: web.window.sessionStorage.removeItem,
  );
  @override
  void clear() => clearDiagnosticContinuationStorage(
    removeItem: web.window.sessionStorage.removeItem,
  );
}

GuestClaimStorage createGuestClaimStorage() => _WebGuestClaimStorage();
