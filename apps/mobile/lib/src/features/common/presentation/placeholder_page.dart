import 'package:flutter/material.dart';

/// 후속 빌드에서 실제 화면으로 대체되는 임시 페이지(학습/커뮤니티 = Build C).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — 준비 중')),
    );
  }
}
