import 'dart:async';

import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_scope_key.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspace = MissionWorkspaceKey(taskId: 31, contentId: 3);
const _scope = MentorScopeKey(ownerId: '73', workspaceKey: _workspace);

final _ownerProvider = NotifierProvider<_OwnerController, String>(
  _OwnerController.new,
);

final class _OwnerController extends Notifier<String> {
  @override
  String build() => '73';

  void switchTo(String owner) => state = owner;
}

SandboxSession _session({
  String stderr = 'StateError\n',
  bool truncated = false,
}) => SandboxSession(
  sessionId: 91,
  language: SandboxLanguage.java,
  contentId: 3,
  codeBlockId: null,
  stdout: 'before\nok\n',
  stderr: stderr,
  exitCode: stderr.isEmpty ? 0 : 1,
  status: stderr.isEmpty
      ? SandboxSessionStatus.completed
      : SandboxSessionStatus.failed,
  truncated: truncated,
  startedAt: DateTime.utc(2026, 8, 16),
  finishedAt: DateTime.utc(2026, 8, 16, 0, 0, 1),
);

const _review = CodeReview(
  confidence: 84,
  strengths: ['예외 경로가 명확해요'],
  improvements: [
    ReviewIssue(message: '복구 경로를 분리하세요', line: 7, severity: 'warning'),
  ],
  security: [ReviewIssue(message: '원문 로그를 노출하지 마세요', severity: 'error')],
);

LcsDraft _draft(
  String id, {
  DateTime? expiresAt,
  List<String> fields = const ['current_content'],
}) => LcsDraft(
  draftId: id,
  expiresAt: expiresAt ?? DateTime.utc(2026, 8, 16, 12, 10),
  content: {for (final field in fields) field: 'preview:$field'},
  fieldsAvailable: fields,
);

final class _Harness {
  _Harness({
    this.partialFirst = false,
    this.eofFirst = false,
    this.busyFirst = false,
    this.scopeValid = true,
    DateTime? now,
    MentorContextEvidence? evidence,
    this.draftCompleter,
    this.mentorStream,
    this.secondaryScope,
  }) : now = now ?? DateTime.utc(2026, 8, 16, 12),
       evidence =
           evidence ??
           MentorContextEvidence(
             currentCode: 'throw StateError();',
             session: _session(),
             review: _review,
           ) {
    container = ProviderContainer(
      overrides: [
        mentorClockProvider.overrideWithValue(() => this.now),
        mentorScopeValidatorProvider(
          _scope,
        ).overrideWithValue(() => scopeValid),
        mentorContextEvidenceProvider(
          _scope,
        ).overrideWith((_) => this.evidence),
        if (secondaryScope != null)
          mentorScopeValidatorProvider(
            secondaryScope!,
          ).overrideWithValue(() => true),
        if (secondaryScope != null)
          mentorContextEvidenceProvider(
            secondaryScope!,
          ).overrideWithValue(const MentorContextEvidence()),
        mentorLcsDraftProvider.overrideWithValue(({
          int? contentId,
          required List<String> requestedFields,
          required Map<String, Object?> requestContext,
        }) async {
          draftCalls += 1;
          draftRequests.add((
            contentId: contentId,
            fields: List.unmodifiable(requestedFields),
            context: Map.unmodifiable(requestContext),
          ));
          if (draftCompleter != null && draftCalls == 1) {
            return draftCompleter!.future;
          }
          return draftFactory?.call(draftCalls) ??
              _draft('draft-$draftCalls', fields: requestedFields);
        }),
        mentorLcsCommitProvider.overrideWithValue(({required draftId}) async {
          commitCalls += 1;
          committedDrafts.add(draftId);
          return 70 + commitCalls;
        }),
        mentorContextualSseConnectProvider.overrideWithValue((
          question, {
          int? contentId,
          int? contextSnapshotId,
          int fromStep = 0,
        }) {
          sseCalls.add((question: question, snapshotId: contextSnapshotId));
          if (mentorStream != null) return mentorStream!.stream;
          if (partialFirst && sseCalls.length == 1) {
            return _partial();
          }
          if (eofFirst && sseCalls.length == 1) {
            return Stream.value(const SseEvent(event: 'token', data: '부분'));
          }
          if (busyFirst && sseCalls.length == 1) {
            return Stream.error(
              const ApiException(
                code: ApiErrorCode.mentorBusy,
                status: 429,
                message: 'mentor is busy; retry later',
              ),
            );
          }
          return _complete();
        }),
      ],
    );
  }

  late final ProviderContainer container;
  DateTime now;
  MentorContextEvidence evidence;
  final Completer<LcsDraft>? draftCompleter;
  final StreamController<SseEvent>? mentorStream;
  final MentorScopeKey? secondaryScope;
  bool scopeValid;
  bool partialFirst;
  bool eofFirst;
  bool busyFirst;
  int draftCalls = 0;
  int commitCalls = 0;
  final draftRequests =
      <({int? contentId, List<String> fields, Map<String, Object?> context})>[];
  final committedDrafts = <String>[];
  final sseCalls = <({String question, int? snapshotId})>[];
  LcsDraft Function(int call)? draftFactory;

  void dispose() => container.dispose();

  Stream<SseEvent> _partial() async* {
    yield const SseEvent(event: 'token', data: '부분');
    throw StateError('disconnect');
  }

  Stream<SseEvent> _complete() async* {
    yield const SseEvent(event: 'token', data: '도움');
    yield const SseEvent(event: 'terminal', data: '{"status":"DONE"}');
  }
}

void main() {
  test('editor CTA 기본값은 content/code만 ON, review/error/output은 OFF다', () {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );

    controller.initializeContext(includeCurrentCode: true);
    var state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.selectedContextFields, {'current_content', 'current_code'});
    expect(state.selectedContextFields, isNot(contains('review_summary')));
    expect(state.selectedContextFields, isNot(contains('recent_errors')));
    expect(state.selectedContextFields, isNot(contains('recent_output')));

    controller.toggleContextField('current_code');
    state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.selectedContextFields, isNot(contains('current_code')));
    expect(state.contextPreview, isNull);
  });

  test('Review CTA 기본값은 content/review만 ON이다', () {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );

    controller.initializeContext(
      includeCurrentCode: false,
      includeReviewSummary: true,
    );

    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      {'current_content', 'review_summary'},
    );
  });

  test('exact stderr가 비어 있으면 recent_errors는 unavailable이다', () {
    final h = _Harness(
      evidence: MentorContextEvidence(
        currentCode: 'print("ok");',
        session: _session(stderr: ''),
      ),
    );
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );

    controller.initializeContext(includeCurrentCode: true);

    final option = h.container
        .read(contextualMentorControllerProvider(_scope))
        .contextOptions
        .singleWhere((candidate) => candidate.id == 'recent_errors');
    expect(option.available, isFalse);
    expect(option.selected, isFalse);
    expect(option.unavailableReason, contains('오류'));
  });

  test('preview 직전 새로 완료된 exact review를 자동 선택하지 않는다', () async {
    final h = _Harness(
      evidence: const MentorContextEvidence(currentCode: 'code'),
    );
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      isNot(contains('review_summary')),
    );

    h.evidence = const MentorContextEvidence(
      currentCode: 'code',
      review: _review,
    );
    h.container.invalidate(mentorContextEvidenceProvider(_scope));
    await controller.preparePreview('리뷰 질문');

    expect(h.draftRequests.single.fields, isNot(contains('review_summary')));
  });

  test('draft는 현재 선택과 exact requestContext를 만들고 실제 preview를 보존한다', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    controller.toggleContextField('recent_output');
    controller.toggleContextField('recent_errors');

    await controller.preparePreview('왜 실패하나요?');

    final request = h.draftRequests.single;
    expect(request.contentId, 3);
    expect(request.fields, [
      'current_content',
      'current_code',
      'recent_errors',
      'recent_output',
    ]);
    expect(request.context, {
      'current_code': 'throw StateError();',
      'recent_errors': ['StateError'],
      'recent_output': {
        'stdout': 'before\nok\n',
        'stderr': 'StateError\n',
        'truncated': false,
      },
    });
    final state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.contextPhase, MentorContextPhase.previewReady);
    expect(state.contextPreview?.draftId, 'draft-1');
    expect(state.previewQuestion, '왜 실패하나요?');
  });

  test('commit ID를 Mentor에 넘기고 one-request 민감 opt-in을 끈다', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    controller.toggleContextField('recent_output');
    await controller.preparePreview('왜 실패하나요?');

    await controller.commitAndSend();

    expect(h.committedDrafts, ['draft-1']);
    expect(h.sseCalls, [(question: '왜 실패하나요?', snapshotId: 71)]);
    final state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.status, MentorStatus.idle);
    expect(state.messages.last.text, '도움');
    expect(state.messages.last.contextFields, [
      'current_content',
      'current_code',
      'recent_output',
    ]);
    expect(state.selectedContextFields, isNot(contains('current_code')));
    expect(state.selectedContextFields, isNot(contains('recent_output')));
    expect(state.selectedContextFields, isNot(contains('review_summary')));

    await controller.retry();
    expect(
      h.sseCalls,
      hasLength(1),
      reason: 'success clears same-send retry ID',
    );
  });

  test('빠른 이중 활성화도 같은 draft를 한 번만 commit/send한다', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    await controller.preparePreview('한 번만 보내세요');

    final first = controller.commitAndSend();
    final second = controller.commitAndSend();
    await Future.wait([first, second]);

    expect(h.commitCalls, 1);
    expect(h.sseCalls, hasLength(1));
  });

  test('새 Sandbox 진입만 code opt-in을 다시 켜고 직접 진입은 끈다', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    await controller.preparePreview('첫 질문');
    await controller.commitAndSend();
    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      isNot(contains('current_code')),
    );

    controller.initializeContext(includeCurrentCode: true);
    var state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.selectedContextFields, contains('current_code'));
    expect(state.contextPreview, isNull);

    controller.initializeContext(includeCurrentCode: false);
    state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.selectedContextFields, isNot(contains('current_code')));
  });

  test(
    'Review streaming 중 direct 재진입은 현재 send를 보존하고 다음 draft만 content-only다',
    () async {
      final stream = StreamController<SseEvent>();
      final h = _Harness(mentorStream: stream);
      addTearDown(() async {
        await stream.close();
        h.dispose();
      });
      final controller = h.container.read(
        contextualMentorControllerProvider(_scope).notifier,
      );
      controller.initializeContext(
        includeCurrentCode: false,
        includeReviewSummary: true,
      );
      await controller.preparePreview('리뷰 질문');

      final sending = controller.commitAndSend();
      await Future<void>.delayed(Duration.zero);
      final before = h.container.read(
        contextualMentorControllerProvider(_scope),
      );
      expect(before.status, MentorStatus.streaming);
      expect(before.selectedContextFields, {
        'current_content',
        'review_summary',
      });

      controller.initializeContext(
        includeCurrentCode: false,
        includeReviewSummary: false,
      );

      final during = h.container.read(
        contextualMentorControllerProvider(_scope),
      );
      expect(during.status, MentorStatus.streaming);
      expect(during.contextPreview?.draftId, before.contextPreview?.draftId);
      expect(during.committedSnapshotId, before.committedSnapshotId);
      expect(during.previewQuestion, before.previewQuestion);
      expect(during.messages, before.messages);
      expect(during.selectedContextFields, before.selectedContextFields);

      stream.add(const SseEvent(event: 'token', data: '답변'));
      stream.add(const SseEvent(event: 'terminal', data: '{"status":"DONE"}'));
      await sending;

      var state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.status, MentorStatus.idle);
      expect(state.messages.last.text, '답변');
      expect(state.selectedContextFields, {'current_content'});

      await controller.preparePreview('새 질문');
      expect(h.draftRequests[1].fields, ['current_content']);
      state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.contextPreview?.fieldsAvailable, ['current_content']);
    },
  );

  test('partial snapshot 재시도는 기존 ID를 쓰고 direct 재진입은 다음 draft에만 적용된다', () async {
    final h = _Harness(partialFirst: true);
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(
      includeCurrentCode: false,
      includeReviewSummary: true,
    );
    await controller.preparePreview('부분 질문');
    await controller.commitAndSend();

    final before = h.container.read(contextualMentorControllerProvider(_scope));
    expect(before.status, MentorStatus.partial);
    expect(before.committedSnapshotId, 71);

    controller.initializeContext(
      includeCurrentCode: false,
      includeReviewSummary: false,
    );
    final queued = h.container.read(contextualMentorControllerProvider(_scope));
    expect(queued.messages, before.messages);
    expect(queued.contextPreview?.draftId, before.contextPreview?.draftId);
    expect(queued.committedSnapshotId, 71);
    expect(queued.selectedContextFields, before.selectedContextFields);

    await controller.retry();
    expect(h.commitCalls, 1);
    expect(h.sseCalls.map((call) => call.snapshotId), [71, 71]);
    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      {'current_content'},
    );

    await controller.preparePreview('다음 질문');
    expect(h.draftRequests[1].fields, ['current_content']);
  });

  test(
    'editor draft pending 중 direct 재진입은 late preview를 바꾸지 않고 다음 draft의 code를 끈다',
    () async {
      final completer = Completer<LcsDraft>();
      final h = _Harness(draftCompleter: completer);
      addTearDown(h.dispose);
      final controller = h.container.read(
        contextualMentorControllerProvider(_scope).notifier,
      );
      controller.initializeContext(includeCurrentCode: true);

      final pending = controller.preparePreview('편집기 질문');
      await Future<void>.delayed(Duration.zero);
      expect(
        h.container
            .read(contextualMentorControllerProvider(_scope))
            .contextPhase,
        MentorContextPhase.loadingPreview,
      );

      controller.initializeContext(includeCurrentCode: false);
      final during = h.container.read(
        contextualMentorControllerProvider(_scope),
      );
      expect(during.contextPhase, MentorContextPhase.loadingPreview);
      expect(during.contextPreview, isNull);
      expect(during.selectedContextFields, {'current_content', 'current_code'});

      completer.complete(
        _draft(
          'late-editor',
          fields: const ['current_content', 'current_code'],
        ),
      );
      await pending;
      var state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.contextPreview?.draftId, 'late-editor');
      expect(state.selectedContextFields, {'current_content', 'current_code'});

      await controller.preparePreview('새 direct 질문');
      expect(h.draftRequests[1].fields, ['current_content']);
      state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.contextPreview?.fieldsAvailable, ['current_content']);
    },
  );

  test('partial retry는 같은 snapshot을 재사용하고 새 질문은 fresh draft다', () async {
    final h = _Harness(partialFirst: true);
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    await controller.preparePreview('첫 질문');
    await controller.commitAndSend();
    expect(
      h.container.read(contextualMentorControllerProvider(_scope)).status,
      MentorStatus.partial,
    );

    await controller.retry();

    expect(h.commitCalls, 1);
    expect(h.sseCalls.map((call) => call.snapshotId), [71, 71]);

    await controller.preparePreview('둘째 질문');
    expect(h.draftRequests[1].fields, isNot(contains('current_code')));
    await controller.retry();
    expect(
      h.sseCalls,
      hasLength(2),
      reason: 'starting a new question cannot reuse the previous snapshot',
    );
    await controller.commitAndSend();
    expect(h.draftCalls, 2);
    expect(h.commitCalls, 2);
    expect(h.sseCalls.last, (question: '둘째 질문', snapshotId: 72));
  });

  test(
    'new FE→old AI: snapshot 질문의 terminal 없는 EOF는 partial이며 retry ID를 보존한다',
    () async {
      final h = _Harness(eofFirst: true);
      addTearDown(h.dispose);
      final controller = h.container.read(
        contextualMentorControllerProvider(_scope).notifier,
      );
      controller.initializeContext(includeCurrentCode: false);
      await controller.preparePreview('EOF 질문');

      await controller.commitAndSend();

      var state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.status, MentorStatus.partial);
      expect(state.messages.last.text, '부분');
      expect(h.sseCalls.single.snapshotId, 71);

      await controller.retry();

      state = h.container.read(contextualMentorControllerProvider(_scope));
      expect(state.status, MentorStatus.idle);
      expect(state.messages.last.text, '도움');
      expect(h.commitCalls, 1);
      expect(h.sseCalls.map((call) => call.snapshotId), [71, 71]);
    },
  );

  test('snapshot 질문의 MENTOR_BUSY retry도 commit 없이 같은 ID를 재사용한다', () async {
    final h = _Harness(busyFirst: true);
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: false);
    await controller.preparePreview('busy 질문');

    await controller.commitAndSend();

    var state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.status, MentorStatus.busy);
    expect(state.error, contains('잠시 후'));
    expect(state.committedSnapshotId, 71);

    await controller.retry();

    state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.status, MentorStatus.idle);
    expect(h.commitCalls, 1);
    expect(h.sseCalls.map((call) => call.snapshotId), [71, 71]);
  });

  test('만료 preview는 commit하지 않고 retained preview에서 fresh retry한다', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.draftFactory = (call) => call == 1
        ? _draft('expired', expiresAt: DateTime.utc(2026, 8, 16, 11, 59))
        : _draft('fresh');
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: false);

    await controller.preparePreview('질문');
    var state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.contextPhase, MentorContextPhase.failed);
    expect(state.contextPreview?.draftId, isNot('expired'));
    expect(h.commitCalls, 0);

    await controller.preparePreview('질문');
    state = h.container.read(contextualMentorControllerProvider(_scope));
    expect(state.contextPreview?.draftId, 'fresh');
    await controller.commitAndSend();
    expect(h.commitCalls, 1);
  });

  test('scope mismatch와 late draft는 context/chat state를 오염시키지 않는다', () async {
    final completer = Completer<LcsDraft>();
    final h = _Harness(scopeValid: false, draftCompleter: completer);
    addTearDown(h.dispose);
    final controller = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    await controller.preparePreview('질문');
    expect(h.draftCalls, 0);
    expect(
      h.container.read(contextualMentorControllerProvider(_scope)).messages,
      isEmpty,
    );

    h.scopeValid = true;
    final pending = controller.preparePreview('늦은 질문');
    h.scopeValid = false;
    completer.complete(_draft('late'));
    await pending;
    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .contextPreview,
      isNull,
    );
  });

  test('A/B family state는 서로 격리된다', () async {
    const other = MentorScopeKey(
      ownerId: '73',
      workspaceKey: MissionWorkspaceKey(taskId: 32, contentId: 4),
    );
    final h = _Harness(secondaryScope: other);
    addTearDown(h.dispose);
    final a = h.container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    final b = h.container.read(
      contextualMentorControllerProvider(other).notifier,
    );
    a.initializeContext(includeCurrentCode: true);
    b.initializeContext(includeCurrentCode: false);

    expect(
      h.container
          .read(contextualMentorControllerProvider(_scope))
          .selectedContextFields,
      contains('current_code'),
    );
    expect(
      h.container
          .read(contextualMentorControllerProvider(other))
          .selectedContextFields,
      isNot(contains('current_code')),
    );
  });

  test('account switch는 pending draft를 무효화하고 새 owner state를 비운다', () async {
    final completer = Completer<LcsDraft>();
    var scopeValid = true;
    final container = ProviderContainer(
      overrides: [
        currentMissionOwnerKeyProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        mentorScopeValidatorProvider(
          _scope,
        ).overrideWithValue(() => scopeValid),
        mentorContextEvidenceProvider(_scope).overrideWithValue(
          const MentorContextEvidence(currentCode: 'owner-a-code'),
        ),
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
    final controller = container.read(
      contextualMentorControllerProvider(_scope).notifier,
    );
    controller.initializeContext(includeCurrentCode: true);
    final pending = controller.preparePreview('owner-a question');

    container.read(_ownerProvider.notifier).switchTo('other-owner');
    scopeValid = false;
    await Future<void>.delayed(Duration.zero);
    completer.complete(
      _draft('late-owner-a', fields: const ['current_content']),
    );
    await pending;

    final state = container.read(contextualMentorControllerProvider(_scope));
    expect(state.contextOptions, isEmpty);
    expect(state.contextPreview, isNull);
    expect(state.messages, isEmpty);
  });
}
