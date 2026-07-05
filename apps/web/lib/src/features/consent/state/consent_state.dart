/// 회원가입 필수 동의 gate 화면 상태(sealed — presentation이 분기).
sealed class ConsentState {
  const ConsentState();
}

/// 폼 편집 중(초기). 필수/선택 동의 체크 + 생년 입력.
class ConsentEditing extends ConsentState {
  const ConsentEditing();
}

/// 제출 진행 중(POST /consents).
class ConsentSubmitting extends ConsentState {
  const ConsentSubmitting();
}

/// 필수 동의 완료 → authController consentStatus=DONE 갱신됨(게이트가 다음 단계로).
class ConsentDone extends ConsentState {
  const ConsentDone();
}

/// 만 14세 미만(400 VALIDATION_FAILED) → 가입 차단 안내 + 로그아웃.
class ConsentBlocked extends ConsentState {
  const ConsentBlocked();
}

/// 제출 실패(네트워크/서버 등 14세 외 오류). 인라인 에러 후 재시도 가능.
class ConsentError extends ConsentState {
  const ConsentError(this.message);
  final String message;
}
