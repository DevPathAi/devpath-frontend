#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_REPOSITORY='ghcr.io/devpathai/devpath-admin'
readonly SOURCE_URL='https://github.com/DevPathAi/devpath-frontend'

if ! declare -F ghcr_manifest_lookup >/dev/null; then
  script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=immutable_registry.sh
  source "${script_root}/immutable_registry.sh"
fi

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_sha256() {
  [[ "$1" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "$2 is not a SHA-256 digest"
}

require_source_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]] || fail 'SOURCE_SHA must be lowercase Git SHA-1'
  test "$1" != '0000000000000000000000000000000000000000' || \
    fail 'SOURCE_SHA cannot be all zeroes'
}

resolve_linux_amd64_config() {
  local root_digest="$1"
  local root_manifest_json
  local child_digest
  local child_manifest_json
  local config_digest
  local unexpected_runnable_count
  local linux_amd64_count

  require_sha256 "${root_digest}" 'root image digest'
  if ! root_manifest_json="$(
    docker buildx imagetools inspect \
      "${IMAGE_REPOSITORY}@${root_digest}" --raw
  )"; then
    fail "unable to inspect exact root image ${root_digest}"
  fi

  if jq -e '
    (.manifests? == null) and
    ((.config.digest? | type) == "string")
  ' <<<"${root_manifest_json}" >/dev/null; then
    child_manifest_json="${root_manifest_json}"
  elif jq -e '(.manifests | type) == "array"' \
    <<<"${root_manifest_json}" >/dev/null; then
    jq -e '
      (.manifests | length) > 0 and
      all(.manifests[];
        ((.digest | type) == "string") and
        (.digest | test("^sha256:[0-9a-f]{64}$")) and
        ((.platform | type) == "object") and
        ((.platform.os | type) == "string") and
        ((.platform.architecture | type) == "string")
      )
    ' <<<"${root_manifest_json}" >/dev/null || \
      fail 'malformed OCI index descriptors'
    jq -e '
      all(.manifests[];
        if (.platform.os == "unknown" and
            .platform.architecture == "unknown") then
          .annotations["vnd.docker.reference.type"] ==
            "attestation-manifest"
        else
          true
        end
      )
    ' <<<"${root_manifest_json}" >/dev/null || \
      fail 'unknown platform descriptor is not an attestation'

    unexpected_runnable_count="$(jq -er '[
      .manifests[]
      | select(
          .platform.os != "unknown" or
          .platform.architecture != "unknown"
        )
      | select(
          .platform.os != "linux" or
          .platform.architecture != "amd64"
        )
    ] | length' <<<"${root_manifest_json}")"
    test "${unexpected_runnable_count}" = '0' || \
      fail 'OCI index has an unexpected runnable platform'

    linux_amd64_count="$(jq -er '[
      .manifests[]
      | select(
          .platform.os == "linux" and
          .platform.architecture == "amd64"
        )
    ] | length' <<<"${root_manifest_json}")"
    test "${linux_amd64_count}" = '1' || \
      fail 'OCI index must contain exactly one linux/amd64 child'
    child_digest="$(jq -er '
      .manifests[]
      | select(
          .platform.os == "linux" and
          .platform.architecture == "amd64"
        )
      | .digest
    ' <<<"${root_manifest_json}")"
    if ! child_manifest_json="$(
      docker buildx imagetools inspect \
        "${IMAGE_REPOSITORY}@${child_digest}" --raw
    )"; then
      fail "unable to inspect linux/amd64 child ${child_digest}"
    fi
  else
    fail 'exact image is neither a runnable manifest nor an OCI index'
  fi

  config_digest="$(jq -er '
    if .manifests? != null then
      error("nested OCI index is not runnable")
    elif ((.config.digest? | type) != "string") then
      error("image config digest missing")
    elif (.config.digest | test("^sha256:[0-9a-f]{64}$") | not) then
      error("invalid image config digest")
    else
      .config.digest
    end
  ' <<<"${child_manifest_json}")" || \
    fail 'unable to resolve runnable image config digest'
  printf '%s\n' "${config_digest}"
}

remote_image() {
  local digest="$1"
  local image_json
  require_sha256 "${digest}" 'remote image digest'
  image_json="$(
    docker buildx imagetools inspect \
      "${IMAGE_REPOSITORY}@${digest}" --format '{{json .Image}}'
  )" || fail "unable to inspect exact image ${digest}"
  jq -ec '
    if (.architecture == "amd64" and .os == "linux") then .
    elif (.["linux/amd64"].architecture == "amd64" and
          .["linux/amd64"].os == "linux") then .["linux/amd64"]
    else error("linux/amd64 image config missing")
    end
  ' <<<"${image_json}"
}

validate_remote_identity() {
  local digest="$1"
  local normalized_image
  normalized_image="$(remote_image "${digest}")"
  jq -e \
    --arg sha "${SOURCE_SHA}" \
    --arg source "${SOURCE_URL}" '
      .architecture == "amd64" and
      .os == "linux" and
      .config.Labels["org.opencontainers.image.revision"] == $sha and
      .config.Labels["org.opencontainers.image.source"] == $source
    ' <<<"${normalized_image}" >/dev/null || \
    fail "refusing incompatible immutable admin tag ${TAG_REFERENCE}"
}

write_output() {
  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
  printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT}"
}

preflight() {
  local lookup
  local state
  local tag_digest
  local config_digest
  local trailing
  lookup="$(ghcr_manifest_lookup "${IMAGE_REPOSITORY}" "${SOURCE_SHA}")" || \
    fail 'immutable admin tag preflight failed closed'
  read -r state tag_digest trailing <<<"${lookup}"
  test -z "${trailing:-}" || fail 'immutable admin lookup has extra fields'
  case "${state}" in
    present)
      require_sha256 "${tag_digest}" 'immutable tag digest'
      config_digest="$(resolve_linux_amd64_config "${tag_digest}")"
      validate_remote_identity "${tag_digest}"
      write_output state present
      write_output digest "${tag_digest}"
      write_output config_digest "${config_digest}"
      ;;
    absent)
      test -z "${tag_digest:-}" || fail 'absent lookup carried a digest'
      write_output state absent
      write_output digest ''
      write_output config_digest ''
      ;;
    *) fail 'immutable admin lookup returned an invalid state' ;;
  esac
}

candidate() {
  local candidate_json
  local config_digest
  candidate_json="$(
    docker image inspect "${CANDIDATE_REFERENCE}" | jq -ec '
      if length == 1 then .[0]
      else error("candidate image cardinality must be one")
      end
    '
  )" || fail 'unable to inspect admin candidate image'
  jq -e \
    --arg sha "${SOURCE_SHA}" \
    --arg source "${SOURCE_URL}" '
      .Architecture == "amd64" and
      .Os == "linux" and
      .Config.Labels["org.opencontainers.image.revision"] == $sha and
      .Config.Labels["org.opencontainers.image.source"] == $source and
      (.Id | test("^sha256:[0-9a-f]{64}$"))
    ' <<<"${candidate_json}" >/dev/null || \
    fail 'admin candidate identity is incompatible'
  config_digest="$(jq -er '.Id' <<<"${candidate_json}")"
  write_output config_digest "${config_digest}"
}

bind() {
  local lookup
  local state
  local observed_digest
  local observed_config_digest
  local registry_digest
  local publish_mode
  local trailing
  : "${PREFLIGHT_STATE:?PREFLIGHT_STATE is required}"
  : "${CANDIDATE_CONFIG_DIGEST:?CANDIDATE_CONFIG_DIGEST is required}"
  case "${PREFLIGHT_STATE}" in
    present)
      require_sha256 "${PREFLIGHT_DIGEST:-}" 'preflight digest'
      require_sha256 \
        "${PREFLIGHT_CONFIG_DIGEST:-}" 'preflight config digest'
      ;;
    absent)
      test -z "${PREFLIGHT_DIGEST:-}" || \
        fail 'absent preflight cannot carry a digest'
      test -z "${PREFLIGHT_CONFIG_DIGEST:-}" || \
        fail 'absent preflight cannot carry a config digest'
      ;;
    *) fail 'invalid immutable admin preflight state' ;;
  esac
  require_sha256 "${CANDIDATE_CONFIG_DIGEST}" 'candidate config digest'

  lookup="$(ghcr_manifest_lookup "${IMAGE_REPOSITORY}" "${SOURCE_SHA}")" || \
    fail 'immutable admin tag bind failed closed'
  read -r state observed_digest trailing <<<"${lookup}"
  test -z "${trailing:-}" || fail 'immutable admin lookup has extra fields'
  case "${state}" in
    present)
      require_sha256 "${observed_digest}" 'observed immutable tag digest'
      observed_config_digest="$(
        resolve_linux_amd64_config "${observed_digest}"
      )"
      validate_remote_identity "${observed_digest}"
      if test "${PREFLIGHT_STATE}" = 'present'; then
        test "${observed_digest}" = "${PREFLIGHT_DIGEST}" || \
          fail 'refusing immutable admin digest changed during build'
        test "${observed_config_digest}" = "${PREFLIGHT_CONFIG_DIGEST}" || \
          fail 'refusing immutable admin config changed during build'
      fi
      test "${observed_config_digest}" = "${CANDIDATE_CONFIG_DIGEST}" || \
        fail 'refusing immutable admin tag: candidate config drift'
      registry_digest="${observed_digest}"
      publish_mode='reused'
      ;;
    absent)
      test -z "${observed_digest:-}" || fail 'absent lookup carried a digest'
      test "${PREFLIGHT_STATE}" = 'absent' || \
        fail 'refusing to recreate immutable admin tag after disappearance'
      docker tag "${CANDIDATE_REFERENCE}" "${TAG_REFERENCE}"
      docker push "${TAG_REFERENCE}"
      lookup="$(
        ghcr_manifest_lookup "${IMAGE_REPOSITORY}" "${SOURCE_SHA}"
      )" || fail 'unable to inspect newly created immutable admin tag'
      read -r state registry_digest trailing <<<"${lookup}"
      test -z "${trailing:-}" || fail 'immutable admin lookup has extra fields'
      test "${state}" = 'present' || fail 'new immutable admin tag is absent'
      require_sha256 "${registry_digest}" 'created immutable tag digest'
      observed_config_digest="$(
        resolve_linux_amd64_config "${registry_digest}"
      )"
      test "${observed_config_digest}" = "${CANDIDATE_CONFIG_DIGEST}" || \
        fail 'new immutable admin tag has candidate config drift'
      validate_remote_identity "${registry_digest}"
      publish_mode='created'
      ;;
    *) fail 'immutable admin lookup returned an invalid state' ;;
  esac
  write_output digest "${registry_digest}"
  write_output mode "${publish_mode}"
}

evidence() {
  local lookup
  local state
  local tag_digest
  local config_digest
  local normalized_image
  local actual_source_sha
  local actual_source_url
  local trailing
  : "${REGISTRY_DIGEST:?REGISTRY_DIGEST is required}"
  : "${PUBLISH_MODE:?PUBLISH_MODE is required}"
  : "${EVIDENCE_PATH:?EVIDENCE_PATH is required}"
  case "${PUBLISH_MODE}" in
    created|reused) ;;
    *) fail 'invalid immutable admin publish mode' ;;
  esac
  require_sha256 "${REGISTRY_DIGEST}" 'registry digest'
  lookup="$(ghcr_manifest_lookup "${IMAGE_REPOSITORY}" "${SOURCE_SHA}")" || \
    fail 'unable to re-inspect immutable admin tag'
  read -r state tag_digest trailing <<<"${lookup}"
  test -z "${trailing:-}" || fail 'immutable admin lookup has extra fields'
  test "${state}" = 'present' || fail 'immutable admin tag disappeared'
  test "${tag_digest}" = "${REGISTRY_DIGEST}" || \
    fail 'immutable admin tag digest changed after bind'
  config_digest="$(resolve_linux_amd64_config "${tag_digest}")"
  validate_remote_identity "${tag_digest}"
  normalized_image="$(remote_image "${tag_digest}")"
  actual_source_sha="$(
    jq -er '.config.Labels["org.opencontainers.image.revision"]' \
      <<<"${normalized_image}"
  )"
  actual_source_url="$(
    jq -er '.config.Labels["org.opencontainers.image.source"]' \
      <<<"${normalized_image}"
  )"
  test "${actual_source_sha}" = "${SOURCE_SHA}"
  test "${actual_source_url}" = "${SOURCE_URL}"
  jq -n \
    --arg source_sha "${actual_source_sha}" \
    --arg image_repository "${IMAGE_REPOSITORY}" \
    --arg image_tag "${SOURCE_SHA}" \
    --arg image_digest "${tag_digest}" \
    --arg image_config_digest "${config_digest}" \
    --arg source_url "${actual_source_url}" \
    --arg publish_mode "${PUBLISH_MODE}" '{
      schema_version: "mission-spine.admin-artifact.v1",
      source_sha: $source_sha,
      image_repository: $image_repository,
      image_tag: $image_tag,
      image_digest: $image_digest,
      image_config_digest: $image_config_digest,
      publish_mode: $publish_mode,
      image_labels: {
        "org.opencontainers.image.revision": $source_sha,
        "org.opencontainers.image.source": $source_url
      }
    }' >"${EVIDENCE_PATH}"
  jq -e '
    (keys | sort) == [
      "image_config_digest", "image_digest", "image_labels",
      "image_repository", "image_tag", "publish_mode",
      "schema_version", "source_sha"
    ] and
    (.image_labels | keys | sort) == [
      "org.opencontainers.image.revision",
      "org.opencontainers.image.source"
    ] and
    (.image_digest | test("^sha256:[0-9a-f]{64}$")) and
    (.image_config_digest | test("^sha256:[0-9a-f]{64}$"))
  ' "${EVIDENCE_PATH}" >/dev/null
}

main() {
  : "${SOURCE_SHA:?SOURCE_SHA is required}"
  require_source_sha "${SOURCE_SHA}"
  readonly TAG_REFERENCE="${IMAGE_REPOSITORY}:${SOURCE_SHA}"
  readonly CANDIDATE_REFERENCE="leva-admin-candidate:${SOURCE_SHA}"
  case "${1:-}" in
    preflight) preflight ;;
    candidate) candidate ;;
    bind) bind ;;
    evidence) evidence ;;
    *) fail 'usage: admin_immutable_image.sh preflight|candidate|bind|evidence' ;;
  esac
}

main "$@"
