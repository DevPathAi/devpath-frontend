/// 진단 화면과 마이페이지가 함께 쓰는 트랙 카탈로그.
///
/// **키는 서버 계약이다.** `assessments.track`·`user_profiles.target_track`·
/// `question_bank.track` 의 CHECK 제약이 이 문자열을 그대로 쓴다. 값(라벨)만 표시용이다.
///
/// 트랙을 늘릴 때는 이 파일 한 곳만 고친다 — 두 화면이 함께 따라온다.
///
/// **여기에 트랙을 더하기 전에 그 트랙 문항이 운영에 있는지 먼저 확인한다.**
/// 문항이 0건인 트랙을 이용자가 고르면 진단이 깨끗하게 실패하지 않는다 —
/// `NextQuestionSelector` 가 null 을 내고 `next()` 가 `Optional.empty()` 를 반환하는데,
/// 그것은 「진단 완료」와 같은 신호다. 그런데 `complete` 는 15문항 응답을 요구하므로
/// 이용자는 **빠져나올 수 없는 세션**에 갇힌다.
const trackLabels = <String, String>{
  'BACKEND_SPRING': '백엔드 (Spring)',
  'FRONTEND_REACT': '프론트엔드 (React)',
  'MOBILE_FLUTTER': '모바일 (Flutter)',
  'DEVOPS': 'DevOps',
  'FULLSTACK': '풀스택',
  'PYTHON_BACKEND': 'Python 백엔드 (Django/FastAPI)',
  'NODE_TYPESCRIPT': 'Node.js 백엔드 (TypeScript)',
  'DATA_AI': '데이터·AI (분석/ML)',
};
