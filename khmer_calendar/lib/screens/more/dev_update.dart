// In-app updater: reads version.txt, fetches the matching release tag (vX.Y.Z), downloads the package
// for this device and installs it without opening a browser.
export 'dev_update_types.dart';
export 'dev_update_stub.dart' if (dart.library.io) 'dev_update_io.dart';
