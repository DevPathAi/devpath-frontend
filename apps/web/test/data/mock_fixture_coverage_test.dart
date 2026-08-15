import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 목 모드가 기본값이라 픽스처가 없으면 화면이 에러로 뜬다.
  // 2026-08-03 실측에서 아래 셋이 누락돼 설정·마이페이지·콘텐츠가 깨져 있었다.
  test('사용자가 도달하는 주요 GET 은 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('GET /consents/me'), isTrue);
    expect(webMockFixtures.containsKey('GET /users/me/profile'), isTrue);
    expect(webMockFixtures.containsKey('GET /notifications/prefs/me'), isTrue);
  });

  test('콘텐츠 진행 저장 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('POST /contents/c1/progress'), isTrue);
  });

  test('Today contentId 3의 조회와 진행 저장 alias 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('GET /contents/3'), isTrue);
    expect(webMockFixtures.containsKey('POST /contents/3/progress'), isTrue);

    final (getStatus, getBody) = webMockFixtures['GET /contents/3']!;
    expect(getStatus, inInclusiveRange(200, 299));
    expect((getBody as Map)['id'], 3);
    expect(getBody['slug'], 'async-error-handling');

    final (progressStatus, progressBody) =
        webMockFixtures['POST /contents/3/progress']!;
    expect(progressStatus, inInclusiveRange(200, 299));
    expect((progressBody as Map)['completed'], isTrue);
  });

  // 2026-08-03: 회원(로그인) 진단 흐름 — assessment_api.dart의 회원 경로
  // (assessmentId 기반) 전부. 이 중 하나라도 빠지면 온보딩 게이트가 진단
  // 화면으로 보낸 로그인 회원이 그 지점에서 다시 막힌다.
  test('회원 진단 경로 픽스처가 전부 있다', () {
    expect(webMockFixtures.containsKey('POST /onboarding/assessments'), isTrue);
    expect(
      // next 는 고정 픽스처가 아니라 시퀀스다 — 같은 문항이 반복되면 완료로
      // 넘어가지 못하기 때문이다(마지막이 null 이어야 complete 로 간다).
      webMockSequences.containsKey('GET /onboarding/assessments/1/next'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/1/answer'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/1/complete'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('POST /onboarding/assessments/claim'),
      isTrue,
    );
    expect(
      webMockFixtures.containsKey('GET /onboarding/assessments/1/result'),
      isTrue,
    );
  });

  test('상태코드는 성공 범위다', () {
    for (final key in [
      'GET /consents/me',
      'GET /users/me/profile',
      'GET /notifications/prefs/me',
      'POST /contents/c1/progress',
      'POST /onboarding/assessments',
      'POST /onboarding/assessments/1/answer',
      'POST /onboarding/assessments/1/complete',
      'POST /onboarding/assessments/claim',
      'GET /onboarding/assessments/1/result',
    ]) {
      final (status, _) = webMockFixtures[key]!;
      expect(status, inInclusiveRange(200, 299), reason: key);
    }
  });

  group('진단 시퀀스', () {
    // 목 모드 진단이 완주하려면 next 가 마지막에 null 을 돌려줘야 한다
    // (AssessmentApi.next 는 본문이 null 일 때만 null 을 반환하고,
    //  DiagnosticController 는 그때만 complete() 로 넘어간다).
    for (final key in [
      'GET /onboarding/assessments/1/next',
      'GET /onboarding/assessments/guest/g-mock/next',
    ]) {
      test('$key 는 문항 2개 뒤 null 로 끝난다', () {
        final seq = webMockSequences[key];
        expect(seq, isNotNull, reason: '$key 시퀀스가 없으면 진단이 시작조차 안 된다');
        expect(
          seq!.length,
          greaterThanOrEqualTo(2),
          reason: '문항이 최소 1개는 이어져야 한다',
        );

        // 마지막은 반드시 null — 이것이 완료 판정의 유일한 신호다.
        final (lastStatus, lastBody) = seq.last;
        expect(lastStatus, 200);
        expect(lastBody, isNull, reason: '마지막이 null 이 아니면 같은 문항이 무한 반복된다');

        // 그 앞은 전부 문항이어야 한다.
        for (final (status, body) in seq.take(seq.length - 1)) {
          expect(status, inInclusiveRange(200, 299));
          expect((body as Map)['question'], isNotNull);
        }
      });
    }
  });
}
