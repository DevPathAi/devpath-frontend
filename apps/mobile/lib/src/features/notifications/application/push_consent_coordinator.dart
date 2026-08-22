import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import 'device_registrar.dart';

/// Maps authoritative auth/consent states to the manual FCM lifecycle.
/// Loading is deliberately transparent so DONE -> Loading -> DONE does not
/// churn a valid registration, while a terminal non-DONE state always revokes
/// even on a cold process with an empty in-memory tracker.
class PushConsentCoordinator {
  PushConsentCoordinator(this._registrar);

  final DeviceRegistrar _registrar;
  String? _ownerKey;
  bool? _consented;
  bool _activatedOnline = false;
  final _operations = <Future<void>>{};

  void handle(AuthState auth) {
    switch (auth) {
      case AuthLoading():
        return;
      case AuthAuthenticated(:final user):
        _handleVerified(user, online: true);
        return;
      case AuthOfflineAuthenticated(:final user):
        _handleVerified(user, online: false);
        return;
      case AuthUnauthenticated() || AuthSessionUnavailable():
        // AuthController owns logout/401/account-switch revocation. Reset only
        // the dedupe memory so a later cold verified PENDING state is handled.
        _ownerKey = null;
        _consented = null;
        _activatedOnline = false;
        return;
    }
  }

  /// Manual auto-init mode explicitly retries token acquisition on resume.
  void resume(AuthState auth) {
    if (auth case AuthAuthenticated(:final user)) {
      if (user.consentStatus == ConsentStatus.done) {
        _run(
          () => _registrar.activate(user.id),
          onFailure: () {
            if (_ownerKey == user.id && _consented == true) {
              _activatedOnline = false;
            }
          },
        );
      } else {
        _run(
          () => _registrar.unregister(user.id, credentialOwnerConfirmed: true),
          onFailure: () {
            if (_ownerKey == user.id && _consented == false) {
              _consented = null;
            }
          },
        );
      }
    }
  }

  void _handleVerified(User user, {required bool online}) {
    final consented = user.consentStatus == ConsentStatus.done;
    final sameOwner = _ownerKey == user.id;
    if (!consented) {
      if (sameOwner && _consented == false) return;
      _ownerKey = user.id;
      _consented = false;
      _activatedOnline = false;
      _run(
        () => _registrar.unregister(user.id, credentialOwnerConfirmed: true),
        onFailure: () {
          if (_ownerKey == user.id && _consented == false) {
            _consented = null;
          }
        },
      );
      return;
    }

    if (!sameOwner) {
      _ownerKey = user.id;
      _activatedOnline = false;
    }
    _consented = true;
    if (!online || _activatedOnline) return;
    _activatedOnline = true;
    _run(
      () => _registrar.activate(user.id),
      onFailure: () {
        if (_ownerKey == user.id && _consented == true) {
          _activatedOnline = false;
        }
      },
    );
  }

  void _run(Future<void> Function() operation, {void Function()? onFailure}) {
    late final Future<void> tracked;
    tracked = Future<void>.sync(operation)
        .catchError((Object _) {
          onFailure?.call();
        })
        .whenComplete(() => _operations.remove(tracked));
    _operations.add(tracked);
  }

  Future<void> get settled async {
    while (_operations.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_operations));
    }
  }
}

final pushConsentCoordinatorProvider = Provider<PushConsentCoordinator>((ref) {
  final coordinator = PushConsentCoordinator(
    ref.watch(deviceRegistrarProvider),
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => coordinator.handle(next),
    fireImmediately: true,
  );
  return coordinator;
});
