import 'dart:async';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

void main() {
  // 관리 화면은 코드 폰트를 여러 곳에서 직접 쓰므로 시작 시 바로 등록한다.
  unawaited(DpCodeFont.ensureLoaded());
  runApp(const ProviderScope(child: DevPathAdminApp()));
}
