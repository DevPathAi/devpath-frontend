import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/content_state.dart';

class ContentController extends Notifier<ContentState> {
  @override
  ContentState build() => const ContentLoading();

  Future<void> load(String id) async {
    state = const ContentLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$id');
      state = ContentLoaded(json['markdown'] as String);
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
    }
  }
}

final contentControllerProvider =
    NotifierProvider<ContentController, ContentState>(ContentController.new);
