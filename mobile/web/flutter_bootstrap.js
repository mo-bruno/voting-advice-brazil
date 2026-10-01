{{flutter_js}}
{{flutter_build_config}}

// An absolute same-origin URL also remains correct if Flutter switches its
// renderer or the site is deployed below a non-root base path.
const fontFallbackBaseUrl =
    new URL('font-fallbacks/', document.baseURI).href;

_flutter.loader.load({
  config: {fontFallbackBaseUrl},
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
