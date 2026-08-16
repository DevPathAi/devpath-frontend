# ET13 frontend reproducibility preflight

This document records the immutable inputs used by the existing ET10 web and
admin release lanes. It does not define ET13 visual cases, golden names, or
baseline approval.

## Locked build inputs

- GitHub Actions use reviewed 40-character commit SHAs. The ordered action map
  and occurrence counts are enforced by
  `apps/web/test/app/frontend_reproducibility_contract_test.dart`.
- Linux jobs use `ubuntu-24.04`, not the migrating `ubuntu-latest` alias. The
  hosted image can still receive weekly updates, so its image version remains
  provenance rather than a canonical visual renderer.
- Docker Buildx is `v0.34.1`; its daemon is
  `moby/buildkit:v0.30.0@sha256:0168606be2315b7c807a03b3d8aa79beefdb31c98740cebdffdfeebf31190c9f`.
  Each image build is restricted to `linux/amd64`; setup-buildx receives only
  its documented version and driver options.
- The Flutter builder and nginx runtime are selected by multi-architecture
  index digest in both Dockerfiles. `linux/amd64` selection is explicit.
- Flutter is the exact tuple `3.44.1`, framework revision
  `924134a44c189315be2148659913dda1671cbe99`, Dart `3.12.1`, archive SHA-256
  `287937458126a53284ed112c8c7dbc647bea2d09ab65d46e2d5cf94e901aac69`.
  Docker downloads to a file, verifies the hash, then extracts it.
- Dependency resolution is fail-closed against `pubspec.lock`. CI and Docker
  run `dart pub get --enforce-lockfile` and
  `dart run melos bootstrap --enforce-lockfile`; global activation is forbidden,
  and bootstrap must leave `pubspec.lock` unchanged.
- Kustomize `v5.4.3` is verified with archive SHA-256
  `3669470b454d865c8184d6bce78df05e977c9aea31c30df3c669317d43bcc7a7`.
- The Android Gradle `9.1.0-all` distribution is verified with SHA-256
  `b84e04fa845fecba48551f425957641074fcc00a88a84d2aae5808743b35fc85`.
  The mobile workflow itself is outside this change.

## Release semantics

The ET10 artifact names, OFF/ON image identities, immutable registry binding,
sanitized evidence schema, admin image tags, and GitOps mutation flow are
unchanged. Pin updates must preserve those existing contract tests.

Hosted runner labels alone are not sufficient for pixel evidence. ET13 visual
and automated accessibility evidence must execute the production distribution
in its separately approved digest-pinned browser/font/locale environment. CI
must compare approved baselines and must not update them.

## Current verification boundary

On 2026-08-16 the exact BuildKit `v0.30.0` daemon bootstrap and `linux/amd64`
selection were verified, but the full pinned Docker image build was stopped
because of host memory pressure. It is intentionally recorded as an unverified
external release gate and must run with sufficient capacity before release.
The green local Flutter production builds and contract tests do not substitute
for that container build.

## Updating a pin

1. Resolve the version from its official release source and record the full
   action commit SHA or image/archive digest.
2. Change the contract expectation first and observe the targeted RED failure.
3. Update the workflow or Dockerfile without changing artifact semantics.
4. Run the focused reproducibility contract, the full web test suite, workspace
   analysis/tests, and production web/admin builds.
5. Review action or image release notes and the resulting artifact provenance
   before accepting the new pin.
