/// Repo the in-app updater reads from (override with
/// `--dart-define=UPDATE_REPO=owner/name` when testing a fork).
const updateRepo = String.fromEnvironment('UPDATE_REPO', defaultValue: 'mounsokdara/Khmer-Calendar.Dev');

/// version.txt in that repo is the single source of truth for the latest version name.
const updateVersionFileUrl = 'https://raw.githubusercontent.com/$updateRepo/main/version.txt';

String updateReleasePageUrl(String versionName) =>
    'https://github.com/$updateRepo/releases/tag/v$versionName';

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
    required this.isNewer,
    this.updaterName = '',
    this.updaterUrl = '',
  });

  /// From the release tag / version.txt, e.g. `1.0.5`.
  final String versionName;

  /// Android: `arm64`, `arm32`, `x64`, `arm32_64` or `universal`. Desktop: `x64`, `arm64` (macOS also `x86_64`).
  final String package;
  final String assetName;
  final String url;

  /// Bytes (0 when GitHub did not say).
  final int size;

  /// When the asset finished uploading.
  final DateTime builtAt;

  /// Short commit id taken from the release title, `''` when it cannot be read.
  final String sha;

  /// True when this build is newer than what is installed.
  final bool isNewer;

  /// Desktop only: small updater program (separate release asset preferred).
  /// e.g. `update-windows-x64.exe`, `update-linux-x64`, `update-macos.sh`.
  final String updaterName;

  /// Direct download URL for [updaterName]. Empty on older releases that only
  /// shipped the updater inside the package (then the app extracts it).
  final String updaterUrl;
}

enum UpdateInstallResult {
  /// The system installer is on screen (or the desktop updater was started).
  started,

  /// "Install unknown apps" has to be allowed for this app first (its settings page was opened).
  needsPermission,

  /// Desktop: the folder the app lives in cannot be written (for example Program Files).
  notWritable,
  failed,
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raised when the person taps Cancel while a download runs.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}
