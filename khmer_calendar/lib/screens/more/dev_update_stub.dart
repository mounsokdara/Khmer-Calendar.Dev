import 'dev_update_types.dart';

/// Web and platforms without an in-app installer.
const bool devUpdateSupported = false;

Future<DevBuild?> fetchDevBuild() async => null;

Future<String> downloadDevBuild(DevBuild build, void Function(int received, int total) onProgress,
        {bool Function()? isCancelled}) async =>
    throw const DevUpdateException('Not supported on this platform');

Future<DevInstallResult> installDevBuild(String path) async => DevInstallResult.failed;
