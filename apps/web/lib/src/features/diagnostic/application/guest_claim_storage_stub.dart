import 'guest_claim_storage.dart';

class _StubGuestClaimStorage implements GuestClaimStorage {
  String? _v;
  @override
  String? read() => _v;
  @override
  void write(String guestId) => _v = guestId;
  @override
  void clear() => _v = null;
}

GuestClaimStorage createGuestClaimStorage() => _StubGuestClaimStorage();
