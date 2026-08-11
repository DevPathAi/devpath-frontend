import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_report.freezed.dart';
part 'community_report.g.dart';

/// 신고 사유. [wire] 는 서버 enum 값, [label] 은 화면 표기다.
///
/// 둘을 한 곳에 묶어 둔다 — 흩어지면 서버 CHECK 제약
/// (`chk_community_reports_category`)과 어긋나도 컴파일이 통과해 런타임 400 으로만 드러난다.
enum CommunityReportCategory {
  spam('SPAM', '스팸'),
  abuse('ABUSE', '욕설'),
  ad('AD', '광고'),
  duplicate('DUPLICATE', '중복'),
  inappropriate('INAPPROPRIATE', '부적절'),
  etc('ETC', '기타');

  const CommunityReportCategory(this.wire, this.label);

  /// 서버로 보내는 값.
  final String wire;

  /// 사용자에게 보이는 이름.
  final String label;
}

/// 신고 접수 결과(`POST /community/reports`).
@freezed
abstract class CommunityReportResult with _$CommunityReportResult {
  const factory CommunityReportResult({
    @Default(0) int id,
    @Default('OPEN') String status,
  }) = _CommunityReportResult;

  factory CommunityReportResult.fromJson(Map<String, dynamic> json) =>
      _$CommunityReportResultFromJson(json);
}
