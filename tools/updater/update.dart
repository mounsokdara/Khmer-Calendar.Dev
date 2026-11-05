// Khmer Calendar updater (Windows: update-windows.exe, Linux: update-linux-<arch>).
//
// Flow:
//   1. app finishes download and starts this program
//   2. this program closes the app (waits briefly, then force-closes if needed)
//   3. after the app is gone, unpack the package and replace files
//   4. write the stamp file and start the new app
// Before touching any file it checks that nothing else is using the app files. If something is,
// it asks the user to close it (Retry / Cancel) instead of failing silently.
// If anything fails it logs why, writes <stamp folder>/update_result.json (the app shows it on the
// next start) and still tries to restart the old app.
// Log: <temp>/khmer_update.log
//
//   update --pid 123 --app-dir <dir> --exe khmer_calendar[.exe] --archive <file>
//          [--stamp <file> --built-at <iso time> --sha <commit>]
//
// Standalone mode (download KhmerCalendar-Updater-* from the release and run it, the app does not
// need to be started): with no --pid/--archive it finds the installed app, downloads the latest
// package itself, closes the app if it is running, updates it and starts it again.
//   KhmerCalendar-Updater-windows-x64.exe [--app-dir <dir>]
//
// Plain Dart, no packages: `dart compile exe tools/updater/update.dart -o update-windows.exe`
import 'dart:convert';
import 'dart:io';

final _sep = Platform.pathSeparator;

const _repo = 'mounsokdara/Khmer-Calendar.Dev';
const _userAgent = 'khmer-calendar-updater';
final _log = File('${Directory.systemTemp.path}${_sep}khmer_update.log');

void _say(String m) {
  try {
    _log.writeAsStringSync('${DateTime.now().toIso8601String()} $m\n', mode: FileMode.append);
  } catch (_) {}
  try {
    stdout.writeln(m); // visible when the updater is started by hand (console window)
  } catch (_) {}
}

Map<String, String> _parse(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (args[i].startsWith('--')) out[args[i].substring(2)] = args[i + 1];
  }
  return out;
}

Future<bool> _alive(int pid) async {
  if (Platform.isWindows) {
    final r = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH', '/FO', 'CSV']);
    final out = '${r.stdout}';
    // CSV lines look like: "khmer_calendar.exe","1234","Session Name",...
    return RegExp('"$pid"').hasMatch(out);
  }
  return (await Process.run('kill', ['-0', '$pid'])).exitCode == 0;
}

Future<void> _waitUntilGone(int pid, {int attempts = 100}) async {
  for (var i = 0; i < attempts; i++) {
    if (!await _alive(pid)) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw 'The app (pid $pid) did not close in time';
}

/// Close the running app so its files are unlocked, then wait until it is gone.
Future<void> _closeApp(int pid) async {
  // Brief window for the app to exit itself after launching us.
  for (var i = 0; i < 25; i++) {
    if (!await _alive(pid)) {
      _say('app already exited (pid $pid)');
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  _say('closing app pid $pid');
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/PID', '$pid', '/T']);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (await _alive(pid)) {
      _say('force closing app pid $pid');
      await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
    }
  } else {
    await Process.run('kill', ['$pid']);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (await _alive(pid)) {
      _say('force closing app pid $pid');
      await Process.run('kill', ['-9', '$pid']);
    }
  }

  await _waitUntilGone(pid);
  // Extra settle time so antivirus / Explorer release file locks.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  _say('app closed');
}


/// Thrown when files in the app folder stay locked by another program.
class _Blocked implements Exception {
  _Blocked(this.files, this.processes);
  final List<String> files;
  final List<String> processes;
  @override
  String toString() => 'Files in use by another program: ${files.take(5).join(', ')}'
      '${processes.isEmpty ? '' : ' (${processes.join(', ')})'}';
}

/// Package files that already exist in the app folder but cannot be opened for writing right now
/// (Windows: sharing violation; Linux: "text file busy"; or read-only).
List<String> _lockedFiles(Directory from, Directory to) {
  final out = <String>[];
  for (final f in from.listSync(recursive: true, followLinks: false).whereType<File>()) {
    final rel = f.path.substring(from.path.length + 1);
    final dest = File('${to.path}$_sep$rel');
    if (!dest.existsSync()) continue;
    try {
      dest.openSync(mode: FileMode.append).closeSync();
    } on FileSystemException {
      out.add(rel);
    }
  }
  return out;
}

/// Programs that run from inside the app folder (for example a second copy of the app,
/// or a helper started from it). Best effort: returns an empty list when it cannot tell.
Future<List<String>> _blockingProcesses(String appDir) async {
  final dir = appDir.endsWith(_sep) ? appDir : '$appDir$_sep';
  try {
    if (Platform.isWindows) {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r"Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($env:KC_DIR, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $_.ProcessName + ' (' + $_.Id + ')' }",
        ],
        environment: {'KC_DIR': dir},
      ).timeout(const Duration(seconds: 15));
      return '${r.stdout}'.split(RegExp(r'[\r\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    final out = <String>[];
    for (final e in Directory('/proc').listSync(followLinks: false).whereType<Directory>()) {
      final id = int.tryParse(e.path.split('/').last);
      if (id == null || id == pid) continue;
      try {
        final target = Link('${e.path}/exe').targetSync();
        if (target.startsWith(dir)) out.add('${target.split('/').last} ($id)');
      } catch (_) {}
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Native Retry / Cancel box (no Flutter here: the app is closed while we update).
/// Returns true when the user chose Retry. Without a dialog tool it returns false and the
/// failure is reported by the app on the next start.
Future<bool> _askRetry(String title, String message) async {
  try {
    if (Platform.isWindows) {
      const script = r"Add-Type -AssemblyName System.Windows.Forms; "
          r"$f = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}; "
          r"$r = [System.Windows.Forms.MessageBox]::Show($f, $env:KC_MSG, $env:KC_TITLE, 'RetryCancel', 'Warning'); "
          r"if ($r -eq 'Retry') { exit 0 } else { exit 1 }";
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', script],
        environment: {'KC_MSG': message, 'KC_TITLE': title},
      );
      return r.exitCode == 0;
    }
    if (Platform.isLinux) {
      final zenity = await Process.run('which', ['zenity']);
      if (zenity.exitCode == 0) {
        final r = await Process.run('zenity', [
          '--question', '--title=$title', '--text=$message',
          '--ok-label=Retry', '--cancel-label=Cancel', '--width=420',
        ]);
        return r.exitCode == 0;
      }
      final kdialog = await Process.run('which', ['kdialog']);
      if (kdialog.exitCode == 0) {
        final r = await Process.run('kdialog', [
          '--title', title, '--warningcontinuecancel', message,
          '--continue-label', 'Retry', '--cancel-label', 'Cancel',
        ]);
        return r.exitCode == 0;
      }
    }
  } catch (_) {}
  return false;
}

/// Wait until the files we must replace are free. If another program keeps them locked, tell the
/// user which one and let them close it and retry. Nothing is copied until everything is free,
/// so a blocked update never leaves a half-updated app.
Future<void> _waitForUnlocked(Directory from, Directory to) async {
  var asked = 0;
  while (true) {
    var locked = <String>[];
    for (var i = 0; i < 15; i++) {
      locked = _lockedFiles(from, to);
      if (locked.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    final procs = await _blockingProcesses(to.path);
    _say('files locked: ${locked.take(10).join(', ')}; programs: ${procs.join(', ')}');
    final shown = locked.take(4).join('\n');
    final more = locked.length > 4 ? '\n... and ${locked.length - 4} more' : '';
    final who = procs.isEmpty
        ? 'Close any other program that is using Khmer Calendar files (including another copy of the app).'
        : 'Please close: ${procs.join(', ')}';
    final retry = asked < 5 &&
        await _askRetry(
          'Khmer Calendar update',
          'The update could not be installed because some app files are in use by a running program.\n\n'
              '$who\n\nFiles in use:\n$shown$more\n\nClick Retry after closing it, or Cancel to keep the current version.',
        );
    asked++;
    if (!retry) throw _Blocked(locked, procs);
  }
}

File _resultFile(String? stamp) => (stamp != null && stamp.isNotEmpty)
    ? File('${File(stamp).parent.path}${_sep}update_result.json')
    : File('${Directory.systemTemp.path}${_sep}khmer_update_result.json');

void _writeResult(String? stamp, Map<String, Object?> data) {
  try {
    final f = _resultFile(stamp)..parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode({...data, 'at': DateTime.now().toUtc().toIso8601String()}));
  } catch (_) {}
}

void _clearResult(String? stamp) {
  try {
    final f = _resultFile(stamp);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

Future<Directory> _unpack(String archive) async {
  final stage = Directory('${Directory.systemTemp.path}${_sep}khmer_update_stage');
  if (stage.existsSync()) stage.deleteSync(recursive: true);
  stage.createSync(recursive: true);
  final zip = archive.toLowerCase().endsWith('.zip');
  // Windows: use the built-in bsdtar (it reads zip); a `tar` from Git for Windows could not.
  final tar = Platform.isWindows ? '${Platform.environment['SystemRoot'] ?? r'C:\\Windows'}\\System32\\tar.exe' : 'tar';
  final r = await Process.run(tar, [zip ? '-xf' : '-xzf', archive, '-C', stage.path]);
  if (r.exitCode != 0) throw 'Unpack failed (${r.exitCode}): ${r.stderr}';
  return stage;
}

/// The folder that holds the main executable (the package may or may not wrap it in one extra folder).
Directory _packageRoot(Directory stage, String exe) {
  if (File('${stage.path}$_sep$exe').existsSync()) return stage;
  for (final e in stage.listSync().whereType<Directory>()) {
    if (File('${e.path}$_sep$exe').existsSync()) return e;
  }
  throw 'The package does not contain $exe';
}

Future<void> _copyOver(Directory from, Directory to, String exe) async {
  final files = from.listSync(recursive: true, followLinks: false).whereType<File>().toList()
    // The main executable goes last: if copying breaks half way, the old app still starts.
    ..sort((a, b) {
      final ae = a.path.endsWith('$_sep$exe') ? 1 : 0;
      final be = b.path.endsWith('$_sep$exe') ? 1 : 0;
      return ae - be;
    });
  for (final f in files) {
    final rel = f.path.substring(from.path.length + 1);
    final dest = File('${to.path}$_sep$rel');
    dest.parent.createSync(recursive: true);
    for (var attempt = 1;; attempt++) {
      try {
        f.copySync(dest.path);
        break;
      } on FileSystemException {
        if (attempt >= 30) rethrow; // files stay locked for a moment after a process ends (antivirus, indexer)
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }
  if (!Platform.isWindows) await Process.run('chmod', ['+x', '${to.path}$_sep$exe']);
}

Future<void> _start(String appDir, String exe) async {
  final path = '$appDir$_sep$exe';
  if (Platform.isWindows) {
    // Fully detach so restart is not tied to this updater process.
    await Process.start(
      'cmd',
      ['/c', 'start', '', '/B', path],
      workingDirectory: appDir,
      mode: ProcessStartMode.detached,
    );
  } else {
    await Process.start(path, const [], workingDirectory: appDir, mode: ProcessStartMode.detached);
  }
}


// ---------------------------------------------------------------- standalone mode

/// Plain message box (or console line when no dialog tool exists).
Future<void> _notify(String title, String message) async {
  try {
    if (Platform.isWindows) {
      await Process.run(
        'powershell',
        [
          '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command',
          r"Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}; "
              r"[void][System.Windows.Forms.MessageBox]::Show($f, $env:KC_MSG, $env:KC_TITLE, 'OK', 'Information')",
        ],
        environment: {'KC_MSG': message, 'KC_TITLE': title},
      );
      return;
    }
    if (Platform.isLinux) {
      final z = await Process.run('which', ['zenity']);
      if (z.exitCode == 0) {
        await Process.run('zenity', ['--info', '--title=$title', '--text=$message', '--width=420']);
        return;
      }
    }
  } catch (_) {}
  stdout.writeln('$title: $message');
}

Future<String?> _pickFolder(String message) async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile', '-NonInteractive', '-Command',
          r"Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; "
              r"$d.Description = $env:KC_MSG; if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath }",
        ],
        environment: {'KC_MSG': message},
      );
      final v = '${r.stdout}'.trim();
      return v.isEmpty ? null : v;
    }
    final z = await Process.run('which', ['zenity']);
    if (z.exitCode == 0) {
      final r = await Process.run('zenity', ['--file-selection', '--directory', '--title=$message']);
      final v = '${r.stdout}'.trim();
      return v.isEmpty ? null : v;
    }
  } catch (_) {}
  return null;
}

String _exeName() => Platform.isWindows ? 'khmer_calendar.exe' : 'khmer_calendar';

/// Where the installed app most likely lives.
List<String> _appDirCandidates() {
  final env = Platform.environment;
  final out = <String>[File(Platform.resolvedExecutable).parent.path];
  if (Platform.isWindows) {
    for (final k in ['LOCALAPPDATA', 'ProgramFiles', 'ProgramFiles(x86)']) {
      final b = env[k];
      if (b == null || b.isEmpty) continue;
      if (k == 'LOCALAPPDATA') out.add('$b\\Programs\\Khmer Calendar');
      out.add('$b\\Khmer Calendar');
    }
  } else {
    final home = env['HOME'] ?? '';
    out.addAll(['$home/KhmerCalendar', '$home/khmer_calendar', '$home/Applications/KhmerCalendar', '/opt/khmer_calendar', '/opt/KhmerCalendar']);
  }
  return out;
}

/// Same folder the app uses for its "installed build" stamp and the failure report.
String? _supportDir() {
  final env = Platform.environment;
  if (Platform.isWindows) {
    final b = env['APPDATA'];
    return b == null ? null : '$b\\mounsokdara\\khmer_calendar';
  }
  final base = env['XDG_DATA_HOME'] ?? (env['HOME'] == null ? null : '${env['HOME']}/.local/share');
  return base == null ? null : '$base/com.mounsokdara.khmercalendar';
}

Future<String?> _curl(List<String> extra) async {
  final curl = Platform.isWindows ? '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\curl.exe' : 'curl';
  try {
    final r = await Process.run(curl, ['-sSfL', '--max-time', '600', '-A', _userAgent, ...extra]);
    return r.exitCode == 0 ? '${r.stdout}' : null;
  } catch (_) {
    return null;
  }
}

Future<String> _getText(String url) async {
  final c = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = _userAgent;
  try {
    final req = await c.getUrl(Uri.parse(url));
    req.headers.set('Accept', 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw 'GitHub answered ${res.statusCode} for $url';
    return await res.transform(utf8.decoder).join();
  } on TlsException {
    final v = await _curl([url]); // system certificate problem: let curl try
    if (v != null) return v;
    throw 'Secure connection failed. Check the date/time, then try again.';
  } finally {
    c.close(force: true);
  }
}

Future<void> _downloadFile(String url, File target, int expected) async {
  if (target.existsSync()) target.deleteSync();
  final c = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = _userAgent;
  try {
    final req = await c.getUrl(Uri.parse(url));
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw 'Download failed (HTTP ${res.statusCode})';
    final sink = target.openWrite();
    var got = 0, last = -1;
    try {
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        got += chunk.length;
        if (expected > 0) {
          final pct = got * 100 ~/ expected ~/ 10 * 10;
          if (pct != last) {
            last = pct;
            _say('  downloading $pct%');
          }
        }
      }
    } finally {
      await sink.close();
    }
    if (expected > 0 && got != expected) throw 'Download incomplete, please try again';
  } on TlsException {
    final curl = Platform.isWindows ? '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\curl.exe' : 'curl';
    final r = await Process.run(curl, ['-fL', '--max-time', '600', '-A', _userAgent, '-o', target.path, url]);
    if (r.exitCode != 0) throw 'Secure connection failed. Check the date/time, then try again.';
  } finally {
    c.close(force: true);
  }
}

/// Ids of running app processes that live in [appDir].
Future<List<int>> _appPids(String appDir, String exe) async {
  final dir = appDir.endsWith(_sep) ? appDir : '$appDir$_sep';
  final ids = <int>[];
  try {
    if (Platform.isWindows) {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile', '-NonInteractive', '-Command',
          r"Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($env:KC_DIR, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $_.Id }",
        ],
        environment: {'KC_DIR': dir},
      ).timeout(const Duration(seconds: 15));
      ids.addAll('${r.stdout}'.split(RegExp(r'[\r\n]+')).map(int.tryParse).whereType<int>());
    } else {
      for (final e in Directory('/proc').listSync(followLinks: false).whereType<Directory>()) {
        final id = int.tryParse(e.path.split('/').last);
        if (id == null || id == pid) continue;
        try {
          if (Link('${e.path}/exe').targetSync().startsWith(dir)) ids.add(id);
        } catch (_) {}
      }
    }
  } catch (_) {}
  ids.remove(pid);
  return ids;
}

Future<String> _linuxArch() async {
  final r = await Process.run('uname', ['-m']);
  final m = '${r.stdout}'.trim();
  return (m == 'aarch64' || m == 'arm64') ? 'arm64' : 'x64';
}

/// Everything the app would do itself: find the install, fetch the newest package, update, restart.
Future<void> _standalone(Map<String, String> a) async {
  const title = 'Khmer Calendar updater';
  if (!Platform.isWindows && !Platform.isLinux) {
    await _notify(title, 'This updater supports Windows and Linux. On macOS, use About > Check for updates inside the app.');
    exit(2);
  }
  final exe = _exeName();
  _say('--- standalone update start');

  // 1. Where is the app?
  String? appDir = a['app-dir'];
  if (appDir == null) {
    for (final c in _appDirCandidates()) {
      if (File('$c$_sep$exe').existsSync()) {
        appDir = c;
        break;
      }
    }
  }
  appDir ??= await _pickFolder('Select the folder that contains $exe');
  if (appDir == null || !File('$appDir$_sep$exe').existsSync()) {
    await _notify(title, 'Khmer Calendar was not found.\n\nRun the updater again and choose the folder that contains $exe, or start it with --app-dir <folder>.');
    exit(2);
  }
  _say('app folder: $appDir');

  String? stampPath;
  final support = _supportDir();
  if (support != null) stampPath = '$support${_sep}updatebuild.json';

  try {
    // 2. What is the newest build for this device?
    _say('checking the latest version...');
    final versionText = await _getText('https://raw.githubusercontent.com/$_repo/main/version.txt?cb=${DateTime.now().millisecondsSinceEpoch}');
    final version = RegExp(r'^\s*versionName\s*=\s*(\S+)\s*$', multiLine: true).firstMatch(versionText)?.group(1);
    if (version == null) throw 'version.txt has no versionName';
    final release = jsonDecode(await _getText('https://api.github.com/repos/$_repo/releases/tags/v$version')) as Map<String, dynamic>;
    final assets = (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>();

    final wanted = <String>[];
    if (Platform.isWindows) {
      final env = Platform.environment;
      final arm = '${env['PROCESSOR_ARCHITEW6432'] ?? env['PROCESSOR_ARCHITECTURE'] ?? ''}'.toUpperCase() == 'ARM64';
      if (arm) wanted.add('KhmerCalendar-windows-arm64.zip');
      wanted.add('KhmerCalendar-windows-x64.zip');
    } else {
      wanted.add('KhmerCalendar-linux-${await _linuxArch()}.tar.gz');
    }
    Map<String, dynamic>? asset;
    for (final w in wanted) {
      asset = assets.where((x) => x['name'] == w && x['state'] == 'uploaded').firstOrNull;
      if (asset != null) break;
    }
    if (asset == null) throw 'No package for this device in release v$version yet. It may still be publishing, try again in a few minutes.';

    // 3. Download.
    final dl = Directory('${Directory.systemTemp.path}${_sep}khmer_update_dl');
    if (dl.existsSync()) dl.deleteSync(recursive: true);
    dl.createSync(recursive: true);
    final archive = File('${dl.path}$_sep${asset['name']}');
    _say('downloading ${asset['name']} (v$version)...');
    await _downloadFile(asset['browser_download_url'] as String, archive, (asset['size'] as num?)?.toInt() ?? 0);

    // 4. Close the app if it runs, then update.
    final pids = await _appPids(appDir, exe);
    if (pids.isNotEmpty) _say('closing the running app (${pids.join(', ')})...');
    for (final p in pids) {
      await _closeApp(p);
    }
    final sha = RegExp(r'\(([0-9a-fA-F]{7,40})\)').firstMatch('${release['name'] ?? ''}')?.group(1) ?? '';
    await _applyUpdate(
      appDir: appDir,
      exe: exe,
      archive: archive.path,
      stamp: stampPath,
      builtAt: '${asset['updated_at'] ?? ''}',
      sha: sha,
    );
    _say('update ok (v$version)');
  } catch (e) {
    _say('update FAILED: $e');
    if (stampPath != null) {
      _writeResult(stampPath, {
        'status': 'failed',
        'reason': e is _Blocked ? 'locked' : 'error',
        'files': e is _Blocked ? e.files.take(20).toList() : <String>[],
        'processes': e is _Blocked ? e.processes : <String>[],
        'detail': '$e',
      });
    }
    if (e is! _Blocked) await _notify(title, 'The update did not finish.\n\n$e\n\nYour current version is unchanged.');
    else await _notify(title, 'The update was cancelled because some app files are still in use. Your current version is unchanged.');
    exit(1);
  }
  try {
    await _start(appDir, exe);
    _say('app started');
  } catch (e) {
    _say('could not start the app: $e');
  }
}

/// Unpack, check nothing is locked, copy, write the stamp, clean up.
Future<void> _applyUpdate({
  required String appDir,
  required String exe,
  required String archive,
  String? stamp,
  String builtAt = '',
  String sha = '',
}) async {
  final stage = await _unpack(archive);
  final root = _packageRoot(stage, exe);
  await _waitForUnlocked(root, Directory(appDir));
  await _copyOver(root, Directory(appDir), exe);
  if (stamp != null && stamp.isNotEmpty) {
    final f = File(stamp)..parent.createSync(recursive: true);
    f.writeAsStringSync('{"builtAt":"$builtAt","sha":"$sha"}');
  }
  try {
    stage.deleteSync(recursive: true);
    File(archive).deleteSync();
  } catch (_) {}
  _clearResult(stamp);
}

Future<void> main(List<String> args) async {
  final a = _parse(args);
  final pid = int.tryParse(a['pid'] ?? '');
  final appDir = a['app-dir'];
  final exe = a['exe'];
  final archive = a['archive'];
  if (pid == null || exe == null || archive == null || appDir == null) {
    // Started by hand (double click): do the whole job ourselves.
    if (pid == null && archive == null) {
      await _standalone(a);
      return;
    }
    _say('Missing arguments: $args');
    exit(2);
  }
  _say('--- update start: $args');
  try {
    await _closeApp(pid);
    await _applyUpdate(
      appDir: appDir,
      exe: exe,
      archive: archive,
      stamp: a['stamp'],
      builtAt: a['built-at'] ?? '',
      sha: a['sha'] ?? '',
    );
    _say('update ok');
  } catch (e) {
    _say('update FAILED: $e');
    _writeResult(a['stamp'], {
      'status': 'failed',
      'reason': e is _Blocked ? 'locked' : 'error',
      'files': e is _Blocked ? e.files.take(20).toList() : <String>[],
      'processes': e is _Blocked ? e.processes : <String>[],
      'detail': '$e',
    });
    try {
      await _start(appDir, exe); // bring the old version back
    } catch (_) {}
    exit(1);
  }
  try {
    await _start(appDir, exe);
    _say('app restarted');
  } catch (e) {
    _say('could not restart: $e');
    exit(1);
  }
}
