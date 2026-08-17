import 'package:devpath_web/src/features/diagnostic/application/claim_analytics_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persisted receipt는 contract identity와 user scope를 raw ID 없이 hash한다',
    () {
      final first = claimAnalyticsReceiptId(
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        assessmentId: 77,
        userId: '101',
      );
      final same = claimAnalyticsReceiptId(
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        assessmentId: 77,
        userId: '101',
      );
      final otherUser = claimAnalyticsReceiptId(
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        assessmentId: 77,
        userId: '202',
      );

      expect(first, same);
      expect(first, isNot(otherUser));
      expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(first, isNot(contains('123e4567')));
      expect(first, isNot(contains('101')));
    },
  );

  test('same-tab receipt JSON은 손상 입력을 버리고 최근 항목만 bounded 보존한다', () {
    String? raw = '{broken';
    for (
      var assessmentId = 1;
      assessmentId <= maxClaimAnalyticsReceipts + 5;
      assessmentId++
    ) {
      raw = addClaimAnalyticsReceiptStorage(
        raw,
        claimAnalyticsReceiptId(
          guestId: '123e4567-e89b-42d3-a456-426614174000',
          assessmentId: assessmentId,
          userId: '101',
        ),
      );
    }

    final receipts = decodeClaimAnalyticsReceiptStorage(raw);
    expect(receipts, hasLength(maxClaimAnalyticsReceipts));
    expect(
      receipts,
      isNot(
        contains(
          claimAnalyticsReceiptId(
            guestId: '123e4567-e89b-42d3-a456-426614174000',
            assessmentId: 1,
            userId: '101',
          ),
        ),
      ),
    );
    expect(
      receipts.last,
      claimAnalyticsReceiptId(
        guestId: '123e4567-e89b-42d3-a456-426614174000',
        assessmentId: maxClaimAnalyticsReceipts + 5,
        userId: '101',
      ),
    );
  });
}
