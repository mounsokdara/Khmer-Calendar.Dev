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
// Plain Dart, no packages: `dart compile exe tools/updater/update.dart -o update-windows.exe`
import 'dart:convert';
import 'dart:io';

final _sep = Platform.pathSeparator;
final _log = File('${Directory.systemTemp.path}${_sep}khmer_update.log');

void _say(String m) {
  try {
    _log.writeAsStringSync('${DateTime.now().toIso8601String()} $m\n', mode: FileMode.append);
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

Future<void> main(List<String> args) async {
  final a = _parse(args);
  final pid = int.tryParse(a['pid'] ?? '');
  final appDir = a['app-dir'];
  final exe = a['exe'];
  final archive = a['archive'];
  if (pid == null || appDir == null || exe == null || archive == null) {
    _say('Missing arguments: $args');
    exit(2);
  }
  _say('--- update start: $args');
  try {
    await _closeApp(pid);
    final stage = await _unpack(archive);
    final root = _packageRoot(stage, exe);
    await _waitForUnlocked(root, Directory(appDir));
    await _copyOver(root, Directory(appDir), exe);
    final stamp = a['stamp'];
    if (stamp != null && stamp.isNotEmpty) {
      final f = File(stamp)..parent.createSync(recursive: true);
      f.writeAsStringSync('{"builtAt":"${a['built-at'] ?? ''}","sha":"${a['sha'] ?? ''}"}');
    }
    try {
      stage.deleteSync(recursive: true);
      File(archive).deleteSync();
    } catch (_) {}
    _clearResult(stamp);
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
