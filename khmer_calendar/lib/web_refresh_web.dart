import 'dart:js_interop';

@JS('__khmerRefresh.deployedVersion')
external JSPromise<JSAny?> _deployedVersion();

@JS('__khmerRefresh.cleanAndReload')
external JSPromise<JSAny?> _cleanAndReload();

/// Version of the app currently deployed on the website (null when unreachable).
Future<String?> deployedWebVersion() async {
  try {
    final v = await _deployedVersion().toDart;
    return v == null ? null : (v as JSString).toDart;
  } catch (_) {
    return null;
  }
}

/// Clears cached files and service workers, downloads the app again and reloads the page.
Future<void> cleanAndReloadWeb() async {
  try {
    await _cleanAndReload().toDart;
  } catch (_) {}
}
