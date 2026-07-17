# ---- build stage: Flutter Web ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=https://api.leva.ai.kr/api/v1
ARG USE_MOCK=false

WORKDIR /src
# 워크스페이스 전체 복사(Dart pub workspaces 단일 해석에 전 멤버 필요)
COPY . .

# cirruslabs/flutter:stable ships Flutter 3.44.0/Dart 3.12.0; pubspec requires ^3.12.1 (로컬 dev=Flutter 3.44.1/Dart 3.12.1).
# 이미지 내 Flutter가 detached-HEAD([user-branch])이라 flutter upgrade 불가 → 3.44.1 tarball로 직접 교체.
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.1-stable.tar.xz \
    | tar -xJ --strip-components=1 -C /sdks/flutter \
 && git config --global --add safe.directory /sdks/flutter \
 && flutter --version

# melos 부트스트랩(CI와 동일한 흐름) — pub-cache/bin을 PATH에 추가
ENV PATH="/root/.pub-cache/bin:${PATH}"
RUN dart pub global activate melos 7.0.0 \
 && melos bootstrap

# 실 API 설정을 빌드시 각인(Flutter Web은 런타임 주입 불가)
RUN cd apps/web \
 && flutter build web --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=USE_MOCK=${USE_MOCK}

# ---- runtime stage: nginx ----
FROM nginx:alpine AS runtime
COPY --from=build /src/apps/web/build/web /usr/share/nginx/html
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
