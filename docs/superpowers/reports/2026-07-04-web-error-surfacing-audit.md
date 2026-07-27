# 웹 에러 표면화 감사 — feature 컨트롤러 에러 경로 정합 확인

- 날짜: 2026-07-04
- 범위: `apps/web/lib/src/features/` 하위 10개 컨트롤러(설계상 지정 목록)
- 목적: 각 컨트롤러의 `catch`/`on ApiException`/에러 상태 전이가 사용자에게 무음 소실 없이 표면화되는지 확인(코드 변경 0, 감사 전용)
- 표면화 위젯 참조: `dp_design`의 `DpError`/`DpKillSwitch`/`DpQuota`

## 감사 표

| 화면 | 컨트롤러 | 에러 catch 경로 | 표면화 방식 | 판정 |
|---|---|---|---|---|
| 로그인(`login_page.dart`) | `auth_controller.dart` | `bootstrapFromCallback()`: `on ApiException catch (e)` → `AuthUnauthenticated(error: e.message)`; `bootstrapSession()`: `on ApiException`/`catch (_)` → `AuthUnauthenticated()`(에러 메시지 없이 미인증 전이 — 앱 시작 자동 세션 복원 실패는 정상 "미인증" 상태로 취급되도록 설계됨) | `login_page.dart:22,56-65`가 `auth.error` 인라인 텍스트(`c.danger`)로 렌더 | OK |
| 커뮤니티 목록(`community_home_page.dart`) | `community_controller.dart` | `on ApiException catch (e)` → `CommunityState(phase: failed, error: e.message)` | `community_home_page.dart:39-42` `DpError(message: s.error, onRetry: notifier.load)` | OK |
| Q&A 상세(`qna_detail_page.dart`) | `qna_detail_controller.dart` | `load()`: `on ApiException catch (e)` → `QnaFailed(e.message)`; `_mutate()`(답변/채택/투표): `on ApiException catch (e)` → `cur.copyWith(actionError: e.message)` | `qna_detail_page.dart:56` `QnaFailed(:message) => DpError(message: message)`; actionError는 `QnaLoaded` 상태 필드로 상세 화면 내 별도 인라인 표시(`qna_detail_page.dart` 내 actionError 사용 확인) | OK |
| 콘텐츠(`content_page.dart`) | `content_controller.dart` | `load()`/`reportProgress()`: `on ApiException catch (e)` → `ContentFailed(e.message)` | `content_page.dart:106-109` `ContentFailed(:message) => DpError(message, onRetry)` | OK |
| 대시보드(`dashboard_page.dart`) | `dashboard_controller.dart` | `on ApiException catch (e)` → `DashFailed(e.message)` | `dashboard_page.dart:33-36` `DashFailed(:message) => DpError(message, onRetry)` | OK |
| 실력진단(`diagnostic_page.dart`) | `diagnostic_controller.dart` | 전 메서드(`startAsMember`/`startAsGuest`/`_answer`/`claimAfterLogin`): `on ApiException catch (e)` → `DiagnosticError(e.message)` | `diagnostic_page.dart:81` `DiagnosticError(:message) => Text(message, ...)`(인라인 에러 텍스트, `DpError` 위젯은 아니지만 화면에 표시됨) | OK |
| AI 멘토(`mentor_page.dart`) | `mentor_controller.dart` | SSE `onError`: `ApiException.isKillSwitch` → `MentorStatus.killSwitch`; 그 외 `ApiException` → `failed`; 비-`ApiException` → `partial`(부분답변 보존) | `mentor_page.dart:41-42` `killSwitch → DpKillSwitch()`; `:67-91` `partial → 안내+재시도 버튼`; `:92-101` `failed → Text(s.error, color: danger)` | OK |
| 학습경로(`path_page.dart`) | `path_controller.dart` | `loadOrStart()`: `on ApiException catch (e)`(404 아니면) → `failed`; SSE `onError`: `isKillSwitch`→`killSwitch`, `isQuota`→`failed`, 그 외→`partial`; `done` 단계 재조회 실패 → `failed` | `path_page.dart:46-49` `failed\|\|killSwitch => DpError(...)`; `:50-55` `partial => _Progress(note: error, onRestart)` | OK |
| AI 리뷰(`review_panel.dart`) | `review_controller.dart` | 폴링 루프: `on ApiException catch (e)` → `isKillSwitch`→`ReviewKillSwitch`, `isQuota`→`ReviewQuota`, 404/`resourceNotFound`→재시도 계속, 그 외→`ReviewFailed(e.message)`; 타임아웃 → `ReviewFailed('...시간 초과...')` | `review_panel.dart:53-65` `ReviewKillSwitch()=>DpKillSwitch(...)`, `ReviewQuota(:retryAfterSeconds)=>DpQuota(...)`, `ReviewFailed(:message)=>DpError(message, onRetry)` | OK |
| 샌드박스(`sandbox_page.dart`) | `run_controller.dart` | SSE `onError`: `ApiErrorCode.sandboxUnavailable`→`RunUnavailable`; 그 외 → `RunDone(logs: [...,'실행 오류: $msg'])`(에러 메시지를 로그 라인에 append) | `sandbox_page.dart:99` `RunUnavailable => DpSandboxUnavailable()`; 그 외 에러는 `_LogPane`이 `RunDone.logs`를 코드 로그 패널에 그대로 렌더(`실행 오류: ...` 라인 포함) — 별도 에러 위젯은 아니지만 로그에 표시되어 사용자에게 보임 | OK |

## 부가 확인 — 무해 폴백(catch swallow) 패턴

다음은 grep에서 걸린 `catch`이지만 API 에러 표면화 경로가 아니라 **의도된 무해 폴백**으로 판단(무음 실패 아님):

- `auth_controller.dart:52` `catch (_)` → `AuthUnauthenticated()`: 앱 시작 자동 세션 복원 실패는 에러가 아니라 정상 "미인증" 상태 전이(설계 주석에 명시: "네트워크/타임아웃/파싱 등 비-ApiException → 미인증"). 사용자는 로그인 페이지로 자연 유도됨.
- `diagnostic_page.dart:127` `catch (_) {}` → 진단 문항 옵션 JSON 파싱 실패 시 빈 리스트 반환. API 호출 자체의 에러가 아니라 렌더링 보조 파싱이며, 실패해도 빈 옵션 리스트로 안전하게 폴백.
- `mentor_controller.dart:122` `catch (_)` → SSE `references` 이벤트 파싱 실패 시 빈 리스트. 참고자료는 부가 정보이며 토큰 스트림(본 답변) 자체는 별도 핸들러가 정상 처리.
- `path_controller.dart:170` `_eventOf` catch(_) → SSE 개별 이벤트 파싱 실패 시 해당 이벤트만 무시(`return null` → 호출부에서 스킵). 스트림 종료(`done`/`error`)는 별도 핸들러가 처리하므로 최종 결과는 여전히 표면화됨.
- `content_page.dart:199` `catchError((_) => {})` → 위젯 dispose 시 진행률 flush를 fire-and-forget으로 전송. 사용자가 이미 화면을 떠난 시점이라 표시할 UI 대상이 없는 best-effort 전송(다음 방문 시 서버 최신값으로 재동기화됨).

## 무음 실패 목록

없음(전 경로 표면화 확인)

10개 컨트롤러 전부에서 `ApiException` 기반 에러 상태 전이가 존재하며, 각 전이 상태는 대응하는 presentation 위젯(`DpError`/`DpKillSwitch`/`DpQuota`/인라인 에러 텍스트/로그 라인)으로 화면에 렌더링됨을 코드 레벨에서 확인했다. 위에 나열한 5건의 `catch(_)`/`catchError` 스월로우는 모두 API 에러 경로가 아닌 보조 파싱/best-effort 전송이며, 해당 실패가 사용자에게 의미 있는 정보 손실을 일으키지 않는다.
