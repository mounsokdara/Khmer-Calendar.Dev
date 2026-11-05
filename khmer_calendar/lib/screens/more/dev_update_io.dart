import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../theme.dart' show appVersion;
import 'device_arch.dart';
import 'dev_update_types.dart';

const _channel = MethodChannel('khmer.permissions');

/// Android (not the F-Droid build, F-Droid updates the app itself) and the three desktop systems.
final bool inAppUpdateSupported =
    (Platform.isAndroid && !const bool.fromEnvironment('FDROID')) ||
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS;

/// Desktop: installing closes the app; the updater program swaps the files and starts it again.
final bool updateRestartsApp = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

const _packageByDigit = <int, String>{0: 'universal', 1: 'arm32', 2: 'arm64', 3: 'x64', 4: 'arm32_64'};

const _headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'khmer-calendar-updater'};

int _compareVersions(String a, String b) {
  List<int> parts(String value) {
    final m = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(value);
    if (m == null) return const [0, 0, 0];
    return [
      int.tryParse(m.group(1) ?? '') ?? 0,
      int.tryParse(m.group(2) ?? '') ?? 0,
      int.tryParse(m.group(3) ?? '') ?? 0,
    ];
  }

  final aa = parts(a);
  final bb = parts(b);
  for (var i = 0; i < 3; i++) {
    final c = aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  return 0;
}

String? _parseVersionName(String text) {
  final m = RegExp(r'^\s*versionName\s*=\s*(\S+)\s*$', multiLine: true).firstMatch(text);
  return m?.group(1);
}

/// True when Dart could not verify the TLS chain (common on some Windows installs).
bool _isSslCertError(Object e) {
  final s = e.toString();
  return s.contains('CERTIFICATE_VERIFY_FAILED') ||
      s.contains('HandshakeException') ||
      s.contains('unable to get local issuer certificate');
}

const _sslCertHint =
    'Secure connection failed (missing system certificate). '
    'Check the date/time is correct, open https://github.com in a browser once, '
    'or turn off antivirus HTTPS scanning, then try again.';

/// Windows (and some Linux) only ship a subset of root CAs until something uses WinINet/Schannel.
/// Dart/BoringSSL does not trigger that lazy install, so HTTPS to GitHub can fail on a "fresh" PC.
/// One PowerShell / curl hit to github.com usually installs the missing roots for the user.
Future<void> _warmSystemCertificates() async {
  if (Platform.isWindows) {
    try {
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'try { Invoke-WebRequest -Uri https://api.github.com -UseBasicParsing -TimeoutSec 12 | Out-Null } catch {}',
        ],
      ).timeout(const Duration(seconds: 20));
    } catch (_) {}
    return;
  }
  if (Platform.isLinux) {
    try {
      await Process.run('curl', ['-fsS', '-o', '/dev/null', '--max-time', '12', 'https://api.github.com'])
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
  }
}

Future<http.Response> _httpGet(Uri uri, {Map<String, String>? headers}) async {
  Future<http.Response> once() => http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

  try {
    return await once();
  } catch (e) {
    if (!_isSslCertError(e)) rethrow;
    await _warmSystemCertificates();
    try {
      return await once();
    } catch (e2) {
      if (_isSslCertError(e2)) {
        throw const UpdateException(_sslCertHint);
      }
      rethrow;
    }
  }
}

/// Looks up the build for this device from the release tag that matches version.txt.
/// Desktop packages include the updater binary inside the archive (not a separate release asset).
Future<UpdateBuild?> fetchUpdateBuild() async {
  late String package;
  late String assetName;
  String? fallbackPackage;
  var updaterName = '';
  DateTime? installedAt;

  if (Platform.isAndroid) {
    final info = await _channel.invokeMapMethod<String, dynamic>('installInfo');
    if (info == null) throw const UpdateException('Cannot read the installed version');
    final versionCode = (info['versionCode'] as num).toInt();
    installedAt = DateTime.fromMillisecondsSinceEpoch((info['installedAt'] as num).toInt(), isUtc: true);
    package = _packageByDigit[versionCode % 10] ?? 'universal';
    assetName = 'KhmerCalendar-$package.apk';
  } else {
    final arch = deviceArch();
    if (arch == null) {
      throw const UpdateException('Could not detect CPU architecture');
    }
    if (Platform.isWindows) {
      if (arch != 'x64' && arch != 'arm64') {
        throw UpdateException('Unsupported Windows architecture: $arch');
      }
      package = arch;
      assetName = 'KhmerCalendar-windows-$arch.zip';
      if (arch == 'arm64') fallbackPackage = 'x64';
      updaterName = 'update-windows.exe';
    } else if (Platform.isLinux) {
      if (arch != 'x64' && arch != 'arm64') {
        throw UpdateException('Unsupported Linux architecture: $arch');
      }
      package = arch;
      assetName = 'KhmerCalendar-linux-$arch.tar.gz';
      updaterName = 'update-linux-$arch';
    } else {
      package = arch == 'x64' ? 'x86_64' : (arch == 'arm64' ? 'arm64' : 'universal');
      assetName = 'KhmerCalendar-macos-$package.dmg';
      updaterName = 'update-macos.sh';
    }
    installedAt = await _readStamp();
  }

  late final http.Response verRes;
  try {
    verRes = await _httpGet(Uri.parse('$updateVersionFileUrl?cb=${DateTime.now().millisecondsSinceEpoch}'));
  } catch (e) {
    if (e is UpdateException) rethrow;
    if (_isSslCertError(e)) throw const UpdateException(_sslCertHint);
    rethrow;
  }
  if (verRes.statusCode != 200) {
    throw UpdateException('Could not read version.txt (${verRes.statusCode})');
  }
  final versionName = _parseVersionName(verRes.body);
  if (versionName == null || versionName.isEmpty) {
    throw const UpdateException('version.txt has no versionName');
  }

  final tag = 'v$versionName';
  late final http.Response res;
  try {
    res = await _httpGet(
      Uri.parse('https://api.github.com/repos/$updateRepo/releases/tags/$tag'),
      headers: _headers,
    );
  } catch (e) {
    if (e is UpdateException) rethrow;
    if (_isSslCertError(e)) throw const UpdateException(_sslCertHint);
    rethrow;
  }
  if (res.statusCode == 404) {
    throw UpdateException('Release $tag not found yet');
  }
  if (res.statusCode != 200) {
    throw UpdateException('GitHub answered ${res.statusCode}');
  }

  final release = jsonDecode(res.body) as Map<String, dynamic>;
  final assets = (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  Map<String, dynamic>? find(String name) =>
      assets.where((a) => a['name'] == name && a['state'] == 'uploaded').firstOrNull;

  var asset = find(assetName);
  if (asset == null && fallbackPackage != null) {
    package = fallbackPackage;
    assetName = 'KhmerCalendar-windows-$package.zip';
    asset = find(assetName);
  }
  if (asset == null) {
    final names = assets.map((a) => a['name']).whereType<String>().take(12).join(', ');
    throw UpdateException('No package for this device ($assetName). Assets: $names');
  }

  final builtAt = DateTime.parse(asset['updated_at'] as String).toUtc();
  final sha = RegExp(r'\(([0-9a-fA-F]{7,40})\)').firstMatch('${release['name'] ?? ''}')?.group(1) ?? '';
  final newerByVersion = _compareVersions(versionName, appVersion) > 0;
  final newerByTime = installedAt == null || builtAt.isAfter(installedAt);
  return UpdateBuild(
    versionName: versionName,
    package: package,
    assetName: assetName,
    url: asset['browser_download_url'] as String,
    size: (asset['size'] as num?)?.toInt() ?? 0,
    builtAt: builtAt,
    sha: sha,
    isNewer: newerByVersion || newerByTime,
    updaterName: updaterName,
    updaterUrl: '',
  );
}

Future<File> _stampFile() async =>
    File('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}updatebuild.json');

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
    late final http.StreamedResponse response;
    try {
      response = await client
          .send(http.Request('GET', Uri.parse(url))..headers.addAll(_headers))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      if (_isSslCertError(e)) {
        await _warmSystemCertificates();
        try {
          response = await client
              .send(http.Request('GET', Uri.parse(url))..headers.addAll(_headers))
              .timeout(const Duration(seconds: 20));
        } catch (e2) {
          if (_isSslCertError(e2)) throw const UpdateException(_sslCertHint);
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    if (response.statusCode != 200) throw UpdateException('Download failed (${response.statusCode})');

    final total = response.contentLength ?? expectedSize;
    var received = 0;
    sink = part.openWrite();
    await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
      if (isCancelled?.call() ?? false) throw const UpdateCancelled();
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.flush();
    await sink.close();
    sink = null;

    if (expectedSize > 0 && received != expectedSize) {
      throw const UpdateException('Download incomplete, please try again');
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
    if (p == null) throw const UpdateException('No download folder');
    return Directory(p);
  }
  return Directory('${Directory.systemTemp.path}${Platform.pathSeparator}khmer_update_dl');
}

Future<void> _extractUpdaterFromPackage(String archivePath, String updaterName) async {
  if (updaterName.isEmpty) return;
  final dir = File(archivePath).parent.path;
  final sep = Platform.pathSeparator;
  final out = File('$dir$sep$updaterName');
  if (out.existsSync()) out.deleteSync();

  if (Platform.isWindows) {
    final tar = '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\System32\tar.exe';
    final r = await Process.run(tar, ['-xf', archivePath, '-C', dir, updaterName]);
    if (r.exitCode != 0 || !out.existsSync()) {
      throw UpdateException('Package is missing the updater ($updaterName)');
    }
  } else if (Platform.isLinux) {
    final r = await Process.run('tar', ['-xzf', archivePath, '-C', dir, './$updaterName', updaterName]);
    if (r.exitCode != 0 || !out.existsSync()) {
      throw UpdateException('Package is missing the updater ($updaterName)');
    }
    await Process.run('chmod', ['+x', out.path]);
  } else if (Platform.isMacOS) {
    final mnt = await Directory.systemTemp.createTemp('khmer_upd_mnt_');
    try {
      final attach = await Process.run('hdiutil', ['attach', '-nobrowse', '-readonly', '-mountpoint', mnt.path, archivePath]);
      if (attach.exitCode != 0) throw const UpdateException('Could not open the disk image');
      final src = File('${mnt.path}$sep$updaterName');
      if (!src.existsSync()) throw UpdateException('Package is missing the updater ($updaterName)');
      src.copySync(out.path);
      await Process.run('chmod', ['+x', out.path]);
    } finally {
      await Process.run('hdiutil', ['detach', mnt.path, '-force']);
      try {
        mnt.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

Future<String> downloadUpdateBuild(
  UpdateBuild build,
  void Function(int received, int total) onProgress, {
  bool Function()? isCancelled,
}) async {
  final dir = await _downloadDir();
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  final sep = Platform.pathSeparator;

  final target = File('${dir.path}$sep${build.assetName}');
  await _fetchTo(build.url, target, build.size, onProgress, isCancelled);

  if (build.updaterName.isNotEmpty) {
    await _extractUpdaterFromPackage(target.path, build.updaterName);
  }
  return target.path;
}

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

Future<UpdateInstallResult> installUpdateBuild(String path, UpdateBuild build) async {
  if (Platform.isAndroid) {
    try {
      final r = await _channel.invokeMethod<String>('installApk', {'path': path});
      switch (r) {
        case 'started':
          return UpdateInstallResult.started;
        case 'permission':
          return UpdateInstallResult.needsPermission;
        default:
          return UpdateInstallResult.failed;
      }
    } on PlatformException {
      return UpdateInstallResult.failed;
    }
  }

  try {
    final exePath = Platform.resolvedExecutable;
    final sep = Platform.pathSeparator;
    final String target;
    final String exeName;
    if (Platform.isMacOS) {
      target = File(exePath).parent.parent.parent.path;
      exeName = '';
      if (!_writable(Directory(target).parent)) return UpdateInstallResult.notWritable;
    } else {
      target = File(exePath).parent.path;
      exeName = exePath.substring(exePath.lastIndexOf(sep) + 1);
      if (!_writable(Directory(target))) return UpdateInstallResult.notWritable;
    }

    final updater = '${File(path).parent.path}$sep${build.updaterName}';
    if (!File(updater).existsSync()) return UpdateInstallResult.failed;
    final stamp = (await _stampFile()).path;
    final common = [
      '--pid', '$pid',
      '--app-dir', target,
      '--archive', path,
      '--stamp', stamp,
      '--built-at', build.builtAt.toIso8601String(),
      '--sha', build.sha,
    ];

    if (Platform.isWindows) {
      final args = ['/c', 'start', '', '/B', updater, '--exe', exeName, ...common];
      await Process.start(
        'cmd',
        args,
        workingDirectory: File(updater).parent.path,
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      await Process.start(
        '/bin/bash',
        [updater, ...common],
        workingDirectory: File(updater).parent.path,
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        updater,
        ['--exe', exeName, ...common],
        workingDirectory: File(updater).parent.path,
        mode: ProcessStartMode.detached,
      );
    }
    return UpdateInstallResult.started;
  } catch (_) {
    return UpdateInstallResult.failed;
  }
}

Future<void> finishUpdateInstall() async {
  if (!updateRestartsApp) return;
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  exit(0);
}
