import 'package:flutter/widgets.dart';

/// 크롬바 우측 액션 **데이터**.
///
/// Widget이 아니라 데이터인 이유: 폭이 모자라면 오버플로 메뉴 항목으로
/// 옮겨 그려야 하는데, Widget으로 받으면 라벨을 알 수 없어 메뉴에
/// 무엇을 표시할지 정할 수 없다.
class DpChromeAction {
  const DpChromeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// 바에서는 tooltip, 오버플로 메뉴에서는 항목 텍스트로 쓰인다.
  final String label;

  /// DpChromeBar가 자기 context를 넘긴다.
  ///
  /// VoidCallback이 아닌 이유: web의 오류 신고 액션이
  /// showSupportDialog(context)를 호출하는데, 액션을 데이터로 바꾸면
  /// 앱 쪽엔 다이얼로그를 띄울 수 있는 context가 없다. 호출부가 전역
  /// context를 잡게 두느니 컴포넌트가 넘겨주는 편이 안전하다.
  final void Function(BuildContext context) onPressed;
}
