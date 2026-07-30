import 'package:flutter/widgets.dart';

/// 명령 팔레트 항목. [onInvoke]는 선택 시 실행(라우팅·액션은 앱이 주입).
typedef DpCommand = ({
  String id,
  String label,
  IconData icon,
  VoidCallback onInvoke,
});
