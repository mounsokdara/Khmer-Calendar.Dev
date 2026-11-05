/// Repo the in-app updater reads from (override with
/// `--dart-define=UPDATE_REPO=owner/name` when testing a fork).
const updateRepo = String.fromEnvironment('UPDATE_REPO', defaultValue: 'mounsokdara/Khmer-Calendar.Dev');

/// version.txt in that repo is the single source of truth for the latest version name.
const updateVersionFileUrl = 'https://raw.githubusercontent.com/$updateRepo/main/version.txt';

String updateReleasePageUrl(String versionName) =>
    'https://github.com/$updateRepo/releases/tag/v$versionName';

/// How the published build compares with the app that is running.
enum UpdateKind {
  /// version name or build number is higher than the installed one
  newerVersion,

  /// same version, but a newer build of it was published after this one was installed
  newerBuild,

  /// nothing newer
  upToDate,

  /// the installed app is newer than the published release
  aheadOfRelease,
}

/// One downloadable build, already narrowed down to the package that fits this device.
class UpdateBuild {
  const UpdateBuild({
    required this.versionName,
    required this.package,
    required this.assetName,
    required this.url,
    required this.size,
    required this.builtAt,
    required this.sha,
    required this.kind,
    this.installedVersion = '',
    this.remoteBuildNumber,
    this.updaterName = '',
    this.updaterUrl = '',
  });

  final String versionName;
  final String package;
  final String assetName;
  final String url;
  final int size;
  final DateTime builtAt;
  final String sha;
  final UpdateKind kind;

  /// Version of the app that is running now (for the "1.0.4 -> 1.0.5" text).
  final String installedVersion;

  /// versionCode from version.txt, when present.
  final int? remoteBuildNumber;

  /// True only when there really is something newer to install.
  bool get isNewer => kind == UpdateKind.newerVersion || kind == UpdateKind.newerBuild;

  /// Desktop only: updater file name inside the package archive.
  /// Windows: `update-windows.exe`, Linux: `update-linux-x64`, macOS: `update-macos.sh`.
  final String updaterName;

  /// Unused: updater is always taken from the package (kept for API stability).
  final String updaterUrl;
}

enum UpdateInstallResult {
  started,
  needsPermission,
  notWritable,
  failed,
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Written by the desktop updater when it could not finish; shown once on the next start.
class UpdateFailure {
  const UpdateFailure({required this.reason, this.files = const [], this.processes = const [], this.detail = ''});

  /// `locked` = another program was using the app files, `error` = anything else.
  final String reason;
  final List<String> files;
  final List<String> processes;
  final String detail;

  bool get isLocked => reason == 'locked';
}

/// Another running copy of the app (it keeps the app files locked and blocks an update).
class AppInstance {
  const AppInstance(this.name, this.id);
  final String name;
  final int id;
  @override
  String toString() => '$name ($id)';
}
