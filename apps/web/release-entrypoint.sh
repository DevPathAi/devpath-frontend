#!/bin/sh
set -eu

zero_sha='0000000000000000000000000000000000000000000000000000000000000000'

case "${MISSION_RELEASE_READY:-}" in
  true)
    printf '%s' "${MISSION_RELEASE_ID:-}" | grep -Eq '^ms-[0-9]{8}-[a-z0-9][a-z0-9-]{2,40}$'
    printf '%s' "${MISSION_CANDIDATE_SPEC_SHA256:-}" | grep -Eq '^[0-9a-f]{64}$'
    printf '%s' "${MISSION_IMAGE_DIGEST:-}" | grep -Eq '^sha256:[0-9a-f]{64}$'
    printf '%s' "${MISSION_SYNTHETIC_PROBE_TOKEN:-}" | grep -Eq '^[0-9a-f]{64}$'
    test "${MISSION_CANDIDATE_SPEC_SHA256}" != "${zero_sha}"
    test "${MISSION_IMAGE_DIGEST}" != "sha256:${zero_sha}"
    ;;
  false)
    test "${MISSION_RELEASE_ID:-}" = 'unreleased'
    test "${MISSION_CANDIDATE_SPEC_SHA256:-}" = "${zero_sha}"
    test "${MISSION_IMAGE_DIGEST:-}" = "sha256:${zero_sha}"
    test "${MISSION_SYNTHETIC_PROBE_TOKEN:-}" = 'disabled'
    ;;
  *)
    echo 'MISSION_RELEASE_READY must be exactly true or false' >&2
    exit 1
    ;;
esac

exec /docker-entrypoint.sh "$@"
