/// DevPath AI 도메인·데이터 계층(순수 Dart).
library; // P1 교훈: lints ^6.0.0 unnecessary_library_name — 이름 없는 library 사용

export 'src/error/api_error_code.dart';
export 'src/error/api_exception.dart';
export 'src/api/api_config.dart';
export 'src/api/api_client.dart';
export 'src/api/page.dart';
export 'src/auth/token_store.dart';
export 'src/auth/auth_interceptor.dart';
export 'src/sse/sse_event.dart';
export 'src/sse/sse_client.dart';
export 'src/models/enums.dart';
export 'src/models/user.dart';
export 'src/models/learning_path.dart';
export 'src/models/learning_content.dart';
export 'src/models/path_sse_event.dart';
export 'src/models/code_review.dart';
export 'src/models/dashboard_summary.dart';
export 'src/models/community_post.dart';
export 'src/models/lcs_snapshot.dart';
export 'src/models/assessment.dart';
export 'src/api/assessment_api.dart';
export 'src/mock/mock_http_adapter.dart';
export 'src/mock/mock_sse_source.dart';

/// 패키지 버전.
const String dpCoreVersion = '0.0.1';
