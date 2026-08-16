import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../services/connectivity_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../today/application/today_controller.dart';
import '../data/content_offline_store.dart';

/// Owns the durable progress outbox. It is activated at app scope so queued
/// progress drains after reconnect even when the content route was closed.
class ContentProgressSyncController extends Notifier<int> {
  final _flights = <String, Future<ContentProgressUpdateResponse?>>{};

  @override
  int build() {
    ref.listen(connectivityProvider, (previous, next) {
      final wasOnline = switch (previous) {
        AsyncData(:final value) => value,
        _ => null,
      };
      final isNowOnline = switch (next) {
        AsyncData(:final value) => value,
        _ => null,
      };
      if (isNowOnline == true && wasOnline != true) {
        final owner = ref.read(currentOwnerKeyProvider);
        if (owner != null) unawaited(syncOwner(owner));
      }
    });
    ref.listen(currentOwnerKeyProvider, (_, owner) {
      if (owner != null) unawaited(syncOwner(owner));
    });
    return 0;
  }

  Future<ContentProgressUpdateResponse?> enqueueAndSync(
    QueuedContentProgress progress,
  ) async {
    await ref.read(contentProgressQueueProvider).enqueue(progress);
    return syncRoute(progress.ownerKey, progress.routeKey);
  }

  Future<void> syncOwner(String ownerKey) async {
    final pending = await ref.read(contentProgressQueueProvider).list(ownerKey);
    await Future.wait(
      pending.map((item) => syncRoute(ownerKey, item.routeKey)),
    );
  }

  Future<ContentProgressUpdateResponse?> syncRoute(
    String ownerKey,
    String routeKey,
  ) {
    final key = '$ownerKey\u0000$routeKey';
    final active = _flights[key];
    if (active != null) {
      return active.then((response) async {
        if (!ref.mounted || ref.read(currentOwnerKeyProvider) != ownerKey) {
          return response;
        }
        final pending = await ref
            .read(contentProgressQueueProvider)
            .read(ownerKey, routeKey);
        if (pending == null) return response;
        final tail = await syncRoute(ownerKey, routeKey);
        return tail ?? response;
      });
    }
    late final Future<ContentProgressUpdateResponse?> tracked;
    tracked = _drainRoute(ownerKey, routeKey).whenComplete(() {
      if (identical(_flights[key], tracked)) _flights.remove(key);
    });
    _flights[key] = tracked;
    return tracked;
  }

  Future<ContentProgressUpdateResponse?> _drainRoute(
    String ownerKey,
    String routeKey,
  ) async {
    ContentProgressUpdateResponse? latestResponse;
    while (ref.mounted && ref.read(currentOwnerKeyProvider) == ownerKey) {
      final pending = await ref
          .read(contentProgressQueueProvider)
          .read(ownerKey, routeKey);
      if (pending == null) return latestResponse;
      try {
        final json = await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>(
              '/contents/$routeKey/progress',
              body: {
                'scrollPct': pending.scrollPct,
                'dwellSec': pending.dwellSec,
              },
            );
        final response = ContentProgressUpdateResponse.fromJson(json);
        if (!ref.mounted || ref.read(currentOwnerKeyProvider) != ownerKey) {
          return latestResponse;
        }
        latestResponse = response;
        await ref
            .read(contentOfflineStoreProvider)
            .applyServerProgress(ownerKey, routeKey, response);
        await ref.read(contentProgressQueueProvider).acknowledge(pending);
        state += 1;
        if (response.completed) {
          if (ref.exists(todayControllerProvider)) {
            unawaited(
              ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
            );
          } else {
            ref.invalidate(todayControllerProvider);
          }
        }
      } on ApiException catch (error) {
        if (_isUnauthorized(error)) {
          await ref
              .read(contentProgressQueueProvider)
              .remove(ownerKey, routeKey);
          if (ref.mounted) {
            await ref
                .read(authControllerProvider.notifier)
                .invalidateUnauthorized(error.message);
          }
        } else if (_isPermanentClientError(error)) {
          await ref
              .read(contentProgressQueueProvider)
              .remove(ownerKey, routeKey);
          if (ref.mounted) state += 1;
        }
        // Transport, throttling and 5xx retain the durable row for reconnect.
        return latestResponse;
      } on FormatException {
        await ref.read(contentProgressQueueProvider).remove(ownerKey, routeKey);
        if (ref.mounted) state += 1;
        return latestResponse;
      } on TypeError {
        await ref.read(contentProgressQueueProvider).remove(ownerKey, routeKey);
        if (ref.mounted) state += 1;
        return latestResponse;
      } on Object {
        // Non-HTTP transport/platform failures remain retryable.
        return latestResponse;
      }
    }
    return latestResponse;
  }

  bool _isUnauthorized(ApiException error) =>
      error.status == 401 || error.code == ApiErrorCode.unauthorized;

  bool _isPermanentClientError(ApiException error) {
    final status = error.status;
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 401 &&
        status != 408 &&
        status != 425 &&
        status != 429;
  }
}

final contentProgressSyncControllerProvider =
    NotifierProvider<ContentProgressSyncController, int>(
      ContentProgressSyncController.new,
    );
