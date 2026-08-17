import 'claim_analytics_receipt.dart';

class _MemoryClaimAnalyticsReceiptStore implements ClaimAnalyticsReceiptStore {
  String? _raw;

  @override
  bool contains(String receiptId) =>
      decodeClaimAnalyticsReceiptStorage(_raw).contains(receiptId);

  @override
  void record(String receiptId) =>
      _raw = addClaimAnalyticsReceiptStorage(_raw, receiptId);
}

final _store = _MemoryClaimAnalyticsReceiptStore();

ClaimAnalyticsReceiptStore createClaimAnalyticsReceiptStore() => _store;
