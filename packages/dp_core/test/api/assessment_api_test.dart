import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

ApiClient mockClient(Map<String, MockFixture> fixtures) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://t', useMock: true));
  c.dio.httpClientAdapter = MockHttpAdapter(fixtures);
  return c;
}

void main() {
  test('startGuest는 guestAssessmentId를 반환', () async {
    final api = AssessmentApi(mockClient({
      'POST /onboarding/assessments/guest': (200, {'guestAssessmentId': 'g-123'}),
    }));
    expect(await api.startGuest('BACKEND_SPRING'), 'g-123');
  });

  test('next는 NextQuestion 매핑', () async {
    final api = AssessmentApi(mockClient({
      'GET /onboarding/assessments/guest/g-123/next': (200, {
        'question': {
          'id': 1,
          'type': 'MCQ',
          'content': 'Q',
          'options': null,
          'bloomLevel': 'REMEMBER',
          'difficulty': 0.3,
        },
        'index': 1,
        'total': 15,
      }),
    }));
    final n = await api.next(guestId: 'g-123');
    expect(n!.question.id, 1);
  });

  test('_base는 둘 다 지정 시 ArgumentError', () {
    final api = AssessmentApi(mockClient({}));
    expect(() => api.next(assessmentId: 1, guestId: 'g'), throwsArgumentError);
  });
}
