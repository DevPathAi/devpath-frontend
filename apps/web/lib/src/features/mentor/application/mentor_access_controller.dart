import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mentor_access_source.dart';
import '../state/mentor_access_state.dart';

class MentorAccessController extends Notifier<MentorAccessState> {
  @override
  MentorAccessState build() => const MentorAccessLoading();

  Future<void> load() async {
    state = const MentorAccessLoading();
    try {
      final json = await ref.read(mentorAccessFetchProvider)();
      if (ref.mounted) state = MentorAccessReady.fromJson(json);
    } on ApiException catch (error) {
      if (ref.mounted) state = MentorAccessFailed(error.message);
    } catch (_) {
      if (ref.mounted) {
        state = const MentorAccessFailed('AI 멘토 초대 상태를 불러오지 못했어요.');
      }
    }
  }
}

final mentorAccessControllerProvider =
    NotifierProvider<MentorAccessController, MentorAccessState>(
      MentorAccessController.new,
    );
