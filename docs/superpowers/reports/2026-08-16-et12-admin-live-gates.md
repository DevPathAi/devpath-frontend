# ET12 Admin live gates

Date: 2026-08-16
Scope: `apps/admin` UI conformance only

ET12의 widget/controller 검증은 Riverpod provider override로 수행했다. 아래 항목은
로컬 UI 계약이 통과해도 live backend parity를 의미하지 않는다. 이 작업에서는
backend, GitOps, 전역 mock fixture를 수정하지 않았다.

## External gates

| Contract | Current evidence | What is not proven | Release gate |
|---|---|---|---|
| `GET /admin/stats` | Admin client wiring and a local exact-route fixture exist. Provider-override tests verify four canonical integer keys, canonical card order, empty/error state, semantics, and 320/600/840/1240 layout. | A deployed endpoint, ADMIN/OWNER authorization, and live response shape were not verified. | With an authorized live account, confirm 2xx and integer values for `dau`, `newUsers`, `openReports`, `aiCalls`; separately exercise empty and non-2xx responses. |
| `POST /admin/users/{id}/sanction` | The UI has an impact confirmation and retains the dialog/error on provider failure. The provider seam preserves the existing `action` value. The app-owned mock contains only the exact numeric `/admin/users/2/sanction` path. | The existing repository spec records that no backend sanction endpoint exists. Action enum, authorization, audit logging, and live mutation are therefore unproven. | Backend owner must publish the request/response and action contract, implement authorization/audit behavior, and complete an authorized live sanction/recovery test before parity is claimed. |
| Global Admin mocks | Some exact paths are present. Provider overrides cover UI contracts, while the app-owned user fixture uses numeric IDs and a recoverable `BETA_PENDING` row for the local approval flow. | The fixture set is incomplete (for example slot-config can be absent), and exact mock matches do not prove query filtering or deployed routing. | Run each changed surface against a deployed API with status and slot query combinations; record response and authorization evidence. |

## Explicit non-claims

- Provider overrides prove UI state handling, raw wire preservation, and request-boundary
  forwarding only.
- App-owned fixture adjustments make local approval recoverable; they do not add or
  claim a live sanction/stats contract.
- No approved brand mark asset was available. Auth/access states therefore use the
  existing wordmark typography only and do not synthesize a replacement mark.
