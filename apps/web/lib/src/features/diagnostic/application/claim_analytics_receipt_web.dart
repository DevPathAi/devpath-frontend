import 'package:web/web.dart' as web;

import 'claim_analytics_receipt.dart';

class _WebClaimAnalyticsReceiptStore implements ClaimAnalyticsReceiptStore {
  @override
  bool contains(String receiptId) => decodeClaimAnalyticsReceiptStorage(
    web.window.sessionStorage.getItem(claimAnalyticsReceiptStorageKey),
  ).contains(receiptId);

  @override
  void record(String receiptId) {
    final storage = web.window.sessionStorage;
    storage.setItem(
      claimAnalyticsReceiptStorageKey,
      addClaimAnalyticsReceiptStorage(
        storage.getItem(claimAnalyticsReceiptStorageKey),
        receiptId,
      ),
    );
  }
}

ClaimAnalyticsReceiptStore createClaimAnalyticsReceiptStore() =>
    _WebClaimAnalyticsReceiptStore();
