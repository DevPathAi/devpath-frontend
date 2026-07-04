# SSE Live Smoke 하네스 (C1)

로컬 실서버 SSE 와이어를 캡처해 프론트 계약과 대조한다.

## JWT 발급

    node mint-jwt.js <userId> [role] [ttlSec]

HS256, secret=`devpath.auth.jwt-secret` dev 기본값(`JWT_SECRET` env로 override). 각 svc는 oauth2-resource-server로 동일 시크릿을 검증한다.

## 캡처

    TOKEN=$(node mint-jwt.js 1)
    curl -N -X POST -H "Authorization: Bearer $TOKEN" \
      -H "Accept: text/event-stream" -H "Content-Type: application/json" \
      -d '<body>' http://localhost:<port><path> | tee captures/<endpoint>.txt

- 포트: learning 8082 · ai 8084 · sandbox 8085 (각 `SERVER_PORT` env로 분리 기동).
- AI provider는 전부 `mock` 기본 — 와이어 검증에 Claude 키 불필요.
- `captures/`는 gitignore(원문은 리포트에 요약 인용).
