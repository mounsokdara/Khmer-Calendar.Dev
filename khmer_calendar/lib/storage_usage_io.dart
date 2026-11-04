import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Files the user saved (custom wheel sound). They are data, never cache.
const _userPrefix = 'wheel_custom_';

/// Weather icons and city photos downloaded by wx_cache_io.dart. They sit in the support folder.
const _cachePrefix = 'wx_';

String _fileName(FileSystemEntity e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last;

/// Keeps one entry per real folder and drops folders that live inside another one in the list.
List<Directory> _dedupe(List<Directory> dirs) {
  final sep = Platform.pathSeparator;
  final paths = <String>{};
  for (final d in dirs) {
    var p = d.path;
    try {
      p = d.resolveSymbolicLinksSync();
    } catch (_) {}
    paths.add(p);
  }
  final sorted = paths.toList()..sort((a, b) => a.length.compareTo(b.length));
  final keep = <String>[];
  for (final p in sorted) {
    final nested = keep.any((k) => p == k || p.startsWith(k.endsWith(sep) ? k : '$k$sep'));
    if (!nested) keep.add(p);
  }
  return keep.map(Directory.new).toList();
}

/// True for the shared system temp folder, which must never be emptied (Linux /tmp, Windows %TEMP%).
bool _isSystemTemp(Directory d) {
  String norm(String p) {
    try {
      return Directory(p).resolveSymbolicLinksSync();
    } catch (_) {
      return p;
    }
  }

  return norm(d.path) == norm(Directory.systemTemp.path);
}

/// Folders whose whole content is cache. This is what Android's Settings > Clear cache empties too.
Future<List<Directory>> _cacheRoots() async {
  final found = <Directory>[];
  try {
    found.add(await getApplicationCacheDirectory());
  } catch (_) {}
  // Android and iOS keep the temporary folder private to the app. On desktop it is the shared system
  // temp folder, so it is deliberately left out there.
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      found.add(await getTemporaryDirectory());
    } catch (_) {}
  }
  if (Platform.isAndroid) {
    try {
      final ext = await getExternalCacheDirectories();
      if (ext != null) found.addAll(ext);
    } catch (_) {}
  }
  return _dedupe(found).where((d) => !_isSystemTemp(d)).toList();
}

/// Everything that can be deleted and rebuilt later: the entries inside the cache folders, the
/// desktop update download folder and the cached weather files.
Future<List<FileSystemEntity>> _cacheEntries() async {
  final out = <FileSystemEntity>[];
  final seen = <String>{};
  void add(FileSystemEntity e) {
    if (seen.add(e.path)) out.add(e);
  }

  for (final root in await _cacheRoots()) {
    try {
      if (!await root.exists()) continue;
      await for (final e in root.list(followLinks: false)) {
        add(e);
      }
    } catch (_) {}
  }
  try {
    final dl = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}khmer_update_dl');
    if (await dl.exists()) add(dl);
  } catch (_) {}
  try {
    final support = await getApplicationSupportDirectory();
    if (await support.exists()) {
      await for (final e in support.list(followLinks: false)) {
        if (e is File && _fileName(e).startsWith(_cachePrefix)) add(e);
      }
    }
  } catch (_) {}
  return out;
}

Future<int> _sizeOf(FileSystemEntity e) async {
  var n = 0;
  try {
    if (e is File) return await e.length();
    if (e is Directory) {
      await for (final c in e.list(recursive: true, followLinks: false)) {
        if (c is File) {
          try {
            n += await c.length();
          } catch (_) {}
        }
      }
    }
  } catch (_) {}
  return n;
}

/// Bytes currently taken by the cache.
Future<int> cacheBytes() async {
  var n = 0;
  for (final e in await _cacheEntries()) {
    n += await _sizeOf(e);
  }
  return n;
}

/// Deletes the cache from disk and returns how many bytes were really freed.
Future<int> clearCacheFiles() async {
  var freed = 0;
  for (final e in await _cacheEntries()) {
    final size = await _sizeOf(e);
    try {
      await e.delete(recursive: true);
      freed += size;
    } catch (_) {
      // Something inside is in use or protected: only count what actually went away.
      final left = await _sizeOf(e);
      if (size > left) freed += size - left;
    }
  }
  return freed;
}

/// Bytes of files the user saved on disk (custom sound). Not part of the cache.
Future<int> userFilesBytes() async {
  var n = 0;
  try {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && _fileName(e).startsWith(_userPrefix)) {
        try {
          n += await e.length();
        } catch (_) {}
      }
    }
  } catch (_) {}
  return n;
}
