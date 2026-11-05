import 'dev_update_types.dart';

/// Web and platforms without an in-app installer.
const bool inAppUpdateSupported = false;

Future<UpdateBuild?> fetchUpdateBuild() async => null;

Future<String> downloadUpdateBuild(UpdateBuild build, void Function(int received, int total) onProgress,
        {bool Function()? isCancelled}) async =>
    throw const UpdateException('Not supported on this platform');

Future<UpdateInstallResult> installUpdateBuild(String path, UpdateBuild build) async => UpdateInstallResult.failed;

/// True when installing closes the app and the updater restarts it (desktop).
const bool updateRestartsApp = false;

Future<void> finishUpdateInstall() async {}

Future<UpdateFailure?> takeUpdateFailure() async => null;

Future<List<String>> otherAppInstances() async => const [];
