import 'package:dp_core/dp_core.dart';

sealed class DiagnosticState {
  const DiagnosticState();
}

class DiagnosticIdle extends DiagnosticState {
  const DiagnosticIdle();
}

class DiagnosticLoading extends DiagnosticState {
  const DiagnosticLoading();
}

class DiagnosticQuestion extends DiagnosticState {
  const DiagnosticQuestion(this.next);
  final NextQuestion next;
}

class DiagnosticGateSignup extends DiagnosticState {
  const DiagnosticGateSignup();
}

class DiagnosticResultState extends DiagnosticState {
  const DiagnosticResultState(this.result);
  final AssessmentResult result;
}

class DiagnosticError extends DiagnosticState {
  const DiagnosticError(this.message);
  final String message;
}
