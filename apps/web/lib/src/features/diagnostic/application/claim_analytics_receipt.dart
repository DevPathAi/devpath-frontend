import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../analytics/analytics_contract.dart';
import 'claim_analytics_receipt_web.dart'
    if (dart.library.io) 'claim_analytics_receipt_stub.dart';

const claimAnalyticsReceiptStorageKey =
    'leva.analytics.result_claimed.receipts.v1';
const maxClaimAnalyticsReceipts = 64;

final _receiptPattern = RegExp(r'^[a-f0-9]{64}$');

/// A bounded, same-tab acknowledgement that survives a hard reload.
///
/// Only a SHA-256 digest is persisted. The digest is scoped to the user so a
/// logout/account switch cannot suppress a factual claim by another account.
abstract interface class ClaimAnalyticsReceiptStore {
  bool contains(String receiptId);
  void record(String receiptId);
}

String claimAnalyticsReceiptId({
  required String guestId,
  required int assessmentId,
  required String userId,
}) {
  final contractIdentity = analyticsDeduplicationKey('result_claimed', {
    'guest_id': guestId,
    'assessment_id': assessmentId,
    'user_id': userId,
    'claim_outcome': 'receipt_identity_only',
  });
  if (contractIdentity == null) {
    throw StateError('result_claimed requires a stable dedupe identity');
  }
  return sha256
      .convert(utf8.encode('$contractIdentity|user_id=$userId'))
      .toString();
}

List<String> decodeClaimAnalyticsReceiptStorage(String? raw) {
  if (raw == null) return const <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['version'] != 1 ||
        decoded['receipts'] is! List<dynamic>) {
      return const <String>[];
    }
    final receipts = decoded['receipts'] as List<dynamic>;
    if (receipts.length > maxClaimAnalyticsReceipts ||
        receipts.any(
          (value) => value is! String || !_receiptPattern.hasMatch(value),
        )) {
      return const <String>[];
    }
    return List<String>.unmodifiable(receipts.cast<String>());
  } catch (_) {
    return const <String>[];
  }
}

String addClaimAnalyticsReceiptStorage(String? raw, String receiptId) {
  if (!_receiptPattern.hasMatch(receiptId)) {
    throw ArgumentError.value(
      receiptId,
      'receiptId',
      'must be a SHA-256 digest',
    );
  }
  final receipts = decodeClaimAnalyticsReceiptStorage(raw).toList()
    ..remove(receiptId)
    ..add(receiptId);
  final start = receipts.length > maxClaimAnalyticsReceipts
      ? receipts.length - maxClaimAnalyticsReceipts
      : 0;
  return jsonEncode({'version': 1, 'receipts': receipts.sublist(start)});
}

ClaimAnalyticsReceiptStore claimAnalyticsReceiptStore() =>
    createClaimAnalyticsReceiptStore();
