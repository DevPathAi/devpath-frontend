// Flutter's CanvasKit backend always requests an unqualified Roboto default
// when the FontManifest does not declare one. ET13 evidence routes run with
// network disabled, so point that fallback at the already packaged and
// hash-pinned Pretendard regular face. The query suffix absorbs CanvasKit's
// fixed "roboto/v32/..." suffix while preserving the local asset URL.
{{flutter_js}}
{{flutter_build_config}}

const et13EvidenceRoute =
  new URLSearchParams(window.location.search).has('fixture');
// Full-page embedding replaces the author viewport with user-scalable=no.
// The explicitly labeled ET13 projection uses Flutter's supported custom-host
// embedding so automated accessibility exercises browser zoom/text scaling;
// normal application routes retain their existing full-page behavior.
const et13HostElement = et13EvidenceRoute
  ? document.createElement('div')
  : null;
if (et13HostElement !== null) {
  et13HostElement.id = 'et13-flutter-host';
  et13HostElement.style.position = 'fixed';
  et13HostElement.style.inset = '0';
  et13HostElement.style.overflow = 'hidden';
  document.body.appendChild(et13HostElement);
}
const et13EngineConfig = et13EvidenceRoute
  ? {
      fontFallbackBaseUrl:
        'assets/packages/dp_design/fonts/Pretendard-Regular.otf?',
      hostElement: et13HostElement,
    }
  : {};

_flutter.loader.load({
  config: et13EngineConfig,
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
