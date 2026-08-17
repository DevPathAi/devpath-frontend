import 'dart:async';

import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_workspace_retention.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_scope_key.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const a = MentorScopeKey(
  ownerId: 'owner-a',
  workspaceKey: MissionWorkspaceKey(taskId: 1, contentId: 11),
);
const b = MentorScopeKey(
  ownerId: 'owner-a',
  workspaceKey: MissionWorkspaceKey(taskId: 2, contentId: 22),
);
const c = MentorScopeKey(
  ownerId: 'owner-b',
  workspaceKey: MissionWorkspaceKey(taskId: 3, contentId: 33),
);

void main() {
  test('A→B→A를 유지하고 세 번째 scope는 가장 오래된 상태를 폐기한다', () {
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('owner-a'),
        for (final scope in [a, b, c])
          mentorContextEvidenceProvider(
            scope,
          ).overrideWithValue(const MentorContextEvidence(currentCode: 'code')),
      ],
    );
    addTearDown(container.dispose);
    final retention = container.read(mentorWorkspaceRetentionProvider.notifier);

    for (final scope in [a, b]) {
      container
          .read(contextualMentorControllerProvider(scope).notifier)
          .initializeContext(includeCurrentCode: true);
      retention.touch(scope);
    }
    retention.touch(a);
    expect(
      container
          .read(contextualMentorControllerProvider(a))
          .selectedContextFields,
      contains('current_code'),
    );

    retention.touch(c);

    expect(container.read(mentorWorkspaceRetentionProvider), [a, c]);
    expect(
      container.read(contextualMentorControllerProvider(b)).contextOptions,
      isEmpty,
    );
  });

  test('evicted scope의 late draft는 같은 key의 새 상태를 바꾸지 않는다', () async {
    final completer = Completer<LcsDraft>();
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWithValue('owner-a'),
        mentorScopeValidatorProvider(a).overrideWithValue(() => true),
        mentorContextEvidenceProvider(
          a,
        ).overrideWithValue(const MentorContextEvidence(currentCode: 'code')),
        mentorLcsDraftProvider.overrideWithValue(
          ({
            int? contentId,
            required List<String> requestedFields,
            required Map<String, Object?> requestContext,
          }) => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final retention = container.read(mentorWorkspaceRetentionProvider.notifier);
    final controller = container.read(
      contextualMentorControllerProvider(a).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    retention.touch(a);
    final pending = controller.preparePreview('late question');

    retention.touch(b);
    retention.touch(c);
    completer.complete(
      LcsDraft(
        draftId: 'late-draft',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        content: const {'current_content': 'late'},
        fieldsAvailable: const ['current_content'],
      ),
    );
    await pending;

    expect(
      container.read(contextualMentorControllerProvider(a)).contextPreview,
      isNull,
    );
  });
}
