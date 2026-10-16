import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notify_stub.dart' if (dart.library.html) 'notify_web.dart' as webnotify;
import 'notify/kinds.dart';
import 'store.dart';

final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;
var _bound = false;
Timer? _syncDebounce;
Timer? _webTick;
final _fired = <String>{};
var _webShots = <ReminderShot>[];
String _reminderSig = '';



NotificationDetails _detailsFor(String channel) {
  final android = switch (channel) {
    'public' => const AndroidNotificationDetails(
        'khmer_public',
        'Public holidays',
        channelDescription: 'Public holiday alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
      ),
    'religious' || 'others' => const AndroidNotificationDetails(
        'khmer_religious',
        'Other holidays',
        channelDescription: 'Alerts for other holidays',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
        color: Color(0xFF1E88E5),
      ),
    'tasks' => const AndroidNotificationDetails(
        'khmer_tasks',
        'Tasks',
        channelDescription: 'Task reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
      ),
    'sil' => const AndroidNotificationDetails(
        'khmer_sil',
        'Silas days',
        channelDescription: 'Silas day alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
      ),
    'daily' => const AndroidNotificationDetails(
        'khmer_daily',
        'Daily reminder',
        channelDescription: 'Morning calendar recap',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: 'ic_stat_notify',
      ),
    _ => const AndroidNotificationDetails(
        'khmer_tasks',
        'Tasks',
        channelDescription: 'Task reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notify',
      ),
  };
  return NotificationDetails(
    android: android,
    iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    linux: const LinuxNotificationDetails(),
  );
}

void bindReminderSync(AppStore store) {
  if (_bound) return;
  _bound = true;
  store.addListener(() {
    final sig = _reminderSignature(store);
    if (store.notifyOn) {
      if (sig == _reminderSig) return;
    } else if (_reminderSig.isEmpty) {
      return;
    }
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 400), () => syncReminders(store));
  });
}

Future<void> initReminderEngine() async {
  if (_ready) return;
  if (kIsWeb) {
    _ready = true;
    return;
  }
  try {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Phnom_Penh'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
    const android = AndroidInitializationSettings('ic_stat_notify');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const windows = WindowsInitializationSettings(
      appName: 'Khmer Calendar',
      appUserModelId: 'MounSokdara.KhmerCalendar',
      guid: 'c4e8f1a2-9b7d-4c3e-8f16-2a91d05b6e44',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );
    await _plugin.initialize(settings);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'khmer_reminders',
        'Reminders',
        description: 'Task and holiday reminders',
        importance: Importance.high,
      ),
    );
    _ready = true;
  } catch (e) {
    debugPrint('reminders init: $e');
  }
}

Future<bool> requestOsNotificationPermission() async {
  if (kIsWeb) return webnotify.requestBrowserNotification();
  await initReminderEngine();
  var ok = false;
  try {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    if (a == true) ok = true;
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  } catch (e) {
    debugPrint('android notify request: $e');
  }
  try {
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    if (i == true) ok = true;
  } catch (e) {
    debugPrint('ios notify request: $e');
  }
  try {
    final mac = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    final m = await mac?.requestPermissions(alert: true, badge: true, sound: true);
    if (m == true) ok = true;
  } catch (e) {
    debugPrint('mac notify request: $e');
  }
  if (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows) {
    ok = ok || _ready;
  }
  return ok;
}

Future<void> cancelAllReminders() async {
  _reminderSig = '';
  _webTick?.cancel();
  _webTick = null;
  _webShots = [];
  if (!_ready || kIsWeb) return;
  try {
    await _plugin.cancelAll();
  } catch (_) {}
}

List<ReminderShot> _collect(AppStore store) {
  final now = DateTime.now();
  final skipNative = androidNativeAlarms;
  final out = <ReminderShot>[];
  for (final kind in reminderKinds) {
    if (!kind.enabled(store)) continue;
    if (skipNative && kind.nativeAndroid) continue;
    out.addAll(kind.collect(store, now));
  }
  return out;
}

void _fireWebDue() {
  if (!webnotify.isBrowserNotificationGranted()) return;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  for (final p in _webShots) {
    if (_fired.contains(p.key)) continue;
    if (p.when.isAfter(now.add(const Duration(seconds: 20)))) continue;
    if (p.when.isBefore(todayStart)) continue;
    _fired.add(p.key);
    webnotify.showBrowserNotification(p.title, p.resolveBody(), tag: p.key);
  }
}

void _armWeb(List<ReminderShot> shots) {
  _webShots = shots;
  _webTick?.cancel();
  _webTick = Timer.periodic(const Duration(seconds: 15), (_) => _fireWebDue());
  _fireWebDue();
}

Future<void> _scheduleNative(ReminderShot shot, int id, bool exact) async {
  if (shot.when.isBefore(DateTime.now())) return;
  final when = tz.TZDateTime.from(shot.when, tz.local);
  final body = shot.resolveBody();
  Future<void> run(AndroidScheduleMode mode) {
    return _plugin.zonedSchedule(id, shot.title, body, when, _detailsFor(shot.channel), androidScheduleMode: mode);
  }

  try {
    await run(exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle);
  } catch (err) {
    debugPrint('schedule $id: $err');
    if (exact) {
      try {
        await run(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (err2) {
        debugPrint('schedule fallback $id: $err2');
      }
    }
  }
}

String _reminderSignature(AppStore store) =>
    '${store.notifyOn}|${store.notifyDaily}|${store.notifySil}|${store.notifyPublic}|${store.notifyOthers}|${store.notifyTasks}|${store.notifyTomorrow}|${store.backgroundOn}|${store.lang}|${store.events.map((e) => '${e.id}:${e.date}:${e.endDate}:${e.startTime}:${e.reminderDate}:${e.reminderTime}:${e.done}').join(',')}';

List<ReminderShot> _pluginPending(List<ReminderShot> shots) {
  final now = DateTime.now();
  final future = shots.where((s) => s.when.isAfter(now)).toList()..sort((a, b) => a.when.compareTo(b.when));
  if (defaultTargetPlatform != TargetPlatform.iOS) return future;
  const iosPendingCap = 60;
  if (future.length <= iosPendingCap) return future;
  return future.sublist(0, iosPendingCap);
}

Future<void> syncReminders(AppStore store) async {
  if (!_ready) {
    if (store.notifyOn) await initReminderEngine();
    if (!_ready) return;
  }
  if (!store.notifyOn) {
    _reminderSig = '';
    await cancelAllReminders();
    return;
  }
  final sig = _reminderSignature(store);
  if (sig == _reminderSig) return;
  _reminderSig = sig;
  if (!androidNativeAlarms) await ensureNotifyLists();
  final shots = _collect(store);
  if (kIsWeb) {
    _armWeb(shots);
    return;
  }
  try {
    await _plugin.cancelAll();
  } catch (_) {}
  var id = 1;
  for (final shot in _pluginPending(shots)) {
    await _scheduleNative(shot, id++, store.backgroundOn);
  }
}
