import 'package:dp_core/dp_core.dart';

sealed class AdminAuthState {
  const AdminAuthState();
}

class AdminUnauthed extends AdminAuthState {
  const AdminUnauthed({this.error});
  final String? error;
}

class AdminAuthed extends AdminAuthState {
  const AdminAuthed(this.user);
  final User user;
  bool get isAdmin =>
      user.role == UserRole.admin || user.role == UserRole.owner;
}
