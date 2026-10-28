/// Repo + pre-release the dev builds are published to by `.github/workflows/android.yml`
/// (override with `--dart-define=DEV_UPDATE_REPO=owner/name` when testing a fork).
const devUpdateRepo = String.fromEnvironment('DEV_UPDATE_REPO', defaultValue: 'mounsokdara/Khmer-Calendar.Dev');
const devUpdateTag = 'dev-latest';
const devReleasePageUrl = 'https://github.com/$devUpdateRepo/releases/tag/$devUpdateTag';

/// One downloadable dev build, already narrowed down to the package that fits this device.
class DevBuild {
  const DevBuild({
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

  /// Android: `arm64`, `arm32`, `x64`, `arm32_64` or `universal`. Desktop: `x64`, `arm64` (macOS also `x86_64`).
  final String package;
  final String assetName;
  final String url;

  /// Bytes (0 when GitHub did not say).
  final int size;

  /// When the asset finished uploading, i.e. when this build was made.
  final DateTime builtAt;

  /// Short commit id taken from the release title, `''` when it cannot be read.
  final String sha;

  /// True when this build was made after the installed one.
  final bool isNewer;

  /// Desktop only: the small updater program (update.exe on Windows) that swaps the files after the app quits.
  final String updaterName;
  final String updaterUrl;
}

enum DevInstallResult {
  /// The system installer is on screen.
  started,

  /// "Install unknown apps" has to be allowed for this app first (its settings page was opened).
  needsPermission,

  /// Desktop: the folder the app lives in cannot be written (for example Program Files).
  notWritable,
  failed,
}

class DevUpdateException implements Exception {
  const DevUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Raised when the person taps Cancel while a download runs.
class DevUpdateCancelled implements Exception {
  const DevUpdateCancelled();
}
