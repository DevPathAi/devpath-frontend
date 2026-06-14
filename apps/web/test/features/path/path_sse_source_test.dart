import 'dart:convert';

import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 fromStep부터 단계를 emit한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final connect = container.read(pathSseConnectProvider);
    final steps = await connect(
      fromStep: 2,
    ).map((e) => (jsonDecode(e.data) as Map)['step'] as String).toList();

    expect(steps, ['BUILD', 'DONE']); // kSseSteps[2..] = BUILD, DONE
  });
}
