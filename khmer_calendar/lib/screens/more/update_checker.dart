import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart' show appBuildNumber, appVersion;
import '../../web_refresh.dart';

const currentAppVersion = appVersion;
const latestReleaseUrl = 'https://github.com/mounsokdara/Khmer-Calendar/releases/latest';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});
  final String version;
  final String url;
}

/// version.txt in the repo is the single source of truth for the latest version:
/// two plain lines, `versionName=1.0.4` and `versionCode=5` (no JSON, no GitHub API rate limit).
const versionFileUrl = 'https://raw.githubusercontent.com/mounsokdara/Khmer-Calendar/main/version.txt';

/// Reads `versionName` out of the text of a version.txt, or null if it is missing.
String? parseVersionName(String text) {
  final m = RegExp(r'^\s*versionName\s*=\s*(\S+)\s*$', multiLine: true).firstMatch(text);
  return m?.group(1);
}

Future<UpdateInfo?> checkForAppUpdate() async {
  final response = await http
      .get(Uri.parse('$versionFileUrl?cb=${DateTime.now().millisecondsSinceEpoch}'))
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return null;
  final latest = parseVersionName(response.body);
  if (latest == null) return null;
  final c = _compareVersions(latest, currentAppVersion);
  if (c < 0) return null;
  if (c == 0) {
    // Same version name: only a higher build number (versionCode) counts as an update.
    final code = _parseVersionCode(response.body);
    if (code == null || code <= appBuildNumber) return null;
  }
  return UpdateInfo(version: latest, url: latestReleaseUrl);
}

/// Web: compares against the version deployed on the site itself (no GitHub involved).
Future<UpdateInfo?> checkForWebUpdate() async {
  final deployed = await deployedWebVersion();
  if (deployed == null || deployed.isEmpty) return null;
  if (_compareVersions(deployed, currentAppVersion) <= 0) return null;
  return UpdateInfo(version: deployed, url: '');
}

int? _parseVersionCode(String text) {
  final m = RegExp(r'^\s*versionCode\s*=\s*(\d+)\s*$', multiLine: true).firstMatch(text);
  return m == null ? null : int.tryParse(m.group(1)!);
}

int _compareVersions(String a, String b) {
  final aa = _parts(a);
  final bb = _parts(b);
  for (var i = 0; i < 4; i++) {
    final c = aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  return 0;
}

List<int> _parts(String value) {
  final match = RegExp(r'^\s*v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?').firstMatch(value);
  if (match == null) return const [0, 0, 0, 0];
  return [for (var i = 1; i <= 4; i++) int.tryParse(match.group(i) ?? '') ?? 0];
}

Future<bool> openLatestRelease([String? url]) {
  return launchUrl(
    Uri.parse(url ?? latestReleaseUrl),
    mode: LaunchMode.externalApplication,
  );
}
