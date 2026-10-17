/// Version of the app currently deployed on the website (null off the web or when unreachable).
Future<String?> deployedWebVersion() async => null;

/// Web only: clears cached files and service workers, downloads the app again and reloads.
Future<void> cleanAndReloadWeb() async {}
