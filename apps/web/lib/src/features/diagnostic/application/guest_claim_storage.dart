import 'guest_claim_storage_web.dart'
    if (dart.library.io) 'guest_claim_storage_stub.dart';

/// 비회원 진단 guestId를 OAuth 전체 리로드 너머로 보관(web=sessionStorage).
abstract interface class GuestClaimStorage {
  String? read();
  void write(String guestId);
  void clear();
}

GuestClaimStorage guestClaimStorage() => createGuestClaimStorage();
