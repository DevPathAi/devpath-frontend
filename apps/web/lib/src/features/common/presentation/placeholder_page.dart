import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// P4b~P4d에서 실구현될 화면의 임시 자리(빈 상태 카피 규약 준수).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      DpEmpty(icon: icon, title: title, message: '곧 제공됩니다.');
}
