import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mentor_access_source.dart';
import '../state/mentor_access_state.dart';

class MentorAccessController extends Notifier<MentorAccessState> {
  int _loadEpoch = 0;

  @override
  MentorAccessState build() => const MentorAccessLoading();

  Future<void> load() async {
    final epoch = ++_loadEpoch;
    state = const MentorAccessLoading();
    try {
      final json = await ref.read(mentorAccessFetchProvider)();
      if (ref.mounted && epoch == _loadEpoch) {
        state = MentorAccessReady.fromJson(json);
      }
    } on ApiException catch (error) {
      if (ref.mounted && epoch == _loadEpoch) {
        state = MentorAccessFailed(error.message);
      }
    } catch (_) {
      if (ref.mounted && epoch == _loadEpoch) {
        state = const MentorAccessFailed('AI 멘토 초대 상태를 불러오지 못했어요.');
      }
    }
  }
}

final mentorAccessControllerProvider =
    NotifierProvider<MentorAccessController, MentorAccessState>(
      MentorAccessController.new,
    );
