import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart' show appVersion;
import '../../web_refresh.dart';

const currentAppVersion = appVersion;
const latestReleaseUrl = 'https://github.com/mounsokdara/Khmer-Calendar/releases/latest';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});
  final String version;
  final String url;
}

Future<UpdateInfo?> checkForAppUpdate() async {
  final response = await http.get(
    Uri.parse('https://api.github.com/repos/mounsokdara/Khmer-Calendar/releases/latest'),
    headers: const {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body);
  if (data is! Map) return null;
  final tag = data['tag_name']?.toString().trim() ?? '';
  final url = data['html_url']?.toString().trim();
  if (tag.isEmpty || url == null || url.isEmpty) return null;
  final latest = tag.replaceFirst(RegExp(r'^v'), '');
  if (_compareVersions(latest, currentAppVersion) <= 0) return null;
  return UpdateInfo(version: latest, url: url);
}

/// Web: compares against the version deployed on the site itself (no GitHub involved).
Future<UpdateInfo?> checkForWebUpdate() async {
  final deployed = await deployedWebVersion();
  if (deployed == null || deployed.isEmpty) return null;
  if (_compareVersions(deployed, currentAppVersion) <= 0) return null;
  return UpdateInfo(version: deployed, url: '');
}

int _compareVersions(String a, String b) {
  final aa = _parts(a);
  final bb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final c = aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  return 0;
}

List<int> _parts(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(value);
  if (match == null) return const [0, 0, 0];
  return [
    int.tryParse(match.group(1) ?? '') ?? 0,
    int.tryParse(match.group(2) ?? '') ?? 0,
    int.tryParse(match.group(3) ?? '') ?? 0,
  ];
}

Future<bool> openLatestRelease([String? url]) {
  return launchUrl(
    Uri.parse(url ?? latestReleaseUrl),
    mode: LaunchMode.externalApplication,
  );
}
