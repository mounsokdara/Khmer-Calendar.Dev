// Portable launcher for KhmerCalendar-windows-universal.zip.
//
// Layout expected next to this exe:
//   x64/khmer_calendar.exe
//   arm64/khmer_calendar.exe
//
// Detects the host CPU, starts the matching binary (detached), then exits.
// Compiled with `dart compile exe` and flipped to the GUI subsystem so no
// console window appears.

import 'dart:io';

bool _isArm64() {
  final arch = (Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '').toUpperCase();
  final arch6432 =
      (Platform.environment['PROCESSOR_ARCHITEW6432'] ?? '').toUpperCase();
  return arch == 'ARM64' || arch6432 == 'ARM64';
}

String _dirOf(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  if (i <= 0) return '.';
  return path.substring(0, i);
}

Future<void> main(List<String> args) async {
  final self = Platform.resolvedExecutable;
  final root = _dirOf(self);
  final sub = _isArm64() ? 'arm64' : 'x64';
  final target = [
    root,
    sub,
    'khmer_calendar.exe',
  ].join(Platform.pathSeparator);

  if (!File(target).existsSync()) {
    // Last-ditch: same folder (single-arch portable reuse).
    final fallback = [root, 'khmer_calendar.exe'].join(Platform.pathSeparator);
    if (File(fallback).existsSync()) {
      await Process.start(
        fallback,
        args,
        mode: ProcessStartMode.detached,
        workingDirectory: root,
      );
      return;
    }
    stderr.writeln('Khmer Calendar not found for $sub at:\n  $target');
    exitCode = 1;
    return;
  }

  await Process.start(
    target,
    args,
    mode: ProcessStartMode.detached,
    workingDirectory: [root, sub].join(Platform.pathSeparator),
  );
}
