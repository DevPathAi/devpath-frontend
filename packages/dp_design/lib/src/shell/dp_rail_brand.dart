import 'package:flutter/widgets.dart';

/// 레일 브랜드 **데이터**. 위젯이 아니다.
///
/// 앱이 TextStyle을 넘길 통로를 두지 않는 것이 이 타입의 존재 이유다.
/// DpTheme가 textTheme.apply(bodyColor: textPrimary)를 하므로 모든 타이포
/// 스케일이 non-null color를 품는다. 앱이 Text를 만들어 넘기면 그 색이
/// DefaultTextStyle.merge에서 이겨, 컴포넌트가 공급한 railText가 진다.
/// 라이트 팔레트는 textPrimary == railBg라 브랜드가 완전히 사라진다.
///
/// 위젯으로 만들지 않은 이유: extended를 전달할 경로가 필요해지고,
/// 그 경로가 다시 앱이 스타일을 실을 틈이 된다.
class DpRailBrand {
  const DpRailBrand({required this.mark, required this.wordmark});

  /// 접힘 상태에서도 남는 로고 마크.
  final Widget mark;

  /// 펼침 상태에서만 보이는 워드마크. String이므로 스타일을 실을 수 없다.
  final String wordmark;
}
