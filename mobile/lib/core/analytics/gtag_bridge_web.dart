import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void logGtagEvent({
  required String name,
  Map<String, Object>? parameters,
}) {
  final gtag = globalContext.getProperty<JSAny?>('gtag'.toJS);
  if (gtag == null) {
    return;
  }

  final payload = <String, Object>{...?parameters};
  final debug =
      globalContext.getProperty<JSBoolean?>('farolAnalyticsDebug'.toJS);
  if (debug?.toDart == true) {
    payload['debug_mode'] = true;
  }

  globalContext.callMethod<JSAny?>(
    'gtag'.toJS,
    'event'.toJS,
    name.toJS,
    payload.jsify() as JSAny,
  );
}
