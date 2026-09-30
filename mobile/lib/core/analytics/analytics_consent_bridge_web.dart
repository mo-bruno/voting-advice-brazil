import 'dart:js_interop';

@JS('farolSetAnalyticsConsent')
external void _farolSetAnalyticsConsent(JSBoolean granted);

bool setWebAnalyticsConsent({required bool granted}) {
  try {
    _farolSetAnalyticsConsent(granted.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
