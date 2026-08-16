# ---- build stage: Flutter Web ----
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build

ARG API_BASE_URL=https://api.leva.ai.kr
ARG USE_MOCK=false
ENV FLUTTER_VERSION=3.44.1 \
    FLUTTER_REVISION=924134a44c189315be2148659913dda1671cbe99 \
    DART_VERSION=3.12.1 \
    FLUTTER_ARCHIVE_SHA256=287937458126a53284ed112c8c7dbc647bea2d09ab65d46e2d5cf94e901aac69

WORKDIR /src
# 워크스페이스 전체 복사(Dart pub workspaces 단일 해석에 전 멤버 필요)
COPY . .

# The pinned base supplies OS tools. Replace its SDK with the separately
# checksum-locked release tuple used by CI and the workspace lock.
RUN archive="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && curl -fsSL --retry 3 --output "${archive}" \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && printf '%s  %s\n' "${FLUTTER_ARCHIVE_SHA256}" "${archive}" | sha256sum -c - \
 && rm -rf /sdks/flutter \
 && mkdir -p /sdks/flutter \
 && tar -xJ --strip-components=1 -C /sdks/flutter -f "${archive}" \
 && rm -f "${archive}" \
 && git config --global --add safe.directory /sdks/flutter \
 && flutter --version --machine > /tmp/flutter-version.json \
 && grep -F "\"frameworkVersion\": \"${FLUTTER_VERSION}\"" /tmp/flutter-version.json \
 && grep -F "\"frameworkRevision\": \"${FLUTTER_REVISION}\"" /tmp/flutter-version.json \
 && grep -F "\"dartSdkVersion\": \"${DART_VERSION}\"" /tmp/flutter-version.json \
 && rm -f /tmp/flutter-version.json

# Resolve only the committed workspace lock and invoke its Melos 7.8.1.
RUN lock_sha256_before="$(sha256sum pubspec.lock | awk '{print $1}')" \
 && dart pub get --enforce-lockfile \
 && dart run melos bootstrap --enforce-lockfile \
 && test "$(sha256sum pubspec.lock | awk '{print $1}')" = "${lock_sha256_before}"

# 실 API 설정을 빌드시 각인(Flutter Web은 런타임 주입 불가)
RUN cd apps/admin \
 && flutter build web --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=USE_MOCK=${USE_MOCK}

# ---- runtime stage: nginx ----
FROM --platform=linux/amd64 nginx:alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752 AS runtime
COPY --from=build /src/apps/admin/build/web /usr/share/nginx/html
COPY apps/admin/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
