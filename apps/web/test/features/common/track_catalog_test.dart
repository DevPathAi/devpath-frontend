import 'package:devpath_web/src/features/common/application/track_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카탈로그는 「트랙을 늘릴 때 이 파일 한 곳만 고치면 된다」고 약속한다.
/// 그 약속을 지키려면 **무엇이 들어 있는지**가 고정돼 있어야 한다.
///
/// 다른 테스트는 `DEVOPS` 하나(단위)와 `백엔드 (Spring)` 하나(골든패스)만 만지므로,
/// 카탈로그에서 `MOBILE_FLUTTER` 나 `FULLSTACK` 을 지워도 전 스위트가 green 이다.
/// 키는 서버 CHECK 제약(`assessments.track` 등 5곳)과 같은 값이라 조용히 줄면
/// 이용자가 고를 수 있는 트랙만 사라진다 — 여기서 계약으로 잠근다.
void main() {
  test('카탈로그는 8트랙을 정확히 이 순서로 낸다', () {
    expect(trackLabels.keys, [
      'BACKEND_SPRING',
      'FRONTEND_REACT',
      'MOBILE_FLUTTER',
      'DEVOPS',
      'FULLSTACK',
      'PYTHON_BACKEND',
      'NODE_TYPESCRIPT',
      'DATA_AI',
    ]);
  });
}
