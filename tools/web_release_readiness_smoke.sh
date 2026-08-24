#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <candidate-image> <off|on>" >&2
  exit 64
fi

candidate_reference="$1"
identity="$2"
case "${identity}" in
  off | on) ;;
  *)
    echo "identity must be 'off' or 'on'" >&2
    exit 64
    ;;
esac

GITHUB_RUN_ID="${GITHUB_RUN_ID:-local-$$}"
runner_temp="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
release_id=ms-20990101-runtime-smoke
candidate_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
image_digest=sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
PROBE_TOKEN=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
disabled_container="mission-readiness-${GITHUB_RUN_ID}-${identity}-disabled"
ready_container="mission-readiness-${GITHUB_RUN_ID}-${identity}-ready"
disabled_port=18080
ready_port=18081
body="${runner_temp}/${ready_container}.body"
headers="${runner_temp}/${ready_container}.headers"
normalized_headers="${headers}.normalized"

cleanup_containers() {
  docker rm -f "${disabled_container}" >/dev/null 2>&1 || true
  docker rm -f "${ready_container}" >/dev/null 2>&1 || true
}

show_container_log() {
  local container="$1"
  if docker inspect "${container}" >/dev/null 2>&1; then
    echo "--- ${container} logs ---" >&2
    docker logs "${container}" >&2 || true
  fi
}

on_exit() {
  local status=$?
  trap - EXIT
  if [[ "${status}" -ne 0 ]]; then
    echo "release readiness smoke failed for identity=${identity}" >&2
    show_container_log "${disabled_container}"
    show_container_log "${ready_container}"
  fi
  cleanup_containers
  rm -f "${body}" "${headers}" "${normalized_headers}"
  exit "${status}"
}
trap on_exit EXIT

wait_for_web() {
  local container="$1"
  local port="$2"
  for _ in $(seq 1 30); do
    if curl --fail --silent "http://127.0.0.1:${port}/" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "web root did not become ready on port ${port}" >&2
  show_container_log "${container}"
  return 1
}

assert_status() {
  local label="$1"
  local expected="$2"
  local actual="${!label}"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label}: expected ${expected}, got ${actual}" >&2
    return 1
  fi
}

docker run --detach --name "${disabled_container}" \
  --publish "127.0.0.1:${disabled_port}:8080" "${candidate_reference}" >/dev/null
wait_for_web "${disabled_container}" "${disabled_port}"
disabled_unauth_status="$(curl --silent --show-error --output "${body}" --write-out '%{http_code}' \
  "http://127.0.0.1:${disabled_port}/internal/release/ready")"
assert_status disabled_unauth_status 401
disabled_auth_status="$(curl --silent --show-error --output "${body}" --write-out '%{http_code}' \
  --header 'Authorization: Bearer disabled' \
  "http://127.0.0.1:${disabled_port}/internal/release/ready")"
assert_status disabled_auth_status 503
docker rm -f "${disabled_container}" >/dev/null

if docker run --rm --env MISSION_RELEASE_READY=true \
  "${candidate_reference}" >/dev/null 2>&1; then
  echo "incomplete release identity unexpectedly started" >&2
  exit 1
fi

docker run --detach --name "${ready_container}" \
  --publish "127.0.0.1:${ready_port}:8080" \
  --env MISSION_RELEASE_READY=true \
  --env MISSION_RELEASE_ID="${release_id}" \
  --env MISSION_CANDIDATE_SPEC_SHA256="${candidate_sha}" \
  --env MISSION_IMAGE_DIGEST="${image_digest}" \
  --env MISSION_SYNTHETIC_PROBE_TOKEN="${PROBE_TOKEN}" \
  "${candidate_reference}" >/dev/null
wait_for_web "${ready_container}" "${ready_port}"
ready_unauth_status="$(curl --silent --show-error --output "${body}" --write-out '%{http_code}' \
  "http://127.0.0.1:${ready_port}/internal/release/ready")"
assert_status ready_unauth_status 401
ready_auth_status="$(curl --silent --show-error \
  --dump-header "${headers}" --output "${body}" --write-out '%{http_code}' \
  --header "Authorization: Bearer ${PROBE_TOKEN}" \
  "http://127.0.0.1:${ready_port}/internal/release/ready")"
assert_status ready_auth_status 200

expected="{\"release_id\":\"${release_id}\",\"candidate_spec_sha256\":\"${candidate_sha}\",\"image_digest\":\"${image_digest}\",\"status\":\"ready\"}"
actual_body="$(cat "${body}")"
if [[ "${actual_body}" != "${expected}" ]]; then
  echo "ready_body: response did not match the sealed synthetic identity" >&2
  echo "actual=${actual_body}" >&2
  exit 1
fi

tr -d '\r' <"${headers}" >"${normalized_headers}"
if ! grep -Fqix 'Cache-Control: no-store' "${normalized_headers}"; then
  echo "ready_headers: Cache-Control: no-store is missing" >&2
  exit 1
fi
if ! grep -Fqix 'X-Content-Type-Options: nosniff' "${normalized_headers}"; then
  echo "ready_headers: X-Content-Type-Options: nosniff is missing" >&2
  exit 1
fi

echo "release readiness smoke passed for identity=${identity}"
