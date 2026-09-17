// Flutter's CanvasKit backend always requests an unqualified Roboto default
// when the FontManifest does not declare one. ET13 evidence routes run with
// network disabled, so point that fallback at the already packaged and
// hash-pinned Pretendard regular face. The query suffix absorbs CanvasKit's
// fixed "roboto/v32/..." suffix while preserving the local asset URL.
{{flutter_js}}
{{flutter_build_config}}

const et13EvidenceRoute =
  new URLSearchParams(window.location.search).has('fixture');
// Full-page embedding replaces the author viewport with user-scalable=no,
// which blocks browser zoom (axe meta-viewport, WCAG 1.4.4). Every route —
// the ET13 projection and the application itself — therefore uses Flutter's
// supported custom-host embedding so browser zoom and text scaling keep working.
const et13HostElement = document.createElement('div');
et13HostElement.id = et13EvidenceRoute ? 'et13-flutter-host' : 'leva-flutter-host';
et13HostElement.style.position = 'fixed';
et13HostElement.style.inset = '0';
et13HostElement.style.overflow = 'hidden';
document.body.appendChild(et13HostElement);
const et13EngineConfig = et13EvidenceRoute
  ? {
      fontFallbackBaseUrl:
        'assets/packages/dp_design/fonts/Pretendard-Regular.otf?',
      hostElement: et13HostElement,
    }
  : { hostElement: et13HostElement };

_flutter.loader.load({
  config: et13EngineConfig,
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
