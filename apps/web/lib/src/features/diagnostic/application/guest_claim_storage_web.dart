import 'package:web/web.dart' as web;

import 'guest_claim_storage.dart';

class _WebGuestClaimStorage implements GuestClaimStorage {
  static const _key = 'pending_guest_assessment_id';
  @override
  String? read() => web.window.sessionStorage.getItem(_key);
  @override
  void write(String guestId) => web.window.sessionStorage.setItem(_key, guestId);
  @override
  void clear() => web.window.sessionStorage.removeItem(_key);
}

GuestClaimStorage createGuestClaimStorage() => _WebGuestClaimStorage();
