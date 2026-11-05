// Khmer Calendar updater (Windows: update-windows.exe, Linux: update-linux-<arch>).
//
// Flow:
//   1. app finishes download and starts this program
//   2. this program closes the app (waits briefly, then force-closes if needed)
//   3. after the app is gone, unpack the package and replace files
//   4. write the stamp file and start the new app
// If anything fails it logs why and still tries to restart the old app.
// Log: <temp>/khmer_update.log
//
//   update --pid 123 --app-dir <dir> --exe khmer_calendar[.exe] --archive <file>
//          [--stamp <file> --built-at <iso time> --sha <commit>]
//
// Plain Dart, no packages: `dart compile exe tools/updater/update.dart -o update-windows.exe`
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
    _say('update ok');
  } catch (e) {
    _say('update FAILED: $e');
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
