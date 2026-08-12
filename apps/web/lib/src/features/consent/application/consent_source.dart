import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../settings/data/settings_models.dart';

/// 동의 제출 항목: 백엔드 `ConsentType` 문자열(TERMS·PRIVACY·MARKETING·LCS_ATTACH·
/// ERROR_LOG) + 동의 여부.
typedef ConsentSubmitItem = ({String type, bool agreed});

/// platform `POST /consents` 배선. 동의 이력 + 생년(14세 검사)을 제출한다.
/// 만 14세 미만이면 서버가 400 VALIDATION_FAILED([ApiException])를 던진다.
class ConsentSource {
  ConsentSource(this._client);

  final ApiClient _client;

  Future<void> submit({
    required List<ConsentSubmitItem> items,
    required int birthYear,
  }) async {
    await _client.post<dynamic>(
      '/consents',
      body: {
        'consents': [
          for (final it in items) {'type': it.type, 'agreed': it.agreed},
        ],
        'birthYear': birthYear,
      },
    );
  }

  /// 동의 화면 진입 시 기존 동의 현황을 조회한다(재동의 prefill). settings 기능의
  /// SettingsSource.fetchConsents와 같은 배선 — 응답 파서(ConsentsView)를 재사용한다.
  Future<ConsentsView> fetchMine() async {
    final json = await _client.get<Map<String, dynamic>>('/consents/me');
    return ConsentsView.fromJson(json);
  }
}

final consentSourceProvider = Provider<ConsentSource>(
  (ref) => ConsentSource(ref.read(apiClientProvider)),
);

/// 동의 화면 진입 시 기존 동의 상태를 읽어 온다. 실패해도 화면은 떠야 하므로
/// 화면 쪽에서 신규 가입자와 같게 폴백한다(AsyncError를 그대로 두고 UI가 처리).
final consentPrefillProvider = FutureProvider<ConsentsView>(
  (ref) => ref.read(consentSourceProvider).fetchMine(),
);
