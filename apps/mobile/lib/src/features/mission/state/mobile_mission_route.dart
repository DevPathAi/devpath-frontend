/// Native companion routes accepted from App/Universal Links.
///
/// Sandbox, Review, and Mentor are intentionally absent: those workspaces stay
/// on web. IDs use the same canonical, JavaScript-safe contract as web routes.
final class MobileMissionRoute {
  const MobileMissionRoute._({
    required this.location,
    this.pathId,
    this.taskId,
    this.contentId,
  });

  static const int maxSafeInteger = 9007199254740991;

  final String location;
  final int? pathId;
  final int? taskId;
  final int? contentId;

  bool get isToday => pathId != null;
  bool get isContent => taskId != null && contentId != null;

  static MobileMissionRoute? tryParse(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null ||
        !location.startsWith('/') ||
        uri.scheme.isNotEmpty ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments;

    if (segments.length == 3 &&
        segments[0] == 'path' &&
        segments[2] == 'today') {
      final pathId = _parseId(segments[1]);
      if (pathId == null) return null;
      final canonical = '/path/$pathId/today';
      if (location != canonical) return null;
      return MobileMissionRoute._(location: canonical, pathId: pathId);
    }

    if (segments.length == 4 &&
        segments[0] == 'mission' &&
        segments[2] == 'content') {
      final taskId = _parseId(segments[1]);
      final contentId = _parseId(segments[3]);
      if (taskId == null || contentId == null) return null;
      final canonical = '/mission/$taskId/content/$contentId';
      if (location != canonical) return null;
      return MobileMissionRoute._(
        location: canonical,
        taskId: taskId,
        contentId: contentId,
      );
    }
    return null;
  }

  static MobileMissionRoute? tryParseUri(Uri uri) {
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
    if (uri.scheme.isEmpty) return tryParse(uri.toString());
    if (uri.scheme == 'https' &&
        uri.host == 'app.devpath.ai' &&
        (!uri.hasPort || uri.port == 443)) {
      return tryParse(uri.path);
    }
    if (uri.scheme == 'devpath' && uri.host == 'open') {
      return tryParse('/${uri.pathSegments.join('/')}');
    }
    return null;
  }

  static int? _parseId(String value) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value)) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed > maxSafeInteger) return null;
    return parsed;
  }
}
