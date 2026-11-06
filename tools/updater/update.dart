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

/// True when [path] is this very updater program (it can never replace its own running file).
bool _isSelf(String path) {
  final me = Platform.resolvedExecutable;
  return Platform.isWindows ? path.toLowerCase() == me.toLowerCase() : path == me;
}

/// Package files that already exist in the app folder but cannot be opened for writing right now
/// (Windows: sharing violation; Linux: "text file busy"; or read-only). The running updater itself
/// is skipped: it is not part of what has to be replaced.
List<String> _lockedFiles(Directory from, Directory to) {
  final out = <String>[];
  for (final f in from.listSync(recursive: true, followLinks: false).whereType<File>()) {
    final rel = f.path.substring(from.path.length + 1);
    final dest = File('${to.path}$_sep$rel');
    if (!dest.existsSync() || _isSelf(dest.path)) continue;
    try {
      dest.openSync(mode: FileMode.append).closeSync();
    } on FileSystemException {
      out.add(rel);
    }
  }
  return out;
}

/// Programs that must never be force closed (the system or the shell would break).
const _protectedNames = {
  'explorer', 'svchost', 'services', 'system', 'csrss', 'wininit', 'winlogon', 'lsass', 'dwm', 'smss',
  'searchindexer', 'searchhost', 'searchprotocolhost', 'msmpeng', 'trustedinstaller', 'fontdrvhost',
  'sihost', 'taskhostw', 'runtimebroker', 'ctfmon', 'systemd', 'init', 'launchd',
};

class _Proc {
  _Proc(this.id, this.name, [this.desc = '']);
  final int id;
  final String name; // process name, for example khmer_calendar.exe
  final String desc; // friendly name when the system knows one, for example "Windows Explorer"

  bool get isProtected => _protectedNames.contains(name.toLowerCase().replaceAll(RegExp(r'\.exe$'), ''));

  @override
  String toString() {
    final friendly = desc.isNotEmpty && desc.toLowerCase() != name.toLowerCase() ? '$desc - ' : '';
    return '$friendly$name (pid $id)';
  }
}

// Windows Restart Manager: the same API the Windows installer uses to learn which programs
// have a file open. Works for files held by Explorer, antivirus, editors, other apps...
const _restartManagerScript = r"""
$src = @'
using System; using System.Collections.Generic; using System.Diagnostics; using System.Runtime.InteropServices;
public static class KcLock {
  [StructLayout(LayoutKind.Sequential)] struct RM_UNIQUE_PROCESS { public int dwProcessId; public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime; }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct RM_PROCESS_INFO {
    public RM_UNIQUE_PROCESS Process;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string strAppName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string strServiceShortName;
    public int ApplicationType; public uint AppStatus; public uint TSSessionId;
    [MarshalAs(UnmanagedType.Bool)] public bool bRestartable; }
  [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] static extern int RmStartSession(out uint h, int flags, string key);
  [DllImport("rstrtmgr.dll")] static extern int RmEndSession(uint h);
  [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] static extern int RmRegisterResources(uint h, uint nFiles, string[] files, uint nApps, RM_UNIQUE_PROCESS[] apps, uint nServices, string[] services);
  [DllImport("rstrtmgr.dll")] static extern int RmGetList(uint h, out uint needed, ref uint count, [In, Out] RM_PROCESS_INFO[] info, ref uint reasons);
  public static string[] Who(string[] files) {
    var list = new List<string>(); uint h;
    if (RmStartSession(out h, 0, Guid.NewGuid().ToString()) != 0) return list.ToArray();
    try {
      if (RmRegisterResources(h, (uint)files.Length, files, 0, null, 0, null) != 0) return list.ToArray();
      uint needed = 0, count = 0, reasons = 0;
      int r = RmGetList(h, out needed, ref count, null, ref reasons);
      if (r == 234 || (r == 0 && needed > 0)) {
        var info = new RM_PROCESS_INFO[needed]; count = needed;
        r = RmGetList(h, out needed, ref count, info, ref reasons);
        if (r == 0) for (int i = 0; i < count; i++) {
          string name = "";
          try { name = Process.GetProcessById(info[i].Process.dwProcessId).ProcessName; } catch (Exception) {}
          list.Add(info[i].Process.dwProcessId + "|" + name + "|" + info[i].strAppName);
        }
      }
    } finally { RmEndSession(h); }
    return list.ToArray();
  }
}
'@
Add-Type -TypeDefinition $src
[KcLock]::Who($env:KC_FILES.Split('|')) | ForEach-Object { $_ }
""";

/// The programs that really use the app files, never this updater itself. On Windows this asks the
/// Restart Manager about the locked files (and also lists anything running from the app folder);
/// on Linux it looks at open files and loaded libraries; best effort, empty when unknown.
Future<List<_Proc>> _blockingProcesses(String appDir, [List<String> lockedPaths = const []]) async {
  final dir = appDir.endsWith(_sep) ? appDir : '$appDir$_sep';
  final byId = <int, _Proc>{};
  void add(_Proc p) {
    if (p.id != pid && p.id > 4) byId.putIfAbsent(p.id, () => p);
  }

  try {
    if (Platform.isWindows) {
      if (lockedPaths.isNotEmpty) {
        final r = await _powershell(_restartManagerScript, {'KC_FILES': lockedPaths.take(60).join('|')})
            .timeout(const Duration(seconds: 25));
        for (final line in '${r.stdout}'.split(RegExp(r'[\r\n]+'))) {
          final f = line.trim().split('|');
          final id = f.length >= 2 ? int.tryParse(f[0]) : null;
          if (id == null) continue;
          final name = f[1].isEmpty ? 'unknown' : (f[1].toLowerCase().endsWith('.exe') ? f[1] : '${f[1]}.exe');
          add(_Proc(id, name, f.length >= 3 ? f.sublist(2).join('|') : ''));
        }
      }
      final r = await _powershell(
        r"Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($env:KC_DIR, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $_.Id.ToString() + '|' + $_.ProcessName }",
        {'KC_DIR': dir},
      ).timeout(const Duration(seconds: 15));
      for (final line in '${r.stdout}'.split(RegExp(r'[\r\n]+'))) {
        final f = line.trim().split('|');
        final id = f.length == 2 ? int.tryParse(f[0]) : null;
        if (id != null) add(_Proc(id, '${f[1]}.exe'));
      }
    } else {
      for (final e in Directory('/proc').listSync(followLinks: false).whereType<Directory>()) {
        final id = int.tryParse(e.path.split('/').last);
        if (id == null || id == pid) continue;
        var uses = false;
        try {
          uses = Link('${e.path}/exe').targetSync().startsWith(dir);
        } catch (_) {}
        if (!uses) {
          try {
            uses = Directory('${e.path}/fd').listSync(followLinks: false).whereType<Link>().any((l) {
              try {
                return l.targetSync().startsWith(dir);
              } catch (_) {
                return false;
              }
            });
          } catch (_) {}
        }
        if (!uses) {
          try {
            uses = File('${e.path}/maps').readAsStringSync().contains(dir);
          } catch (_) {}
        }
        if (uses) {
          var name = 'unknown';
          try {
            name = File('${e.path}/comm').readAsStringSync().trim();
          } catch (_) {}
          add(_Proc(id, name));
        }
      }
    }
  } catch (_) {}
  return byId.values.toList();
}

/// Runs a PowerShell script (encoded, so no quoting problems); values go in as environment variables.
Future<ProcessResult> _powershell(String script, Map<String, String> env) {
  final bytes = <int>[];
  for (final u in script.codeUnits) {
    bytes..add(u & 0xff)..add(u >> 8);
  }
  return Process.run(
    'powershell',
    ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-EncodedCommand', base64Encode(bytes)],
    environment: env,
  );
}

/// Close other programs for the user (Force close). Never touches this updater or system programs.
Future<void> _forceClose(List<_Proc> procs) async {
  for (final p in procs) {
    if (p.id == pid || p.isProtected) continue;
    _say('force closing $p');
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${p.id}', '/T', '/F']);
      } else {
        await Process.run('kill', ['-9', '${p.id}']);
      }
    } catch (_) {}
  }
  await Future<void>.delayed(const Duration(milliseconds: 1500)); // let the system release the files
}

Future<bool> _isAlive(int id) async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run('tasklist', ['/FI', 'PID eq $id', '/NH', '/FO', 'CSV']);
      return '${r.stdout}'.contains(',"$id",');
    }
    return Directory('/proc/$id').existsSync();
  } catch (_) {
    return false;
  }
}

/// Programs from [procs] that are still running (a normal force close was not enough).
Future<List<_Proc>> _stillRunning(List<_Proc> procs) async => [
      for (final p in procs)
        if (await _isAlive(p.id)) p,
    ];

/// Force close with administrator rights. The system shows its own permission prompt
/// (Windows UAC, Linux polkit); if the user says no, nothing happens.
Future<void> _forceCloseAdmin(List<_Proc> procs) async {
  final ids = [for (final p in procs) if (p.id != pid && !p.isProtected) p.id];
  if (ids.isEmpty) return;
  _say('force closing as administrator: ${ids.join(', ')}');
  try {
    if (Platform.isWindows) {
      final args = [for (final id in ids) '/PID $id', '/T', '/F'].join(' ');
      await _powershell(
        r"try { Start-Process -FilePath 'taskkill.exe' -ArgumentList $env:KC_ARGS -Verb RunAs -Wait -WindowStyle Hidden } catch { exit 1 }",
        {'KC_ARGS': args},
      );
    } else {
      final which = await Process.run('which', ['pkexec']);
      if (which.exitCode == 0) {
        await Process.run('pkexec', ['/bin/kill', '-9', ...ids.map((e) => '$e')]);
      } else {
        await _notify('Khmer Calendar updater',
            'Administrator rights are needed but pkexec was not found. Run this in a terminal, then click Retry:\n\nsudo kill -9 ${ids.join(' ')}');
      }
    }
  } catch (_) {}
  await Future<void>.delayed(const Duration(milliseconds: 1500));
}

enum _Choice { retry, force, admin, cancel }

/// Native dialog (no Flutter here: the app is closed while we update).
/// Without a dialog tool it returns cancel and the failure is reported by the app on the next start.
Future<_Choice> _ask(String title, String message, {required bool canForce, bool canAdmin = false}) async {
  try {
    if (Platform.isWindows) {
      final script = [
        r"Add-Type -AssemblyName System.Windows.Forms",
        r"[System.Windows.Forms.Application]::EnableVisualStyles()",
        r"$global:r = 1",
        r"$f = New-Object System.Windows.Forms.Form",
        r"$f.Text = $env:KC_TITLE; $f.TopMost = $true; $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'",
        r"$f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.ClientSize = New-Object System.Drawing.Size(640, 400)",
        r"$l = New-Object System.Windows.Forms.Label; $l.Text = $env:KC_MSG",
        r"$l.Location = New-Object System.Drawing.Point(15, 15); $l.Size = New-Object System.Drawing.Size(610, 330); $f.Controls.Add($l)",
        r"$global:x = 20",
        r"function Add-Btn($text, $code) { $b = New-Object System.Windows.Forms.Button; $b.Text = $text; $b.Tag = $code",
        r"  $b.Size = New-Object System.Drawing.Size(148, 32); $b.Location = New-Object System.Drawing.Point($global:x, 352); $global:x += 153",
        r"  $b.Add_Click({ $global:r = [int]$this.Tag; $this.FindForm().Close() }); $f.Controls.Add($b) }",
        r"Add-Btn 'Retry' 0",
        r"if ($env:KC_FORCE -eq '1') { Add-Btn 'Force close' 2 }",
        r"if ($env:KC_ADMIN -eq '1') { Add-Btn 'Force as administrator' 3 }",
        r"Add-Btn 'Cancel' 1",
        r"[void]$f.ShowDialog()",
        r"exit $global:r",
      ].join('\n');
      final r = await _powershell(script, {'KC_MSG': message, 'KC_TITLE': title, 'KC_FORCE': canForce ? '1' : '0', 'KC_ADMIN': canAdmin ? '1' : '0'});
      return switch (r.exitCode) { 0 => _Choice.retry, 2 => _Choice.force, 3 => _Choice.admin, _ => _Choice.cancel };
    }
    if (Platform.isLinux) {
      final zenity = await Process.run('which', ['zenity']);
      if (zenity.exitCode == 0) {
        final r = await Process.run('zenity', [
          '--question', '--title=$title', '--text=$message',
          '--ok-label=Retry', '--cancel-label=Cancel',
          if (canForce) '--extra-button=Force close',
          if (canAdmin) '--extra-button=Force as administrator',
          '--width=460',
        ]);
        if ('${r.stdout}'.contains('Force as administrator')) return _Choice.admin;
        if ('${r.stdout}'.contains('Force close')) return _Choice.force;
        return r.exitCode == 0 ? _Choice.retry : _Choice.cancel;
      }
      final kdialog = await Process.run('which', ['kdialog']);
      if (kdialog.exitCode == 0) {
        // kdialog has three buttons: yes / no / cancel
        if (canAdmin) {
          final r = await Process.run('kdialog', ['--title', title, '--yes-label', 'Force as administrator', '--no-label', 'Retry', '--cancel-label', 'Cancel', '--yesnocancel', message]);
          return r.exitCode == 0 ? _Choice.admin : (r.exitCode == 1 ? _Choice.retry : _Choice.cancel);
        }
        if (canForce) {
          final r = await Process.run('kdialog', ['--title', title, '--yes-label', 'Force close', '--no-label', 'Retry', '--cancel-label', 'Cancel', '--yesnocancel', message]);
          return r.exitCode == 0 ? _Choice.force : (r.exitCode == 1 ? _Choice.retry : _Choice.cancel);
        }
        final r = await Process.run('kdialog', ['--title', title, '--yes-label', 'Retry', '--no-label', 'Cancel', '--yesno', message]);
        return r.exitCode == 0 ? _Choice.retry : _Choice.cancel;
      }
    }
  } catch (_) {}
  return _Choice.cancel;
}

/// Yes / No question in a native dialog. Returns false when there is no dialog tool.
Future<bool> _confirm(String title, String message, {String yes = 'Reinstall', String no = 'Cancel'}) async {
  try {
    if (Platform.isWindows) {
      final r = await _powershell(
        r"Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}; "
        r"$a = [System.Windows.Forms.MessageBox]::Show($f, $env:KC_MSG, $env:KC_TITLE, 'YesNo', 'Question'); "
        r"if ($a -eq 'Yes') { exit 0 } else { exit 1 }",
        {'KC_MSG': message, 'KC_TITLE': title},
      );
      return r.exitCode == 0;
    }
    if (Platform.isLinux) {
      final zenity = await Process.run('which', ['zenity']);
      if (zenity.exitCode == 0) {
        final r = await Process.run('zenity', [
          '--question', '--title=$title', '--text=$message',
          '--ok-label=$yes', '--cancel-label=$no', '--width=420',
        ]);
        return r.exitCode == 0;
      }
      final kdialog = await Process.run('which', ['kdialog']);
      if (kdialog.exitCode == 0) {
        final r = await Process.run('kdialog', ['--title', title, '--yes-label', yes, '--no-label', no, '--yesno', message]);
        return r.exitCode == 0;
      }
    }
  } catch (_) {}
  return false;
}

/// Wait until the files we must replace are free. If another program keeps them locked, tell the
/// user which one and let them close it and retry, or force close it. Nothing is copied until
/// everything is free, so a blocked update never leaves a half-updated app.
Future<void> _waitForUnlocked(Directory from, Directory to) async {
  var asked = 0;
  var forceTried = false;
  while (true) {
    var locked = <String>[];
    for (var i = 0; i < 15; i++) {
      locked = _lockedFiles(from, to);
      if (locked.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    final procs = await _blockingProcesses(to.path, locked.map((r) => '${to.path}$_sep$r').toList());
    _say('files locked: ${locked.take(10).join(', ')}; programs: ${procs.join(', ')}');
    final shown = locked.take(4).join('\n');
    final more = locked.length > 4 ? '\n... and ${locked.length - 4} more' : '';
    final closable = procs.where((p) => !p.isProtected).toList();
    final system = procs.where((p) => p.isProtected).toList();
    final who = procs.isEmpty
        ? 'Could not tell which program is using them. Close any other program that might (including another copy of Khmer Calendar, or a File Explorer window showing the app folder).'
        : 'Programs using these files:\n${procs.map((p) => '  - $p${p.isProtected ? '  (system program)' : ''}').join('\n')}\n\n'
            'Close ${closable.isEmpty ? 'them' : (closable.length == 1 ? 'it' : 'them')}${system.isEmpty ? '' : ' (or the window that uses the app folder)'}, or click Force close and the updater will close ${closable.isEmpty ? 'it' : 'the ones it can'} for you (unsaved work in it is lost).';
    // A normal force close was tried and something is still running: offer administrator rights.
    final stuck = forceTried ? await _stillRunning(closable) : <_Proc>[];
    final adminNote = stuck.isEmpty
        ? ''
        : '\n\nForce close could not close: ${stuck.join(', ')}.\nClick Force as administrator to try with administrator rights (the system asks you to confirm).';
    final choice = asked >= 5
        ? _Choice.cancel
        : await _ask(
            'Khmer Calendar update',
            'The update could not be installed because some app files are in use by a running program.\n\n'
                '$who$adminNote\n\nFiles in use:\n$shown$more\n\nClick Retry after closing it, or Cancel to keep the current version.',
            canForce: closable.isNotEmpty,
            canAdmin: stuck.isNotEmpty,
          );
    asked++;
    if (choice == _Choice.cancel) throw _Blocked(locked, procs.map((e) => '$e').toList());
    if (choice == _Choice.force) {
      await _forceClose(procs);
      forceTried = true;
    }
    if (choice == _Choice.admin) await _forceCloseAdmin(closable);
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
    if (_isSelf(dest.path)) {
      _say('skipping the running updater: $rel');
      continue;
    }
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

// ---------------------------------------------------------------- version check (standalone)

List<int> _versionParts(String v) {
  final m = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?').firstMatch(v.trim());
  if (m == null) return const [0, 0, 0, 0];
  return [for (var i = 1; i <= 4; i++) int.tryParse(m.group(i) ?? '') ?? 0];
}

int _compareVersions(String a, String b) {
  final x = _versionParts(a), y = _versionParts(b);
  for (var i = 0; i < 4; i++) {
    final c = x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// Version of the installed app: Flutter writes data/flutter_assets/version.json into every desktop bundle.
/// Returns (versionName, buildNumber), either may be null when unknown.
Future<(String?, int?)> _installedVersion(String appDir, String exe) async {
  try {
    final f = File('$appDir${_sep}data${_sep}flutter_assets${_sep}version.json');
    if (f.existsSync()) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final v = '${j['version'] ?? ''}'.trim();
      if (v.isNotEmpty) return (v, int.tryParse('${j['build_number'] ?? ''}'));
    }
  } catch (_) {}
  if (Platform.isWindows) {
    try {
      final r = await _powershell(
        r"[System.Diagnostics.FileVersionInfo]::GetVersionInfo($env:KC_EXE).ProductVersion",
        {'KC_EXE': '$appDir$_sep$exe'},
      ).timeout(const Duration(seconds: 15));
      final v = '${r.stdout}'.trim();
      if (RegExp(r'^\d+\.\d+').hasMatch(v)) return (v, null);
    } catch (_) {}
  }
  return (null, null);
}

/// How the published release compares with the installed app. Decided only by version.txt
/// (versionName, then versionCode) against the installed app. Publish dates are never used.
enum _Compare { newer, same, ahead, unknown }

_Compare _compareInstalled({
  required String? installedVersion,
  required int? installedBuild,
  required String remoteVersion,
  required int? remoteBuild,
}) {
  if (installedVersion == null) return _Compare.unknown; // cannot tell: let the user update
  final c = _compareVersions(remoteVersion, installedVersion);
  if (c > 0) return _Compare.newer;
  if (c < 0) return _Compare.ahead;
  if (installedBuild != null && remoteBuild != null) {
    if (remoteBuild > installedBuild) return _Compare.newer;
    if (remoteBuild < installedBuild) return _Compare.ahead;
  }
  return _Compare.same;
}

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

    // 3. Is there anything newer than what is installed?
    final remoteCode = int.tryParse(RegExp(r'^\s*versionCode\s*=\s*(\d+)', multiLine: true).firstMatch(versionText)?.group(1) ?? '');
    final (installedV, installedCode) = await _installedVersion(appDir, exe);
    final cmp = _compareInstalled(
      installedVersion: installedV,
      installedBuild: installedCode,
      remoteVersion: version,
      remoteBuild: remoteCode,
    );
    if (!a.containsKey('force-update')) {
      if (cmp == _Compare.ahead) {
        final msg = 'Your version (v$installedV) is newer than the published one (v$version).';
        _say(msg);
        await _notify(title, '$msg\n\nNo update is needed.');
        return;
      }
      if (cmp == _Compare.same) {
        _say('same version (v$installedV), asking to reinstall');
        final again = await _confirm(
          title,
          'You already have the latest version (v$installedV).\n\nDo you want to reinstall it anyway?',
        );
        if (!again) {
          _say('reinstall declined');
          return;
        }
      }
    }

    // 4. Download.
    final dl = Directory('${Directory.systemTemp.path}${_sep}khmer_update_dl');
    if (dl.existsSync()) dl.deleteSync(recursive: true);
    dl.createSync(recursive: true);
    final archive = File('${dl.path}$_sep${asset['name']}');
    _say('downloading ${asset['name']} (v$version)...');
    await _downloadFile(asset['browser_download_url'] as String, archive, (asset['size'] as num?)?.toInt() ?? 0);

    // 5. Close the app if it runs, then update.
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
