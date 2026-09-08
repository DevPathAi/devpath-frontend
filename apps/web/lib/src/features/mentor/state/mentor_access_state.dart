sealed class MentorAccessState {
  const MentorAccessState();
}

class MentorAccessLoading extends MentorAccessState {
  const MentorAccessLoading();
}

class MentorAccessReady extends MentorAccessState {
  const MentorAccessReady({
    required this.status,
    required this.source,
    this.waitlistedAt,
    this.activatedAt,
  });

  final String status;
  final String source;
  final DateTime? waitlistedAt;
  final DateTime? activatedAt;

  bool get isActive => status == 'ACTIVE';

  factory MentorAccessReady.fromJson(Map<String, dynamic> json) =>
      MentorAccessReady(
        status: json['status'] as String,
        source: json['source'] as String,
        waitlistedAt: DateTime.tryParse(json['waitlistedAt'] as String? ?? ''),
        activatedAt: DateTime.tryParse(json['activatedAt'] as String? ?? ''),
      );
}

class MentorAccessFailed extends MentorAccessState {
  const MentorAccessFailed(this.message);
  final String message;
}
