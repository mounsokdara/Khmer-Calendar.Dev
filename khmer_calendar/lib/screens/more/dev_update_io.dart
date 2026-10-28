import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'device_arch.dart';
import 'dev_update_types.dart';

const _channel = MethodChannel('khmer.permissions');

/// Android (not the F-Droid build, F-Droid updates the app itself) and the three desktop systems.
final bool devUpdateSupported =
    (Platform.isAndroid && !const bool.fromEnvironment('FDROID')) ||
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS;

/// Desktop: installing closes the app; the updater program swaps the files and starts it again.
final bool devUpdateRestartsApp = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

// Last digit of the Android versionCode says which package is installed (see build.gradle.kts).
const _packageByDigit = <int, String>{0: 'universal', 1: 'arm32', 2: 'arm64', 3: 'x64', 4: 'arm32_64'};

const _headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'khmer-calendar-dev-updater'};

/// Looks up the newest dev build for this device. Returns null when the pre-release has no package for it
/// (for example while CI is still uploading). `isNewer` says whether it is newer than what is installed.
Future<DevBuild?> fetchDevBuild() async {
  // Names of the files CI puts into the `dev-latest` pre-release (android.yml and desktop-dev.yml).
  late final String package;
  late final String assetName;
  var updaterName = '';
  DateTime? installedAt;

  if (Platform.isAndroid) {
    final info = await _channel.invokeMapMethod<String, dynamic>('installInfo');
    if (info == null) throw const DevUpdateException('Cannot read the installed version');
    final versionCode = (info['versionCode'] as num).toInt();
    installedAt = DateTime.fromMillisecondsSinceEpoch((info['installedAt'] as num).toInt(), isUtc: true);
    // Same package type as the installed one: a different ABI split has another version code and could be
    // refused as a downgrade. Unknown digit (e.g. a custom build): fall back to universal.
    package = _packageByDigit[versionCode % 10] ?? 'universal';
    assetName = 'KhmerCalendar-$package.apk';
  } else {
    final arch = deviceArch(); // arm64 | x64 | arm32 | null
    if (Platform.isWindows) {
      if (arch != 'x64' && arch != 'arm64') return null;
      package = arch!;
      assetName = 'KhmerCalendar-windows-$arch.zip';
      updaterName = 'update-windows.exe';
    } else if (Platform.isLinux) {
      if (arch != 'x64' && arch != 'arm64') return null;
      package = arch!;
      assetName = 'KhmerCalendar-linux-$arch.tar.gz';
      updaterName = 'update-linux-$arch';
    } else {
      package = arch == 'x64' ? 'x86_64' : (arch == 'arm64' ? 'arm64' : 'universal');
      assetName = 'KhmerCalendar-macos-$package.dmg';
      updaterName = 'update-macos.sh';
    }
    installedAt = await _readStamp(); // null: unknown build (never updated by this updater)
  }

  final res = await http
      .get(Uri.parse('https://api.github.com/repos/$devUpdateRepo/releases/tags/$devUpdateTag'), headers: _headers)
      .timeout(const Duration(seconds: 12));
  if (res.statusCode == 404) return null; // no dev-latest release (yet)
  if (res.statusCode != 200) throw DevUpdateException('GitHub answered ${res.statusCode}');

  final release = jsonDecode(res.body) as Map<String, dynamic>;
  final assets = (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? find(String name) =>
      assets.where((a) => a['name'] == name && a['state'] == 'uploaded').firstOrNull;

  final asset = find(assetName);
  if (asset == null) return null;
  final updater = updaterName.isEmpty ? null : find(updaterName);
  if (updaterName.isNotEmpty && updater == null) return null; // package without its updater: not installable yet

  final builtAt = DateTime.parse(asset['updated_at'] as String).toUtc();
  final sha = RegExp(r'\(([0-9a-fA-F]{7,40})\)').firstMatch('${release['name'] ?? ''}')?.group(1) ?? '';
  return DevBuild(
    package: package,
    assetName: assetName,
    url: asset['browser_download_url'] as String,
    size: (asset['size'] as num?)?.toInt() ?? 0,
    builtAt: builtAt,
    sha: sha,
    isNewer: installedAt == null || builtAt.isAfter(installedAt),
    updaterName: updaterName,
    updaterUrl: updater == null ? '' : updater['browser_download_url'] as String,
  );
}

// ---------- desktop: which dev build is installed ----------

/// The updater writes this file after a successful update (path is passed to it, see installDevBuild).
Future<File> _stampFile() async => File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}devbuild.json');

Future<DateTime?> _readStamp() async {
  try {
    final f = await _stampFile();
    if (!f.existsSync()) return null;
    final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return DateTime.tryParse('${json['builtAt']}')?.toUtc();
  } catch (_) {
    return null;
  }
}

// ---------- download ----------

Future<void> _fetchTo(
  String url,
  File target,
  int expectedSize,
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
) async {
  final part = File('${target.path}.part');
  final client = http.Client();
  IOSink? sink;
  try {
    final response = await client.send(http.Request('GET', Uri.parse(url))..headers.addAll(_headers)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw DevUpdateException('Download failed (${response.statusCode})');

    final total = response.contentLength ?? expectedSize;
    var received = 0;
    sink = part.openWrite();
    await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
      if (isCancelled?.call() ?? false) throw const DevUpdateCancelled();
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.flush();
    await sink.close();
    sink = null;

    if (expectedSize > 0 && received != expectedSize) {
      throw const DevUpdateException('Download incomplete, please try again');
    }
    await part.rename(target.path);
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

Future<Directory> _downloadDir() async {
  if (Platform.isAndroid) {
    final info = await _channel.invokeMapMethod<String, dynamic>('installInfo');
    final p = info?['updatesDir'] as String?;
    if (p == null) throw const DevUpdateException('No download folder');
    return Directory(p);
  }
  return Directory('${Directory.systemTemp.path}${Platform.pathSeparator}khmer_update_dl');
}

/// Downloads [build] (and, on desktop, its updater program) and returns the path of the package file.
Future<String> downloadDevBuild(
  DevBuild build,
  void Function(int received, int total) onProgress, {
  bool Function()? isCancelled,
}) async {
  final dir = await _downloadDir();
  if (dir.existsSync()) dir.deleteSync(recursive: true); // drop leftovers of earlier downloads
  dir.createSync(recursive: true);
  final sep = Platform.pathSeparator;

  if (build.updaterUrl.isNotEmpty) {
    final updater = File('${dir.path}$sep${build.updaterName}');
    await _fetchTo(build.updaterUrl, updater, 0, null, isCancelled);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', updater.path]);
  }
  final target = File('${dir.path}$sep${build.assetName}');
  await _fetchTo(build.url, target, build.size, onProgress, isCancelled);
  return target.path;
}

// ---------- install ----------

bool _writable(Directory d) {
  try {
    final probe = File('${d.path}${Platform.pathSeparator}.khmer_write_test');
    probe.writeAsStringSync('x');
    probe.deleteSync();
    return true;
  } catch (_) {
    return false;
  }
}

/// Android: opens the system installer for the downloaded APK (it only installs when signed with the same key
/// as the running app, so a tampered download is rejected by the system).
/// Desktop: starts the updater program, which waits for this app to quit, swaps the files and restarts it.
/// Call [finishDevInstall] after `started` on desktop to close the app.
Future<DevInstallResult> installDevBuild(String path, DevBuild build) async {
  if (Platform.isAndroid) {
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

  try {
    final exePath = Platform.resolvedExecutable;
    final sep = Platform.pathSeparator;
    final String target; // what the updater replaces: the app folder, or the .app bundle on macOS
    final String exeName;
    if (Platform.isMacOS) {
      // <X>.app/Contents/MacOS/<exe>  ->  <X>.app
      target = File(exePath).parent.parent.parent.path;
      exeName = '';
      if (!_writable(Directory(target).parent)) return DevInstallResult.notWritable;
    } else {
      target = File(exePath).parent.path;
      exeName = exePath.substring(exePath.lastIndexOf(sep) + 1);
      if (!_writable(Directory(target))) return DevInstallResult.notWritable;
    }

    final updater = '${File(path).parent.path}$sep${build.updaterName}';
    if (!File(updater).existsSync()) return DevInstallResult.failed;
    final stamp = (await _stampFile()).path;
    final common = [
      '--pid', '$pid',
      '--app-dir', target,
      '--archive', path,
      '--stamp', stamp,
      '--built-at', build.builtAt.toIso8601String(),
      '--sha', build.sha,
    ];
    final cmd = Platform.isMacOS ? '/bin/bash' : updater;
    final args = Platform.isMacOS ? [updater, ...common] : ['--exe', exeName, ...common];
    await Process.start(cmd, args, mode: ProcessStartMode.detached);
    return DevInstallResult.started;
  } catch (_) {
    return DevInstallResult.failed;
  }
}

/// Desktop: closes the app so the updater can replace its files. Android: nothing to do.
Future<void> finishDevInstall() async {
  if (!devUpdateRestartsApp) return;
  await Future<void>.delayed(const Duration(milliseconds: 900));
  exit(0);
}
