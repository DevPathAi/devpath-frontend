import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

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
}

final consentSourceProvider = Provider<ConsentSource>(
  (ref) => ConsentSource(ref.read(apiClientProvider)),
);
