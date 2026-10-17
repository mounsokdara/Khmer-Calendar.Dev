import 'dart:ffi' show Abi;

/// CPU architecture of the running app: 'arm32', 'arm64' or 'x64' (null when unknown).
String? deviceArch() {
  final a = Abi.current();
  if (a == Abi.androidArm || a == Abi.linuxArm) return 'arm32';
  if (a == Abi.androidArm64 || a == Abi.windowsArm64 || a == Abi.macosArm64 || a == Abi.linuxArm64) return 'arm64';
  if (a == Abi.androidX64 || a == Abi.windowsX64 || a == Abi.macosX64 || a == Abi.linuxX64) return 'x64';
  return null;
}
