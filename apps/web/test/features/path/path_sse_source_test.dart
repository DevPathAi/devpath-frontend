import 'dart:convert';

import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 stage 이벤트를 처음부터 emit한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final connect = container.read(pathSseConnectProvider);
    final stages = await connect()
        .map((e) => (jsonDecode(e.data) as Map)['stage'] as String)
        .toList();

    expect(stages, ['collecting', 'generating', 'matching', 'done']);
  });
}
