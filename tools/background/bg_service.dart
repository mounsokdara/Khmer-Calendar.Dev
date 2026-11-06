// Khmer Calendar — background service launcher.
//
// Built as a small standalone executable next to the main app:
//   Windows: khmer-calendar-bg.exe
//   Linux:   khmer-calendar-bg
//   macOS:   khmer-calendar-bg
//
// Registered for login/startup instead of the UI binary so boot only
// starts a background task (never a window).
//
// Usage: khmer-calendar-bg
//        khmer-calendar-bg --app-dir /path/to/app/folder

import 'dart:io';

const _lockName = 'khmer-calendar-bg.lock';

void main(List<String> args) {
  final appDir =
      _parseAppDir(args) ?? File(Platform.resolvedExecutable).parent.path;
  final log = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}khmer_calendar_bg.log',
  );
  _say(log, 'bg_service start dir=$appDir');

  if (!_acquireLock(log)) {
    _say(log, 'another background instance is already running; exit');
    exit(0);
  }

  final mainExe = _findMainApp(appDir);
  if (mainExe == null) {
    _say(log, 'main app not found next to bg service');
    exit(2);
  }
  _say(log, 'starting headless: $mainExe --autostart');

  try {
    final mode = Platform.isWindows
        ? ProcessStartMode.detached
        : ProcessStartMode.detached;
    Process.start(
      mainExe,
      const ['--autostart'],
      workingDirectory: appDir,
      mode: mode,
    );
  } catch (e) {
    _say(log, 'failed to start main app: $e');
    exit(1);
  }

  // Launcher exits; the headless Flutter process is the long-running service.
  exit(0);
}

String? _parseAppDir(List<String> args) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--app-dir') return args[i + 1];
  }
  return null;
}

void _say(File log, String msg) {
  final line = '${DateTime.now().toIso8601String()} $msg\n';
  try {
    log.writeAsStringSync(line, mode: FileMode.append, flush: true);
  } catch (_) {}
}

// Held for the life of the process so the OS lock is not released early.
RandomAccessFile? _winLock;

bool _acquireLock(File log) {
  final lockPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}$_lockName';
  final lock = File(lockPath);
  if (Platform.isWindows) {
    // This exe runs as a GUI-subsystem (windowless) process, so spawning
    // console tools like `tasklist` would flash a cmd window. Use a
    // non-blocking OS file lock instead.
    try {
      _winLock = lock.openSync(mode: FileMode.append);
      _winLock!.lockSync(FileLock.exclusive);
      return true;
    } on FileSystemException {
      return false;
    } catch (e) {
      _say(log, 'lock: $e');
      return true;
    }
  }
  try {
    if (lock.existsSync()) {
      final old = lock.readAsStringSync().trim();
      final oldPid = int.tryParse(old);
      if (oldPid != null && _pidAlive(oldPid)) {
        return false;
      }
    }
    lock.writeAsStringSync('$pid\n');
    return true;
  } catch (e) {
    _say(log, 'lock: $e');
    return true;
  }
}

bool _pidAlive(int targetPid) {
  if (Platform.isWindows) {
    try {
      final r = Process.runSync('tasklist', ['/FI', 'PID eq $targetPid', '/NH']);
      return r.stdout.toString().contains('$targetPid');
    } catch (_) {
      return false;
    }
  }
  try {
    final r = Process.runSync('kill', ['-0', '$targetPid']);
    return r.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String? _findMainApp(String appDir) {
  final sep = Platform.pathSeparator;
  final self = Platform.resolvedExecutable;
  final candidates = <String>[
    '$appDir${sep}khmer_calendar.exe',
    '$appDir${sep}khmer_calendar',
    '$appDir${sep}Khmer Calendar.exe',
    '$appDir${sep}Khmer Calendar',
    '$appDir${sep}KhmerCalendar.exe',
    '$appDir${sep}KhmerCalendar',
  ];
  for (final p in candidates) {
    if (p != self && File(p).existsSync()) return p;
  }

  if (Platform.isMacOS) {
    try {
      for (final e in Directory(appDir).listSync()) {
        if (e.path.endsWith('.app')) {
          final macOsDir = '${e.path}${sep}Contents${sep}MacOS';
          final found = _firstExecIn(macOsDir, self);
          if (found != null) return found;
        }
      }
    } catch (_) {}
    final found = _firstExecIn(appDir, self);
    if (found != null) return found;
  }

  try {
    for (final e in Directory(appDir).listSync()) {
      if (e is! File) continue;
      if (e.path == self) continue;
      final base = e.uri.pathSegments.isEmpty
          ? e.path.split(sep).last
          : e.uri.pathSegments.last;
      if (base == 'khmer-calendar-bg' ||
          base == 'khmer-calendar-bg.exe' ||
          base.startsWith('update-') ||
          base.startsWith('KhmerCalendar-Updater') ||
          base.endsWith('.so') ||
          base.endsWith('.dll') ||
          base.endsWith('.json') ||
          base.endsWith('.txt') ||
          base.endsWith('.dat')) {
        continue;
      }
      if (Platform.isWindows) {
        if (base.endsWith('.exe')) return e.path;
      } else {
        final mode = e.statSync().mode;
        if ((mode & 0x49) != 0) return e.path;
      }
    }
  } catch (_) {}
  return null;
}

String? _firstExecIn(String dir, String self) {
  try {
    final d = Directory(dir);
    if (!d.existsSync()) return null;
    for (final e in d.listSync()) {
      if (e is! File) continue;
      if (e.path == self) continue;
      if (e.path.contains('khmer-calendar-bg')) continue;
      final mode = e.statSync().mode;
      if ((mode & 0x49) != 0) return e.path;
    }
  } catch (_) {}
  return null;
}
