import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/owner_data_store.dart';

@immutable
final class QuickCaptureDraft {
  const QuickCaptureDraft({
    this.title = '',
    this.body = '',
    this.tags = const [],
  });

  final String title;
  final String body;
  final List<String> tags;

  bool get isEmpty => title.isEmpty && body.isEmpty && tags.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is QuickCaptureDraft &&
      other.title == title &&
      other.body == body &&
      listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(title, body, Object.hashAll(tags));
}

class QuickCaptureStore {
  QuickCaptureStore(this._data);

  static const bucket = 'quick-capture-draft-v1';
  static const key = 'question';
  final OwnerDataStore _data;
  final _mutationTails = <String, Future<void>>{};

  Future<QuickCaptureDraft?> read(String ownerKey) async {
    await (_mutationTails[ownerKey] ?? Future<void>.value());
    final row = await _data.read(ownerKey, bucket, key);
    if (row == null) return null;
    try {
      final json = jsonDecode(row.payload) as Map<String, dynamic>;
      return QuickCaptureDraft(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
    } on Object {
      await _data.deleteIfMatches(
        ownerKey,
        bucket,
        key,
        payload: row.payload,
        updatedAt: row.updatedAt,
      );
      return null;
    }
  }

  Future<void> write(
    String ownerKey,
    QuickCaptureDraft draft, {
    bool Function()? isCurrent,
  }) {
    if (draft.isEmpty) return clear(ownerKey, isCurrent: isCurrent);
    return _serialize(ownerKey, () async {
      if (isCurrent?.call() == false) return;
      await _data.write(
        ownerKey,
        bucket,
        key,
        jsonEncode({
          'title': draft.title,
          'body': draft.body,
          'tags': draft.tags,
        }),
      );
    });
  }

  Future<void> clear(String ownerKey, {bool Function()? isCurrent}) =>
      _serialize(ownerKey, () async {
        if (isCurrent?.call() == false) return;
        await _data.delete(ownerKey, bucket, key);
      });

  Future<T> _serialize<T>(String ownerKey, Future<T> Function() mutation) {
    final previous = _mutationTails[ownerKey] ?? Future<void>.value();
    final result = previous.then((_) => mutation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _mutationTails[ownerKey] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_mutationTails[ownerKey], tail)) {
          _mutationTails.remove(ownerKey);
        }
      }),
    );
    return result;
  }
}

final quickCaptureStoreProvider = Provider<QuickCaptureStore>(
  (ref) => QuickCaptureStore(ref.watch(ownerDataStoreProvider)),
);
