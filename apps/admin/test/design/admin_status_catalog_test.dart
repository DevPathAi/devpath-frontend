import 'package:devpath_admin/src/design/admin_status_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminStatusCatalog', () {
    test('known status keeps its exact wire code beside the Korean label', () {
      final status = AdminStatusCatalog.resolve(
        AdminStatusDomain.user,
        'BETA_PENDING',
      );

      expect(status.wire, 'BETA_PENDING');
      expect(status.label, '승인 대기');
      expect(status.displayLabel, '승인 대기 (BETA_PENDING)');
      expect(status.isKnown, isTrue);
    });

    test('unknown status is explicit and never drops the server wire code', () {
      final status = AdminStatusCatalog.resolve(
        AdminStatusDomain.support,
        'ESCALATED_BY_VENDOR',
      );

      expect(status.label, '알 수 없는 상태');
      expect(status.wire, 'ESCALATED_BY_VENDOR');
      expect(status.displayLabel, '알 수 없는 상태 (ESCALATED_BY_VENDOR)');
      expect(status.isKnown, isFalse);
    });

    test('filter catalogs expose each exact wire value once', () {
      for (final domain in AdminStatusDomain.values) {
        final values = AdminStatusCatalog.values(domain).map((e) => e.wire);
        expect(values.toSet(), hasLength(values.length));
        expect(values, isNot(contains(isEmpty)));
      }
    });
  });
}
