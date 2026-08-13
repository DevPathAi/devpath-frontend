/// 진단 화면과 마이페이지가 함께 쓰는 트랙 카탈로그.
///
/// **키는 서버 계약이다.** `assessments.track`·`user_profiles.target_track`·
/// `question_bank.track` 의 CHECK 제약이 이 문자열을 그대로 쓴다. 값(라벨)만 표시용이다.
///
/// 트랙을 늘릴 때는 이 파일 한 곳만 고친다 — 두 화면이 함께 따라온다.
const trackLabels = <String, String>{
  'BACKEND_SPRING': '백엔드 (Spring)',
  'FRONTEND_REACT': '프론트엔드 (React)',
  'MOBILE_FLUTTER': '모바일 (Flutter)',
  'DEVOPS': 'DevOps',
  'FULLSTACK': '풀스택',
};
