// Measures and clears the files this app can safely rebuild (its "cache"), per platform:
//   io (Android, iOS, Windows, macOS, Linux): app cache folders on disk
//   web: Cache Storage used by the service worker
export 'storage_usage_stub.dart'
    if (dart.library.js_interop) 'storage_usage_web.dart'
    if (dart.library.io) 'storage_usage_io.dart';
