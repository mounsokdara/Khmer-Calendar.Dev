import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../theme.dart' show appVersion;
// Prefixed: package:flutter/services.dart also exports a symbol named appBuildNumber.
import '../../theme.dart' as theme show appBuildNumber;
import 'device_arch.dart';
import 'dev_update_types.dart';

const _channel = MethodChannel('khmer.permissions');

final bool inAppUpdateSupported =
    (Platform.isAndroid && !const bool.fromEnvironment('FDROID')) ||
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS;

final bool updateRestartsApp = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

const _packageByDigit = <int, String>{0: 'universal', 1: 'arm32', 2: 'arm64', 3: 'x64', 4: 'arm32_64'};

const _headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'khmer-calendar-updater'};

int _compareVersions(String a, String b) {
  // Accepts 1.0.5, v1.0.5, 1.0.5.2, 1.0.5-dev (suffixes are ignored).
  List<int> parts(String value) {
    final m = RegExp(r'^\s*v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?').firstMatch(value);
    if (m == null) return const [0, 0, 0, 0];
    return [for (var i = 1; i <= 4; i++) int.tryParse(m.group(i) ?? '') ?? 0];
  }

  final aa = parts(a);
  final bb = parts(b);
  for (var i = 0; i < 4; i++) {
    final c = aa[i].compareTo(bb[i]);
    if (c != 0) return c;
  }
  return 0;
}

int? _parseVersionCode(String text) {
  final m = RegExp(r'^\s*versionCode\s*=\s*(\d+)\s*$', multiLine: true).firstMatch(text);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// The app version is checked FIRST: only a higher version name or build number counts as an update.
/// Only when both are equal, a build that was published after this one was installed counts as a
/// newer build of the same version. [builtAt] is null when the publish time is not known.
UpdateKind _decideKind({
  required String remoteVersion,
  required int? remoteBuild,
  required DateTime? builtAt,
  required DateTime? installedAt,
}) {
  final c = _compareVersions(remoteVersion, appVersion);
  if (c > 0) return UpdateKind.newerVersion;
  if (c < 0) return UpdateKind.aheadOfRelease;
  if (remoteBuild != null) {
    if (remoteBuild > theme.appBuildNumber) return UpdateKind.newerVersion;
    if (remoteBuild < theme.appBuildNumber) return UpdateKind.aheadOfRelease;
  }
  if (builtAt != null && installedAt != null && builtAt.isAfter(installedAt.add(const Duration(seconds: 30)))) {
    return UpdateKind.newerBuild;
  }
  return UpdateKind.upToDate; // no stamp / no proof of a newer build: do not claim an update
}

String? _parseVersionName(String text) {
  final m = RegExp(r'^\s*versionName\s*=\s*(\S+)\s*$', multiLine: true).firstMatch(text);
  return m?.group(1);
}

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

String _joinPath(List<String> parts) => parts.where((p) => p.isNotEmpty).join(Platform.pathSeparator);

String _winSystem32(String exeName) {
  final root = Platform.environment['SystemRoot'];
  final base = (root == null || root.isEmpty) ? _joinPath(['C:', 'Windows']) : root;
  return _joinPath([base, 'System32', exeName]);
}

String? _curlPath() {
  if (Platform.isWindows) {
    final p = _winSystem32('curl.exe');
    if (File(p).existsSync()) return p;
    return 'curl.exe';
  }
  if (Platform.isLinux || Platform.isMacOS) return 'curl';
  return null;
}

Future<({int status, String body})?> _curlGet(String url, {Map<String, String>? headers}) async {
  final curl = _curlPath();
  if (curl == null) return null;
  final args = <String>[
    '-sS',
    '-L',
    '--max-time', '30',
    '-w', '\n%{http_code}',
    '-A', 'khmer-calendar-updater',
  ];
  headers?.forEach((k, v) {
    args.addAll(['-H', '$k: $v']);
  });
  args.add(url);
  try {
    final r = await Process.run(curl, args, stdoutEncoding: utf8, stderrEncoding: utf8)
        .timeout(const Duration(seconds: 35));
    if (r.exitCode != 0) return null;
    final out = (r.stdout as String? ?? '');
    final nl = out.lastIndexOf('\n');
    if (nl < 0) return null;
    final code = int.tryParse(out.substring(nl + 1).trim());
    if (code == null) return null;
    return (status: code, body: out.substring(0, nl));
  } catch (_) {
    return null;
  }
}

Future<bool> _curlDownload(
  String url,
  File target, {
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
  int expectedSize = 0,
}) async {
  final curl = _curlPath();
  if (curl == null) return false;
  final part = File('${target.path}.part');
  if (part.existsSync()) part.deleteSync();
  final args = <String>[
    '-fL',
    '--max-time', '600',
    '-A', 'khmer-calendar-updater',
    '-o', part.path,
    url,
  ];
  try {
    final proc = await Process.start(curl, args);
    var done = false;
    final poll = () async {
      while (!done) {
        if (isCancelled?.call() ?? false) {
          proc.kill();
          break;
        }
        if (part.existsSync()) {
          final n = part.lengthSync();
          onProgress?.call(n, expectedSize > 0 ? expectedSize : n);
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    };
    final polling = poll();
    final code = await proc.exitCode.timeout(const Duration(minutes: 12), onTimeout: () {
      proc.kill();
      return -1;
    });
    done = true;
    await polling;
    if (isCancelled?.call() ?? false) {
      if (part.existsSync()) part.deleteSync();
      throw const UpdateCancelled();
    }
    if (code != 0 || !part.existsSync()) {
      if (part.existsSync()) part.deleteSync();
      return false;
    }
    final got = part.lengthSync();
    if (expectedSize > 0 && got != expectedSize) {
      part.deleteSync();
      throw const UpdateException('Download incomplete, please try again');
    }
    if (target.existsSync()) target.deleteSync();
    await part.rename(target.path);
    onProgress?.call(got, got);
    return true;
  } catch (e) {
    if (e is UpdateCancelled || e is UpdateException) rethrow;
    if (part.existsSync()) {
      try {
        part.deleteSync();
      } catch (_) {}
    }
    return false;
  }
}

Future<http.Response> _httpGet(Uri uri, {Map<String, String>? headers}) async {
  Future<http.Response> dartOnce() => http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

  try {
    return await dartOnce();
  } catch (e) {
    if (!_isSslCertError(e)) rethrow;
    final viaCurl = await _curlGet(uri.toString(), headers: headers);
    if (viaCurl != null) {
      return http.Response(viaCurl.body, viaCurl.status, headers: const {'content-type': 'text/plain'});
    }
    throw const UpdateException(_sslCertHint);
  }
}

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
  final remoteBuild = _parseVersionCode(verRes.body);
  if (res.statusCode == 403 || res.statusCode == 429) {
    // GitHub API rate limit (60 requests per hour without a login): use the direct download link instead.
    return UpdateBuild(
      versionName: versionName,
      package: package,
      assetName: assetName,
      url: 'https://github.com/$updateRepo/releases/download/$tag/$assetName',
      size: 0,
      builtAt: DateTime.now().toUtc(),
      sha: '',
      kind: _decideKind(remoteVersion: versionName, remoteBuild: remoteBuild, builtAt: null, installedAt: installedAt),
      installedVersion: appVersion,
      remoteBuildNumber: remoteBuild,
      updaterName: updaterName,
      updaterUrl: '',
    );
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
  return UpdateBuild(
    versionName: versionName,
    package: package,
    assetName: assetName,
    url: asset['browser_download_url'] as String,
    size: (asset['size'] as num?)?.toInt() ?? 0,
    builtAt: builtAt,
    sha: sha,
    kind: _decideKind(remoteVersion: versionName, remoteBuild: remoteBuild, builtAt: builtAt, installedAt: installedAt),
    installedVersion: appVersion,
    remoteBuildNumber: remoteBuild,
    updaterName: updaterName,
    updaterUrl: '',
  );
}

Future<File> _stampFile() async =>
    File(_joinPath([(await getApplicationSupportDirectory()).path, 'updatebuild.json']));

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
        final ok = await _curlDownload(
          url,
          target,
          onProgress: onProgress,
          isCancelled: isCancelled,
          expectedSize: expectedSize,
        );
        if (ok) return;
        throw const UpdateException(_sslCertHint);
      }
      rethrow;
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
  } catch (e) {
    try {
      await sink?.close();
    } catch (_) {}
    if (part.existsSync()) {
      try {
        part.deleteSync();
      } catch (_) {}
    }
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
  return Directory(_joinPath([Directory.systemTemp.path, 'khmer_update_dl']));
}

Future<void> _extractUpdaterFromPackage(String archivePath, String updaterName) async {
  if (updaterName.isEmpty) return;
  final dir = File(archivePath).parent.path;
  final out = File(_joinPath([dir, updaterName]));
  if (out.existsSync()) out.deleteSync();

  if (Platform.isWindows) {
    final tar = _winSystem32('tar.exe');
    if (File(tar).existsSync()) {
      final r = await Process.run(tar, ['-xf', archivePath, '-C', dir, updaterName]);
      if (r.exitCode == 0 && out.existsSync()) return;
    }
    final script = [
      "\$ErrorActionPreference = 'Stop'",
      'Add-Type -AssemblyName System.IO.Compression.FileSystem',
      '\$zipPath = \$args[0]',
      '\$entryName = \$args[1]',
      '\$outPath = \$args[2]',
      '\$z = [System.IO.Compression.ZipFile]::OpenRead(\$zipPath)',
      'try {',
      '  \$e = \$z.Entries | Where-Object { \$_.Name -eq \$entryName } | Select-Object -First 1',
      '  if (\$null -eq \$e) { throw "Package is missing \$entryName" }',
      '  if (Test-Path -LiteralPath \$outPath) { Remove-Item -LiteralPath \$outPath -Force }',
      '  [System.IO.Compression.ZipFileExtensions]::ExtractToFile(\$e, \$outPath, \$true)',
      '} finally { \$z.Dispose() }',
    ].join('; ');
    final ps = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script, '--%', archivePath, updaterName, out.path],
    );
    if (ps.exitCode != 0 || !out.existsSync()) {
      final err = '${ps.stderr}'.trim();
      throw UpdateException(
        err.isEmpty ? 'Package is missing the updater ($updaterName)' : 'Could not extract updater: $err',
      );
    }
  } else if (Platform.isLinux) {
    // Package stores ./update-linux-x64. Requesting the bare name makes tar exit 2
    // even when the file was extracted successfully — only check existsSync.
    await Process.run('tar', ['-xzf', archivePath, '-C', dir, './$updaterName']);
    if (!out.existsSync()) {
      throw UpdateException('Package is missing the updater ($updaterName)');
    }
    await Process.run('chmod', ['+x', out.path]);
  } else if (Platform.isMacOS) {
    final mnt = await Directory.systemTemp.createTemp('khmer_upd_mnt_');
    try {
      final attach = await Process.run('hdiutil', ['attach', '-nobrowse', '-readonly', '-mountpoint', mnt.path, archivePath]);
      if (attach.exitCode != 0) throw const UpdateException('Could not open the disk image');
      final src = File(_joinPath([mnt.path, updaterName]));
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

  final target = File(_joinPath([dir.path, build.assetName]));
  await _fetchTo(build.url, target, build.size, onProgress, isCancelled);

  if (build.updaterName.isNotEmpty) {
    await _extractUpdaterFromPackage(target.path, build.updaterName);
  }
  return target.path;
}

bool _writable(Directory d) {
  try {
    final probe = File(_joinPath([d.path, '.khmer_write_test']));
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

    final updater = _joinPath([File(path).parent.path, build.updaterName]);
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

/// Reads (and removes) the failure report left by the updater. Null when the last update was fine
/// or the report is older than a day.
Future<UpdateFailure?> takeUpdateFailure() async {
  if (!updateRestartsApp) return null;
  try {
    final dir = (await getApplicationSupportDirectory()).path;
    final f = File(_joinPath([dir, 'update_result.json']));
    if (!f.existsSync()) return null;
    final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    f.deleteSync();
    final at = DateTime.tryParse('${json['at']}');
    if (at != null && DateTime.now().toUtc().difference(at.toUtc()).inHours > 24) return null;
    if (json['status'] != 'failed') return null;
    List<String> list(Object? v) => (v as List? ?? const []).map((e) => '$e').toList();
    return UpdateFailure(
      reason: '${json['reason'] ?? 'error'}',
      files: list(json['files']),
      processes: list(json['processes']),
      detail: '${json['detail'] ?? ''}',
    );
  } catch (_) {
    return null;
  }
}

/// Other running copies of this app (same executable name, different process id). They keep the
/// app files locked and block an update, so we warn before the app closes. Best effort.
Future<List<AppInstance>> otherAppInstances() async {
  try {
    final exe = Platform.resolvedExecutable;
    final name = exe.substring(exe.lastIndexOf(Platform.pathSeparator) + 1);
    final out = <AppInstance>[];
    if (Platform.isWindows) {
      final r = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $name', '/NH', '/FO', 'CSV']);
      // One line per process: "image name","pid","session name","session #","memory". Only the first two fields count
      // (the session number is also a quoted number, which is what used to show up as a fake "copy").
      for (final line in '${r.stdout}'.split(RegExp(r'[\r\n]+'))) {
        final m = RegExp(r'^"([^"]+)","(\d+)"').firstMatch(line.trim());
        if (m == null || m.group(1)!.toLowerCase() != name.toLowerCase()) continue;
        final id = int.parse(m.group(2)!);
        if (id != pid) out.add(AppInstance(name, id));
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final r = await Process.run('pgrep', ['-x', name]);
      for (final id in '${r.stdout}'.split('\n').map((e) => int.tryParse(e.trim())).whereType<int>()) {
        if (id != pid) out.add(AppInstance(name, id));
      }
    }
    return out;
  } catch (_) {}
  return const [];
}

/// Force close the given copies (never this process). With [admin] the system asks the user for
/// permission first (Windows UAC, Linux polkit, macOS password) and closes them with admin rights.
Future<void> forceCloseInstances(List<AppInstance> instances, {bool admin = false}) async {
  final ids = [for (final i in instances) if (i.id != pid) i.id];
  if (ids.isEmpty) return;
  try {
    if (!admin) {
      for (final id in ids) {
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/PID', '$id', '/T', '/F']);
        } else {
          await Process.run('kill', ['-9', '$id']);
        }
      }
    } else if (Platform.isWindows) {
      final args = [for (final id in ids) '/PID $id', '/T', '/F'].join(' ');
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          r"try { Start-Process -FilePath 'taskkill.exe' -ArgumentList $env:KC_ARGS -Verb RunAs -Wait -WindowStyle Hidden } catch { exit 1 }",
        ],
        environment: {'KC_ARGS': args},
      );
    } else if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'do shell script "kill -9 ${ids.join(' ')}" with administrator privileges',
      ]);
    } else {
      await Process.run('pkexec', ['/bin/kill', '-9', ...ids.map((e) => '$e')]);
    }
  } catch (_) {}
  await Future<void>.delayed(const Duration(milliseconds: 1500)); // let the system release the files
}
