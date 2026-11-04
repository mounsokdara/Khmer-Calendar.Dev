import 'dart:js_interop';

// Implemented in web/index.html (window.__khmerStorage). Both resolve to the byte count as a string.
@JS('__khmerStorage.cacheBytes')
external JSPromise<JSAny?> _cacheBytes();

@JS('__khmerStorage.clearCache')
external JSPromise<JSAny?> _clearCache();

int _parse(JSAny? v) {
  try {
    if (v == null) return 0;
    return int.tryParse((v as JSString).toDart) ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Size of everything the browser cached for this site (service worker Cache Storage).
Future<int> cacheBytes() async {
  try {
    return _parse(await _cacheBytes().toDart);
  } catch (_) {
    return 0;
  }
}

/// Deletes the Cache Storage entries. Settings and reminders live in localStorage and are not touched.
Future<int> clearCacheFiles() async {
  try {
    return _parse(await _clearCache().toDart);
  } catch (_) {
    return 0;
  }
}

/// On the web the custom sound is kept in localStorage, which the data size already counts.
Future<int> userFilesBytes() async => 0;
