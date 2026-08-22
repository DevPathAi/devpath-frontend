import 'package:dp_core/dp_core.dart';

import '../../mission/state/mission_workspace_key.dart';

enum SandboxStarterKind { generic, selectionRequired, unsupported }

/// A route-owned, non-persistent projection for the contextual Sandbox.
///
/// Learning content currently exposes a track but no task-specific starter or
/// code-block identity. The projection therefore chooses only an unambiguous
/// runtime and labels its starter as generic. It never rebrands Markdown sample
/// code as task-specific evidence.
final class SandboxWorkspaceContext {
  const SandboxWorkspaceContext._({
    required this.workspaceKey,
    required this.taskTitle,
    required this.contentTitle,
    required this.track,
    required this.language,
    required this.starterCode,
    required this.starterKind,
    required this.starterLabel,
  });

  final MissionWorkspaceKey workspaceKey;
  final String taskTitle;
  final String contentTitle;
  final String track;
  final SandboxLanguage? language;
  final String? starterCode;
  final SandboxStarterKind starterKind;
  final String starterLabel;

  int get contentId => workspaceKey.contentId;

  /// No current Learning Content response field owns this identifier.
  int? get codeBlockId => null;

  bool get canSelectLanguage => starterKind != SandboxStarterKind.unsupported;

  factory SandboxWorkspaceContext.resolve({
    required MissionWorkspaceKey workspaceKey,
    required LearningContent content,
    required String taskTitle,
  }) {
    if (content.id != workspaceKey.contentId) {
      throw const FormatException('Sandbox content identity mismatch');
    }
    final resolved = _runtimeForTrack(content.track);
    return SandboxWorkspaceContext._(
      workspaceKey: workspaceKey,
      taskTitle: taskTitle,
      contentTitle: content.title,
      track: content.track,
      language: resolved.language,
      starterCode: resolved.language?.genericStarter,
      starterKind: resolved.kind,
      starterLabel: resolved.label,
    );
  }

  static ({SandboxLanguage? language, SandboxStarterKind kind, String label})
  _runtimeForTrack(String track) {
    final normalized = track.trim().toUpperCase();
    return switch (normalized) {
      'BACKEND_SPRING' || 'JAVA' || 'JAVA_BACKEND' => (
        language: SandboxLanguage.java,
        kind: SandboxStarterKind.generic,
        label: '과제 전용 starter가 없어 JAVA 일반 템플릿을 사용합니다.',
      ),
      'FRONTEND_REACT' || 'NODE' || 'NODEJS' || 'JAVASCRIPT' => (
        language: SandboxLanguage.node,
        kind: SandboxStarterKind.generic,
        label: '과제 전용 starter가 없어 NODE 일반 템플릿을 사용합니다.',
      ),
      'PYTHON_BACKEND' || 'PYTHON' || 'PY' => (
        language: SandboxLanguage.python,
        kind: SandboxStarterKind.generic,
        label: '과제 전용 starter가 없어 PYTHON 일반 템플릿을 사용합니다.',
      ),
      'MOBILE_FLUTTER' => (
        language: null,
        kind: SandboxStarterKind.unsupported,
        label: '현재 Sandbox는 Flutter/Dart runtime을 지원하지 않습니다.',
      ),
      _ => (
        language: null,
        kind: SandboxStarterKind.selectionRequired,
        label: '콘텐츠만으로 실행 언어를 확정할 수 없습니다. 지원 runtime을 선택해 주세요.',
      ),
    };
  }
}
