import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../state/sandbox_workspace_context.dart';

final class SandboxWorkspaceState {
  const SandboxWorkspaceState({
    this.context,
    this.language,
    required this.code,
    this.draftNotice,
    this.edited = false,
  });

  final SandboxWorkspaceContext? context;
  final SandboxLanguage? language;
  final String code;
  final String? draftNotice;
  final bool edited;

  SandboxWorkspaceState copyWith({
    SandboxWorkspaceContext? context,
    Object? language = _notProvided,
    String? code,
    String? draftNotice,
    bool clearDraftNotice = false,
    bool? edited,
  }) => SandboxWorkspaceState(
    context: context ?? this.context,
    language: identical(language, _notProvided)
        ? this.language
        : language as SandboxLanguage?,
    code: code ?? this.code,
    draftNotice: clearDraftNotice ? null : (draftNotice ?? this.draftNotice),
    edited: edited ?? this.edited,
  );
}

class SandboxWorkspaceController extends Notifier<SandboxWorkspaceState> {
  SandboxWorkspaceController(this.workspaceKey);

  final MissionWorkspaceKey? workspaceKey;
  String? _ownerKey;

  @override
  SandboxWorkspaceState build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
      if (nextOwner == _ownerKey) return;
      _ownerKey = nextOwner;
      state = _initialState();
    });
    return _initialState();
  }

  SandboxWorkspaceState _initialState() => SandboxWorkspaceState(
    language: workspaceKey == null ? SandboxLanguage.java : null,
    code: workspaceKey == null ? SandboxLanguage.java.genericStarter : '',
  );

  void configure(SandboxWorkspaceContext context) {
    if (context.workspaceKey != workspaceKey) {
      throw StateError('Sandbox context key mismatch');
    }
    if (state.context != null) return;
    state = SandboxWorkspaceState(
      context: context,
      language: context.language,
      code: context.starterCode ?? '',
    );
  }

  void updateCode(String code) {
    if (code == state.code) return;
    state = state.copyWith(code: code, edited: true, clearDraftNotice: true);
  }

  void selectLanguage(SandboxLanguage language) {
    if (state.context?.canSelectLanguage == false) return;
    if (language == state.language) return;
    final previousLanguage = state.language;
    final replaceGeneric =
        !state.edited ||
        (previousLanguage != null &&
            state.code == previousLanguage.genericStarter);
    state = state.copyWith(
      language: language,
      code: replaceGeneric ? language.genericStarter : state.code,
      edited: replaceGeneric ? false : true,
      draftNotice: replaceGeneric
          ? '${language.wireName} 일반 템플릿으로 바꿨어요.'
          : '실행 언어만 ${language.wireName}(으)로 바뀌었고 기존 편집 코드는 유지했어요.',
    );
  }
}

const _notProvided = Object();

final sandboxWorkspaceControllerProvider =
    NotifierProvider.family<
      SandboxWorkspaceController,
      SandboxWorkspaceState,
      MissionWorkspaceKey?
    >(SandboxWorkspaceController.new);
