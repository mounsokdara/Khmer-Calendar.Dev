// Khmer Calendar — background service launcher.
//
// Built as a small standalone executable next to the main app:
//   Windows: khmer-calendar-bg.exe
//   Linux:   khmer-calendar-bg
//   macOS:   khmer-calendar-bg (beside the .app or inside Contents/MacOS)
//
// Registered for login/startup instead of the UI binary so the process
// that starts at boot is clearly a background task and never opens a window.
//
// Usage: khmer-calendar-bg
//        khmer-calendar-bg --app-dir /path/to/app/folder

import 'dart:io';

const _lockName = 'khmer-calendar-bg.lock';
const _mainNames = <String>[
  'khmer_calendar.exe', // Windows Flutter default
  'khmer_calendar',
  'Khmer Calendar',
  'KhmerCalendar',
];

void main(List<String> args) {
  final appDir = _parseAppDir(args) ?? File(Platform.resolvedExecutable).parent.path;
  final log = _logFile(appDir);
  _say(log, 'bg_service start dir=$appDir');

  if (!_acquireLock(appDir, log)) {
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
    Process.start(
      mainExe,
      const ['--autostart'],
      workingDirectory: appDir,
      mode: ProcessStartMode.detached,
      // Windows: avoid inheriting a console that could flash.
      environment: Platform.isWindows
          ? <String, String>{'KHMER_BG': '1'}
          : null,
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

File _logFile(String appDir) {
  final tmp = Directory.systemTemp.path;
  return File('$tmp${Platform.pathSeparator}khmer_calendar_bg.log');
}

void _say(File log, String msg) {
  final line = '${DateTime.now().toIso8601String()} $msg\n';
  try {
    log.writeAsStringSync(line, mode: FileMode.append, flush: true);
  } catch (_) {}
}

/// Simple lock file so double registration or a second login does not spawn twice.
bool _acquireLock(String appDir, File log) {
  final lockPath = '${Directory.systemTemp.path}${Platform.pathSeparator}$_lockName';
  final lock = File(lockPath);
  try {
    if (lock.existsSync()) {
      final old = lock.readAsStringSync().trim();
      final pid = int.tryParse(old);
      if (pid != null && _pidAlive(pid)) {
        return false;
      }
    }
    lock.writeAsStringSync('${pid}\n');
    return true;
  } catch (e) {
    _say(log, 'lock: $e');
    return true; // best-effort
  }
}

int get pid => pidFromPlatform();

int pidFromPlatform() {
  return pid;
}

// Avoid recursive getter — use Platform-independent pid.
// dart:io Process has no static pid; use pid from io via a workaround.
// Actually in Dart, `pid` is a top-level getter from dart:io.

bool _pidAlive(int pid) {
  if (Platform.isWindows) {
    try {
      final r = Process.runSync('tasklist', ['/FI', 'PID eq $pid', '/NH']);
      return r.stdout.toString().contains('$pid');
    } catch (_) {
      return false;
    }
  }
  try {
    // signal 0: check existence
    Process.killPid(pid, ProcessSignal.sigusr1); // may fail; use /proc
  } catch (_) {}
  if (Platform.isLinux || Platform.isMacOS) {
    return File('/proc/$pid').existsSync() ||
        Process.runSync('kill', ['-0', '$pid']).exitCode == 0;
  }
  return false;
}

String? _findMainApp(String appDir) {
  final sep = Platform.pathSeparator;
  // Prefer known names in the same folder.
  for (final name in _mainNames) {
    final p = '$appDir$sep$name';
    if (File(p).existsSync()) return p;
  }
  // macOS: bg binary may sit next to Foo.app
  if (Platform.isMacOS) {
    final dir = Directory(appDir);
    try {
      for (final e in dir.listSync()) {
        if (e.path.endsWith('.app')) {
          final macOs = Directory('${e.path}$sep' 'Contents$sep'MacOS');
          if (macOs.existsSync()) {
            for (final f in macOs.listSync()) {
              if (f is File && !f.path.endsWith('khmer-calendar-bg')) {
                return f.path;
              }
            }
          }
        }
      }
    } catch (_) {}
    // Inside Contents/MacOS already
    final parent = Directory(appDir).parent.path; // Contents
    final bundle = Directory(parent).parent.path; // .app
    if (bundle.endsWith('.app')) {
      for (final name in _mainNames) {
        final p = '$appDir$sep$name';
        if (File(p).existsSync()) return p;
      }
      try {
        for (final f in Directory(appDir).listSync()) {
          if (f is File && !f.path.contains('khmer-calendar-bg')) {
            return f.path;
          }
        }
      } catch (_) {}
    }
  }
  // Linux bundle: executable often named after project
  try {
    for (final e in Directory(appDir).listSync()) {
      if (e is! File) continue;
      final base = e.uri.pathSegments.isEmpty
          ? e.path
          : e.uri.pathSegments.last;
      if (base == 'khmer-calendar-bg' ||
          base.startsWith('update-') ||
          base.endsWith('.so') ||
          base.endsWith('.json') ||
          base.endsWith('.txt')) {
        continue;
      }
      // Prefer executable bit on POSIX
      if (!Platform.isWindows) {
        final mode = e.statSync().mode;
        final exec = (mode & 0x49) != 0; // owner/group/other exec
        if (!exec) continue;
      }
      if (base.endsWith('.exe') || !base.contains('.')) {
        return e.path;
      }
    }
  } catch (_) {}
  return null;
}
