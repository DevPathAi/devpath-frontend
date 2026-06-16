class Report {
  const Report({
    required this.id,
    required this.type,
    required this.targetTitle,
    required this.reason,
    required this.status, // OPEN | RESOLVED
  });
  final String id;
  final String type;
  final String targetTitle;
  final String reason;
  final String status;

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] as String,
    type: json['type'] as String,
    targetTitle: json['targetTitle'] as String,
    reason: json['reason'] as String,
    status: (json['status'] as String?) ?? 'OPEN',
  );
}
