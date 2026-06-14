import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 단일 아이콘셋(Material Symbols). 와이어프레임 이모지(🏠🗺💬👥🔔 등) 대체(DD3).
abstract final class DpIcons {
  // 하단탭 / 내비
  static const IconData home = Symbols.home_rounded;
  static const IconData path = Symbols.map_rounded;
  static const IconData mentor = Symbols.chat_rounded;
  static const IconData community = Symbols.groups_rounded;
  static const IconData notifications = Symbols.notifications_rounded;
  static const IconData dashboard = Symbols.dashboard_rounded;
  static const IconData content = Symbols.menu_book_rounded;

  // 상태
  static const IconData killSwitch = Symbols.build_rounded;     // 점검 중
  static const IconData quota = Symbols.hourglass_top_rounded;  // 한도
  static const IconData offline = Symbols.cloud_off_rounded;
  static const IconData sandboxOff = Symbols.code_off_rounded;
  static const IconData empty = Symbols.inbox_rounded;
  static const IconData error = Symbols.error_rounded;
  static const IconData retry = Symbols.refresh_rounded;

  // SSE 단계 표시(P3-C — Material Icons 대신 단일 Symbols 셋 유지, DD3)
  static const IconData stepDone = Symbols.check_circle_rounded;
  static const IconData stepCurrent = Symbols.radio_button_checked_rounded;
  static const IconData stepPending = Symbols.radio_button_unchecked_rounded;

  // 코드/Sandbox(P4c-B — DD3 단일 Symbols 셋)
  static const IconData code = Symbols.code_rounded;
  static const IconData expandMore = Symbols.expand_more_rounded;
  static const IconData expandLess = Symbols.expand_less_rounded;

  // 리뷰/멘토/커뮤니티(P4d/e/f — DD3 단일 Symbols 셋)
  static const IconData dotSmall = Symbols.fiber_manual_record_rounded; // 심각도 점
  static const IconData thumbUp = Symbols.thumb_up_rounded;
  static const IconData thumbDown = Symbols.thumb_down_rounded;
  static const IconData send = Symbols.send_rounded;
  static const IconData edit = Symbols.edit_rounded;

  // mobile(P6 — DD3 단일 Symbols 셋). offline은 위 상태 섹션 재사용.
  static const IconData downloadDone = Symbols.download_done_rounded;
}
