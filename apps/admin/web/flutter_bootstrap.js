// Flutter's CanvasKit backend always requests an unqualified Roboto default
// when the FontManifest does not declare one. ET13 evidence routes run with
// network disabled, so point that fallback at the already packaged and
// hash-pinned Pretendard regular face. The query suffix absorbs CanvasKit's
// fixed "roboto/v32/..." suffix while preserving the local asset URL.
{{flutter_js}}
{{flutter_build_config}}

const et13EvidenceRoute =
  new URLSearchParams(window.location.search).has('fixture');
const et13EngineConfig = et13EvidenceRoute
  ? {
      fontFallbackBaseUrl:
        'assets/packages/dp_design/fonts/Pretendard-Regular.otf?',
    }
  : {};

_flutter.loader.load({
  config: et13EngineConfig,
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
