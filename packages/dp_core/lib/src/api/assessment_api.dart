import '../models/assessment.dart';
import 'api_client.dart';

/// 진단 API 클라이언트. 회원(assessmentId)·비회원(guestId) 동일 인터페이스.
class AssessmentApi {
  AssessmentApi(this.client);

  final ApiClient client;

  String _base({int? assessmentId, String? guestId}) {
    if ((assessmentId == null) == (guestId == null)) {
      throw ArgumentError('assessmentId와 guestId 중 정확히 하나만 지정해야 한다');
    }
    return guestId != null
        ? '/onboarding/assessments/guest/$guestId'
        : '/onboarding/assessments/$assessmentId';
  }

  Future<String> startGuest(String track) async {
    final data = await client.post<Map<String, dynamic>>(
      '/onboarding/assessments/guest',
      body: {'track': track},
    );
    return data['guestAssessmentId'] as String;
  }

  Future<int> startMember(String track) async {
    final data = await client.post<Map<String, dynamic>>(
      '/onboarding/assessments',
      body: {'track': track},
    );
    return data['assessmentId'] as int;
  }

  Future<NextQuestion?> next({int? assessmentId, String? guestId}) async {
    final data = await client.get<Map<String, dynamic>?>(
      '${_base(assessmentId: assessmentId, guestId: guestId)}/next',
    );
    if (data == null) return null;
    return NextQuestion.fromJson(data);
  }

  Future<void> answer({
    int? assessmentId,
    String? guestId,
    required int questionId,
    String? answer,
    required bool skipped,
    int? timeSpentSec,
  }) async {
    await client.post<void>(
      '${_base(assessmentId: assessmentId, guestId: guestId)}/answer',
      body: {
        'questionId': questionId,
        'answer': answer,
        'skipped': skipped,
        'timeSpentSec': timeSpentSec,
      },
    );
  }

  Future<AssessmentResult> complete({
    int? assessmentId,
    String? guestId,
  }) async {
    final data = await client.post<Map<String, dynamic>>(
      '${_base(assessmentId: assessmentId, guestId: guestId)}/complete',
    );
    return AssessmentResult.fromJson(data);
  }

  Future<AssessmentResult> result(int assessmentId) async {
    final data = await client.get<Map<String, dynamic>>(
      '/onboarding/assessments/$assessmentId/result',
    );
    return AssessmentResult.fromJson(data);
  }

  Future<int> claim(String guestAssessmentId) async {
    final data = await client.post<Map<String, dynamic>>(
      '/onboarding/assessments/claim',
      body: {'guest_assessment_id': guestAssessmentId},
    );
    return data['assessmentId'] as int;
  }
}
