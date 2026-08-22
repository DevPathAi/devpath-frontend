import 'dart:async';

import 'package:devpath_admin/src/features/support/application/support_controller.dart';
import 'package:devpath_admin/src/features/support/data/support_request.dart';
import 'package:devpath_admin/src/features/support/data/support_source.dart';
import 'package:devpath_admin/src/features/support/state/support_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loading and failed states retain exact status/type for retry',
    () async {
      final pending = Completer<List<SupportRequestRow>>();
      final container = ProviderContainer(
        overrides: [
          supportListFetchProvider.overrideWithValue(
            ({status, type, required limit}) => pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);

      final request = container
          .read(supportListProvider.notifier)
          .load(status: 'VENDOR_REVIEW', type: 'ERROR');
      final loading = container.read(supportListProvider);
      expect(loading.status, 'VENDOR_REVIEW');
      expect(loading.type, 'ERROR');

      pending.completeError(
        const ApiException(code: ApiErrorCode.unknown, message: '조회 실패'),
      );
      await request;
      final failed = container.read(supportListProvider);
      expect(failed, isA<SupportListFailed>());
      expect(failed.status, 'VENDOR_REVIEW');
      expect(failed.type, 'ERROR');
    },
  );
}
