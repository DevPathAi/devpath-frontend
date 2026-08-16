/// Admin-owned display contract for server status values.
///
/// The wire value is never translated or normalized. Known values gain a Korean
/// label, while unknown values stay visible so operators can report contract
/// drift without losing the evidence that arrived from the API.
enum AdminStatusDomain { user, report, support, ad }

class AdminStatusDescriptor {
  const AdminStatusDescriptor({
    required this.wire,
    required this.label,
    this.isKnown = true,
  });

  final String wire;
  final String label;
  final bool isKnown;

  String get displayLabel => '$label ($wire)';
}

abstract final class AdminStatusCatalog {
  static const _users = <AdminStatusDescriptor>[
    AdminStatusDescriptor(wire: 'BETA_PENDING', label: '승인 대기'),
    AdminStatusDescriptor(wire: 'ACTIVE', label: '활성'),
    AdminStatusDescriptor(wire: 'WARNED', label: '경고'),
    AdminStatusDescriptor(wire: 'SUSPENDED', label: '이용 정지'),
    AdminStatusDescriptor(wire: 'BANNED', label: '영구 정지'),
  ];

  static const _reports = <AdminStatusDescriptor>[
    AdminStatusDescriptor(wire: 'OPEN', label: '미처리'),
    AdminStatusDescriptor(wire: 'RESOLVED', label: '처리됨'),
    AdminStatusDescriptor(wire: 'REJECTED', label: '기각됨'),
  ];

  static const _support = <AdminStatusDescriptor>[
    AdminStatusDescriptor(wire: 'OPEN', label: '접수됨'),
    AdminStatusDescriptor(wire: 'IN_PROGRESS', label: '처리 중'),
    AdminStatusDescriptor(wire: 'RESOLVED', label: '처리됨'),
    AdminStatusDescriptor(wire: 'WONTFIX', label: '보류'),
  ];

  static const _ads = <AdminStatusDescriptor>[
    AdminStatusDescriptor(wire: 'ACTIVE', label: '노출 중'),
    AdminStatusDescriptor(wire: 'PAUSED', label: '일시 중지'),
  ];

  static List<AdminStatusDescriptor> values(AdminStatusDomain domain) =>
      switch (domain) {
        AdminStatusDomain.user => _users,
        AdminStatusDomain.report => _reports,
        AdminStatusDomain.support => _support,
        AdminStatusDomain.ad => _ads,
      };

  static AdminStatusDescriptor resolve(AdminStatusDomain domain, String wire) {
    for (final status in values(domain)) {
      if (status.wire == wire) return status;
    }
    return AdminStatusDescriptor(
      wire: wire,
      label: '알 수 없는 상태',
      isKnown: false,
    );
  }

  static bool isKnown(AdminStatusDomain domain, String wire) =>
      resolve(domain, wire).isKnown;
}
