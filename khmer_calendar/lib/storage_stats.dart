import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar/chhankitek.dart' show khmerNum;
import 'i18n.dart';
import 'storage_usage.dart';
import 'store.dart';
import 'weather.dart' show clearWeatherMemoryCache;

/// What the app keeps on this device.
class StorageStats {
  const StorageStats({required this.dataBytes, required this.cacheBytes});

  /// Settings, events and reminders (and the custom sound) the user would lose by clearing data.
  final int dataBytes;

  /// Files the app downloaded and can fetch again.
  final int cacheBytes;

  int get totalBytes => dataBytes + cacheBytes;
}

int _valueBytes(Object? v) {
  if (v is String) return utf8.encode(v).length;
  if (v is List) {
    var n = 0;
    for (final s in v) {
      n += _valueBytes(s);
    }
    return n;
  }
  if (v is bool) return 1;
  if (v is int || v is double) return 8;
  return 0;
}

/// Size of everything saved through SharedPreferences (settings, events, reminders, weather cities).
Future<int> _prefsBytes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    var n = 0;
    for (final k in prefs.getKeys()) {
      n += utf8.encode(k).length + _valueBytes(prefs.get(k));
    }
    return n;
  } catch (_) {
    return 0;
  }
}

Future<StorageStats> loadStorageStats() async {
  final r = await Future.wait<int>([_prefsBytes(), userFilesBytes(), cacheBytes()]);
  return StorageStats(dataBytes: r[0] + r[1], cacheBytes: r[2]);
}

/// Deletes every file the app can rebuild plus the in-memory copies, and returns the bytes freed on disk.
Future<int> clearAppCache() async {
  final freed = await clearCacheFiles();
  try {
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
  } catch (_) {}
  clearWeatherMemoryCache();
  return freed;
}

/// Number of events that have a reminder set.
int reminderCount(AppStore store) => store.events.where((e) => (e.reminderDate ?? '').isNotEmpty).length;

String formatCount(int n, Lang lang) => lang == Lang.en ? '$n' : khmerNum(n);

/// "12.4 MB" with Khmer digits when the app is in Khmer.
String formatBytes(int bytes, Lang lang) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes < 0 ? 0.0 : bytes.toDouble();
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  final s = u == 0 ? '${v.round()}' : (v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));
  return '${lang == Lang.en ? s : khmerNum(s)} ${units[u]}';
}
