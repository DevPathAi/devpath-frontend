/// Learner-facing labels for learning API wire values.
///
/// Unknown values deliberately collapse to a neutral label so server enums do
/// not leak into product copy during mixed-version rollouts.
abstract final class DpLearningLabels {
  static String track(String wireValue) => switch (wireValue) {
    'BACKEND' || 'BACKEND_SPRING' => '백엔드 · Spring',
    'FRONTEND' || 'FRONTEND_REACT' => '프론트엔드 · React',
    'MOBILE' || 'MOBILE_FLUTTER' => '모바일 · Flutter',
    'DATA' || 'DATA_ENGINEERING' => '데이터 엔지니어링',
    'DEVOPS' || 'CLOUD_DEVOPS' => '클라우드 · DevOps',
    _ => '학습 경로',
  };

  static String taskType(String wireValue) => switch (wireValue) {
    'READ' => '읽기',
    'PRACTICE' => '실습',
    'QUIZ' => '확인',
    _ => '학습',
  };

  static String syncStatus(String wireValue) => switch (wireValue) {
    'SYNCED' => '동기화됨',
    'SYNC_PENDING' => '동기화 대기',
    'SYNC_FAILED' => '동기화 필요',
    _ => '상태 확인 중',
  };

  static String bloomLevel(String wireValue) => switch (wireValue) {
    'REMEMBER' => '기억하기',
    'UNDERSTAND' => '이해하기',
    'APPLY' => '적용하기',
    'ANALYZE' => '분석하기',
    'EVALUATE' => '평가하기',
    'CREATE' => '만들기',
    _ => '학습하기',
  };

  static String difficulty(num value) {
    if (value <= 0.33) return '입문';
    if (value <= 0.66) return '중급';
    return '심화';
  }
}
