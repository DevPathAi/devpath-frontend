import 'guest_claim_storage.dart';

class _StubGuestClaimStorage implements GuestClaimStorage {
  String? _v;
  @override
  String? read() => _v;
  @override
  void write(String rawContinuation) => _v = rawContinuation;
  @override
  void clear() => _v = null;
}

GuestClaimStorage createGuestClaimStorage() => _StubGuestClaimStorage();
