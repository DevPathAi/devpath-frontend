import 'package:dp_core/dp_core.dart';

/// admin 사용자 목록 행(표시 전용 DTO).
class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.nickname,
    required this.email,
    required this.role,
    required this.status, // ACTIVE | WARNED | SUSPENDED | BANNED
  });

  final String id;
  final String nickname;
  final String email;
  final UserRole role;
  final String status;

  factory AdminUserRow.fromJson(Map<String, dynamic> json) => AdminUserRow(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        email: json['email'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name.toUpperCase() == (json['role'] as String?),
          orElse: () => UserRole.unknown,
        ),
        status: (json['status'] as String?) ?? 'ACTIVE',
      );
}
