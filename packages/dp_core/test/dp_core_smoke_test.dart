import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('공개 API가 barrel로 노출된다', () {
    expect(dpCoreVersion, '0.0.1');
    expect(ApiErrorCode.fromWire('CONFLICT'), ApiErrorCode.conflict);
    const cfg = ApiConfig(baseUrl: 'https://x/api/v1', useMock: true);
    expect(cfg.useMock, isTrue);
  });
}
