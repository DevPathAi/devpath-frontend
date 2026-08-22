import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/features/sandbox/state/sandbox_workspace_context.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

LearningContent _content({required String track, int id = 12}) =>
    LearningContent(
      id: id,
      slug: 'lesson',
      title: '현재 단원',
      track: track,
      markdown: '# lesson',
      progress: const ContentProgress(scrollPct: 0.4, dwellSec: 10),
    );

void main() {
  const key = MissionWorkspaceKey(taskId: 7, contentId: 12);

  test('명확한 콘텐츠 track은 JAVA/NODE/PYTHON runtime과 generic starter로 맞춘다', () {
    for (final entry in <String, SandboxLanguage>{
      'BACKEND_SPRING': SandboxLanguage.java,
      'FRONTEND_REACT': SandboxLanguage.node,
      'PYTHON_BACKEND': SandboxLanguage.python,
    }.entries) {
      final context = SandboxWorkspaceContext.resolve(
        workspaceKey: key,
        content: _content(track: entry.key),
        taskTitle: '오늘의 과제',
      );

      expect(context.language, entry.value);
      expect(context.starterCode, entry.value.genericStarter);
      expect(context.starterKind, SandboxStarterKind.generic);
      expect(context.starterLabel, contains('일반 템플릿'));
      expect(context.contentId, 12);
      expect(context.codeBlockId, isNull);
    }
  });

  test('지원/근거가 없는 track은 Java 실행으로 fallback하지 않는다', () {
    for (final track in ['MOBILE_FLUTTER', 'DEVOPS', 'FULLSTACK', 'UNKNOWN']) {
      final context = SandboxWorkspaceContext.resolve(
        workspaceKey: key,
        content: _content(track: track),
        taskTitle: '$track 과제',
      );

      expect(context.language, isNull);
      expect(context.starterCode, isNull);
      expect(
        context.starterKind,
        track == 'MOBILE_FLUTTER'
            ? SandboxStarterKind.unsupported
            : SandboxStarterKind.selectionRequired,
      );
      expect(context.starterLabel, isNot(contains('JAVA 일반 템플릿')));
    }
  });

  test('route content와 응답 content가 다르면 context를 만들지 않는다', () {
    expect(
      () => SandboxWorkspaceContext.resolve(
        workspaceKey: key,
        content: _content(track: 'BACKEND_SPRING', id: 99),
        taskTitle: '과제',
      ),
      throwsFormatException,
    );
  });
}
