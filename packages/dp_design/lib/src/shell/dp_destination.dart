import 'package:flutter/widgets.dart';

/// 앱 셸 목적지(표현부 계약). 라우팅 비의존 — 경로 해석은 앱이 index로 처리.
/// [badgeCount] 0 = 배지 없음.
typedef DpDestination = ({IconData icon, String label, int badgeCount});
