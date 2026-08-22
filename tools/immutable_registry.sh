#!/usr/bin/env bash

# Shared wrapper: credentials stay in the environment and are consumed by the
# Node HTTPS client in memory. No token is placed in argv or output.
readonly IMMUTABLE_REGISTRY_TOOL_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
)"

ghcr_manifest_lookup() {
  local image_repository="$1"
  local image_tag="$2"
  IMAGE_REPOSITORY="${image_repository}" \
    IMAGE_TAG="${image_tag}" \
    node "${IMMUTABLE_REGISTRY_TOOL_ROOT}/immutable_registry.mjs" lookup
}
