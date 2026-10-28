import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'dev_update_types.dart';

const _channel = MethodChannel('khmer.permissions');

/// Android builds that are not the F-Droid build (F-Droid updates the app itself).
final bool devUpdateSupported = Platform.isAndroid && !const bool.fromEnvironment('FDROID');

// Last digit of the Android versionCode says which package is installed (see build.gradle.kts).
const _packageByDigit = <int, String>{0: 'universal', 1: 'arm32', 2: 'arm64', 3: 'x64', 4: 'arm32_64'};

const _headers = {
  'Accept': 'application/vnd.github+json',
  'User-Agent': 'khmer-calendar-dev-updater',
};

/// Looks up the newest dev build for this device. Returns null when the pre-release has no APK for it
/// (for example while CI is still uploading). `isNewer` says whether it is newer than what is installed.
Future<DevBuild?> fetchDevBuild() async {
  final info = await _channel.invokeMapMethod<String, dynamic>('installInfo');
  if (info == null) throw const DevUpdateException('Cannot read the installed version');
  final versionCode = (info['versionCode'] as num).toInt();
  final installedAt = DateTime.fromMillisecondsSinceEpoch((info['installedAt'] as num).toInt(), isUtc: true);

  // Same package type as the installed one: a different ABI split has another version code and could be
  // refused as a downgrade. Unknown digit (e.g. a custom build): fall back to universal.
  final package = _packageByDigit[versionCode % 10] ?? 'universal';
  final assetName = 'KhmerCalendar-$package.apk';

  final res = await http
      .get(Uri.parse('https://api.github.com/repos/$devUpdateRepo/releases/tags/$devUpdateTag'), headers: _headers)
      .timeout(const Duration(seconds: 12));
  if (res.statusCode == 404) return null; // no dev-latest release (yet)
  if (res.statusCode != 200) throw DevUpdateException('GitHub answered ${res.statusCode}');

  final release = jsonDecode(res.body) as Map<String, dynamic>;
  final assets = (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final asset = assets.where((a) => a['name'] == assetName && a['state'] == 'uploaded').firstOrNull;
  if (asset == null) return null;

  final builtAt = DateTime.parse(asset['updated_at'] as String).toUtc();
  final sha = RegExp(r'\(([0-9a-fA-F]{7,40})\)').firstMatch('${release['name'] ?? ''}')?.group(1) ?? '';
  return DevBuild(
    package: package,
    assetName: assetName,
    url: asset['browser_download_url'] as String,
    size: (asset['size'] as num?)?.toInt() ?? 0,
    builtAt: builtAt,
    sha: sha,
    isNewer: builtAt.isAfter(installedAt),
  );
}

/// Downloads [build] into the app's private cache and returns the file path.
Future<String> downloadDevBuild(
  DevBuild build,
  void Function(int received, int total) onProgress, {
  bool Function()? isCancelled,
}) async {
  final info = await _channel.invokeMapMethod<String, dynamic>('installInfo');
  final dirPath = info?['updatesDir'] as String?;
  if (dirPath == null) throw const DevUpdateException('No download folder');

  final dir = Directory(dirPath);
  if (dir.existsSync()) dir.deleteSync(recursive: true); // drop leftovers of earlier downloads
  dir.createSync(recursive: true);
  final target = File('${dir.path}/${build.assetName}');
  final part = File('${target.path}.part');

  final client = http.Client();
  IOSink? sink;
  try {
    final response = await client.send(http.Request('GET', Uri.parse(build.url))..headers.addAll(_headers))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw DevUpdateException('Download failed (${response.statusCode})');

    final total = response.contentLength ?? build.size;
    var received = 0;
    sink = part.openWrite();
    await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
      if (isCancelled?.call() ?? false) throw const DevUpdateCancelled();
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, total);
    }
    await sink.flush();
    await sink.close();
    sink = null;

    if (build.size > 0 && received != build.size) {
      throw const DevUpdateException('Download incomplete, please try again');
    }
    await part.rename(target.path);
    return target.path;
  } catch (_) {
    try {
      await sink?.close();
    } catch (_) {}
    if (part.existsSync()) part.deleteSync();
    rethrow;
  } finally {
    client.close();
  }
}

/// Opens the system installer for a downloaded APK. Android only installs it when it is signed with the same
/// key as the running app, so a tampered download is rejected by the system.
Future<DevInstallResult> installDevBuild(String path) async {
  try {
    final r = await _channel.invokeMethod<String>('installApk', {'path': path});
    switch (r) {
      case 'started':
        return DevInstallResult.started;
      case 'permission':
        return DevInstallResult.needsPermission;
      default:
        return DevInstallResult.failed;
    }
  } on PlatformException {
    return DevInstallResult.failed;
  }
}
