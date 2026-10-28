// In-app updater for DEV builds (this repo's `dev-latest` pre-release): downloads the APK that matches the
// installed package inside the app and hands it to the system installer, so nobody has to open GitHub.
// Android only; every other platform (and the web) reports `devUpdateSupported == false`.
export 'dev_update_types.dart';
export 'dev_update_stub.dart' if (dart.library.io) 'dev_update_io.dart';
