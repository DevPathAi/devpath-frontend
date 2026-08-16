import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serializes every durable credential mutation in one provider-owned tail.
///
/// [invalidate] is synchronous so in-flight requests observe a replacement
/// boundary even when an older secure-storage write is still completing. The
/// queued replacement then deterministically becomes the final credential.
class CredentialMutationCoordinator {
  Future<void> _tail = Future<void>.value();
  var _generation = 0;

  int get generation => _generation;

  void invalidate() {
    _generation += 1;
  }

  Future<T> run<T>(Future<T> Function() mutation) {
    final operation = _tail.then((_) => mutation());
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}

final credentialMutationCoordinatorProvider =
    Provider<CredentialMutationCoordinator>(
      (ref) => CredentialMutationCoordinator(),
    );
