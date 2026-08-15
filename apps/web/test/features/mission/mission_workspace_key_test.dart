import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissionWorkspaceKey', () {
    test('양수 JS-safe task/content ID와 canonical 경로를 보존한다', () {
      const key = MissionWorkspaceKey(
        taskId: 1,
        contentId: MissionWorkspaceKey.maxSafeInteger,
      );

      expect(key.taskId, 1);
      expect(key.contentId, MissionWorkspaceKey.maxSafeInteger);
      expect(
        key.contentLocation,
        '/mission/1/content/${MissionWorkspaceKey.maxSafeInteger}',
      );
      expect(key.sandboxLocation, '/mission/1/sandbox');
    });

    test('route 문자열은 양의 canonical 십진 정수만 허용한다', () {
      expect(MissionWorkspaceKey.tryParseTaskId('7'), 7);
      expect(
        MissionWorkspaceKey.tryParse(taskId: '7', contentId: '101'),
        const MissionWorkspaceKey(taskId: 7, contentId: 101),
      );

      for (final value in <String?>[
        null,
        '',
        '0',
        '-1',
        '+1',
        '01',
        '1.0',
        ' 1',
        '1 ',
        '9007199254740992',
      ]) {
        expect(
          MissionWorkspaceKey.tryParseTaskId(value),
          isNull,
          reason: 'invalid standalone taskId: $value',
        );
        expect(
          MissionWorkspaceKey.tryParse(taskId: value, contentId: '1'),
          isNull,
          reason: 'invalid taskId: $value',
        );
        expect(
          MissionWorkspaceKey.tryParse(taskId: '1', contentId: value),
          isNull,
          reason: 'invalid contentId: $value',
        );
      }
    });

    test('parse factory는 유효한 key를 만들고 잘못된 route를 명시적으로 거부한다', () {
      expect(
        MissionWorkspaceKey.parse(taskId: '7', contentId: '101'),
        const MissionWorkspaceKey(taskId: 7, contentId: 101),
      );
      expect(
        () => MissionWorkspaceKey.parse(taskId: '0', contentId: '101'),
        throwsFormatException,
      );
    });

    test('값 동등성과 hashCode는 task/content 쌍을 함께 사용한다', () {
      const first = MissionWorkspaceKey(taskId: 7, contentId: 101);
      const same = MissionWorkspaceKey(taskId: 7, contentId: 101);

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(
        first,
        isNot(const MissionWorkspaceKey(taskId: 8, contentId: 101)),
      );
      expect(
        first,
        isNot(const MissionWorkspaceKey(taskId: 7, contentId: 102)),
      );
    });

    test('직접 생성도 0·음수·JS-safe 경계 초과를 거부한다', () {
      expect(
        () => MissionWorkspaceKey(taskId: 0, contentId: 1),
        throwsAssertionError,
      );
      expect(
        () => MissionWorkspaceKey(taskId: 1, contentId: -1),
        throwsAssertionError,
      );
      expect(
        () => MissionWorkspaceKey(
          taskId: MissionWorkspaceKey.maxSafeInteger + 1,
          contentId: 1,
        ),
        throwsAssertionError,
      );
    });
  });
}
