import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/support_draft.dart';

/// 접수 제출. 실패를 삼키지 않고 [ApiException] 을 그대로 올린다 —
/// 다이얼로그가 사용자가 쓴 내용을 유지한 채 에러를 보여주고 재시도할 수 있어야 한다.
class SupportController extends Notifier<AsyncValue<int?>> {
  @override
  AsyncValue<int?> build() => const AsyncValue.data(null);

  /// 성공 시 접수 번호를 돌려준다.
  Future<int> submit(SupportDraft draft, SupportContext context) async {
    state = const AsyncValue.loading();
    try {
      final json = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/support/requests',
        body: {
          'type': draft.type,
          // 서버도 마스킹하지만 클라에서도 지운다 — 원문이 네트워크와 접근 로그를 지나지 않는다.
          'title': SensitiveTextMasker.mask(draft.title),
          'body': SensitiveTextMasker.mask(draft.body),
          'context': context.toJson(),
        },
      );
      final id = (json['id'] as num).toInt();
      state = AsyncValue.data(id);
      return id;
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final supportControllerProvider =
    NotifierProvider<SupportController, AsyncValue<int?>>(
      SupportController.new,
    );
