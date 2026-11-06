import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'autostart_io.dart' if (dart.library.html) 'autostart_stub.dart' as autostart;
import 'home_screen.dart';
import 'i18n.dart';
import 'location.dart';
import 'notify/kinds.dart';
import 'notify_stub.dart' if (dart.library.html) 'notify_web.dart' as webnotify;
import 'reminders.dart';
import 'store.dart';
import 'custom_components/slide_snackbar.dart';
import 'widgets/dialog_actions.dart';

const _channel = MethodChannel('khmer.permissions');

class OsPerms {
  const OsPerms({
    required this.notify,
    required this.background,
    required this.autoLaunch,
    required this.location,
    this.autoStartQueryable = false,
  });

  final bool notify;
  final bool background;
  final bool autoLaunch;
  final bool location;
  final bool autoStartQueryable;
}

Future<bool> _native(String method, [Map<String, dynamic>? args]) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final r = await _channel.invokeMethod<bool>(method, args);
    return r ?? false;
  } catch (e) {
    debugPrint('native $method: $e');
    return false;
  }
}

Future<Map<String, bool>> _androidStatus() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return {};
  try {
    final r = await _channel.invokeMethod<dynamic>('checkStatus');
    if (r is Map) {
      return r.map((k, v) => MapEntry('$k', v == true));
    }
  } catch (e) {
    debugPrint('checkStatus: $e');
  }
  return {};
}

bool get _android {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool get _apple {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get _desktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> _syncNativeFlags(AppStore store) async {
  await _native('setFlags', {
    'background': store.backgroundOn,
    'autoLaunch': store.autoLaunchOn,
  });
}

/// Desktop: register login bg helper and start it when background mode is on.
Future<void> _desktopBackgroundOn() async {
  if (!_desktop) return;
  try {
    await autostart.enableDesktopAutostart();
    await autostart.ensureDesktopBackgroundRunning();
  } catch (e) {
    debugPrint('desktop background on: $e');
  }
}

Future<void> _desktopBackgroundOff() async {
  if (!_desktop) return;
  try {
    await autostart.disableDesktopAutostart();
  } catch (e) {
    debugPrint('desktop background off: $e');
  }
}

Future<void> _pause() async {
  await Future<void>.delayed(const Duration(milliseconds: 280));
}

Future<bool> _confirm(
  BuildContext? context,
  Lang lang,
  String titleKey,
  String bodyKey,
) async {
  final ctx = context;
  if (ctx == null || !ctx.mounted) return false;
  final ok = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(t(lang, titleKey)),
      content: Text(t(lang, bodyKey)),
      actions: equalDialogActions([
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: dialogBtnStyle(),
          child: dlgLabel(t(lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: dialogBtnStyle(),
          child: dlgLabel(t(lang, 'ok')),
        ),
      ]),
    ),
  );
  return ok == true;
}

bool _canGrant(String kind) {
  if (kIsWeb) return kind == 'notify' || kind == 'location';
  if (kind == 'auto' && defaultTargetPlatform == TargetPlatform.iOS) return false;
  return true;
}

String _kindTitleKey(String kind) {
  switch (kind) {
    case 'notify':
      return 'setupAllowNotify';
    case 'background':
      return 'setupAllowBackground';
    case 'auto':
      return 'setupAllowAutoLaunch';
    default:
      return 'setupAllowGps';
  }
}

Future<void> _waitForResume() async {
  var left = false;
  final done = Completer<void>();
  final listener = AppLifecycleListener(
    onHide: () => left = true,
    onPause: () => left = true,
    onInactive: () => left = true,
    onResume: () {
      if (!done.isCompleted) done.complete();
    },
  );
  try {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!left) return;
    await done.future.timeout(const Duration(minutes: 10), onTimeout: () {});
  } finally {
    listener.dispose();
  }
}

Future<void> _openSettingsFor(String kind) async {
  if (_android) {
    switch (kind) {
      case 'notify':
        await _native('openAppSettings');
        return;
      case 'background':
        await _native('requestBatteryExemption');
        return;
      case 'auto':
        await _native('openAutoStart');
        return;
      case 'location':
        await _native('openLocationSettings');
        await _native('openAppSettings');
        return;
    }
  }
  final wait = _waitForResume();
  try {
    if (kind == 'location') {
      await Geolocator.openAppSettings();
    } else {
      await openAppSettings();
    }
  } catch (e) {
    debugPrint('openSettings $kind: $e');
  }
  await wait;
}

Future<bool> promptIfDenied(
  AppStore store, {
  BuildContext? context,
  required String kind,
  required Future<bool> Function() allowed,
}) async {
  if (await allowed()) return true;
  if (!_canGrant(kind)) return true;
  final ctx = context;
  if (ctx == null || !ctx.mounted) return false;
  final open = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      title: Text(t(store.lang, 'permNotAllowed')),
      content: Text(
          '${t(store.lang, _kindTitleKey(kind))}\n\n${t(store.lang, 'permOpenSettingsBody')}'),
      actions: equalDialogActions([
        OutlinedButton(
          onPressed: () => Navigator.pop(d, false),
          style: dialogBtnStyle(),
          child: dlgLabel(t(store.lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          style: dialogBtnStyle(),
          child: dlgLabel(t(store.lang, 'permOpenSettings')),
        ),
      ]),
    ),
  );
  if (open != true) return false;
  await _openSettingsFor(kind);
  await _pause();
  return allowed();
}

Future<bool> notificationsAllowed() async {
  if (kIsWeb) return webnotify.isBrowserNotificationGranted();
  if (_android) {
    final native = (await _androidStatus())['notify'] ?? false;
    PermissionStatus status = PermissionStatus.denied;
    try {
      status = await Permission.notification.status;
    } catch (_) {}
    return native ||
        status.isGranted ||
        status.isLimited ||
        status.isProvisional;
  }
  try {
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  } catch (_) {
    return false;
  }
}

Future<bool> backgroundAllowed() async {
  if (kIsWeb) return false;
  if (_android) {
    final s = await _androidStatus();
    if (s['battery'] == true) return true;
    try {
      return (await Permission.ignoreBatteryOptimizations.status).isGranted;
    } catch (_) {
      return false;
    }
  }
  if (_apple) return notificationsAllowed();
  return true;
}

Future<bool> autoLaunchAllowed() async {
  if (kIsWeb) return false;
  if (_desktop) {
    try {
      return await autostart.isDesktopAutostartEnabled();
    } catch (_) {
      return false;
    }
  }
  if (_android) return true;
  return false;
}

Future<bool> locationAllowed() async {
  try {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

Future<OsPerms> readOsPermissions() async {
  final notify = await notificationsAllowed();
  final background = await backgroundAllowed();
  final autoLaunch = await autoLaunchAllowed();
  final location = await locationAllowed();
  var queryable = false;
  if (_desktop) {
    queryable = true;
  }
  return OsPerms(
    notify: notify,
    background: background,
    autoLaunch: autoLaunch,
    location: location,
    autoStartQueryable: queryable,
  );
}

Future<void> keepOnlyGranted(AppStore store) async {
  final os = await readOsPermissions();
  if (store.notifyOn && !os.notify) store.setNotifyOn(false);
  if (store.backgroundOn && !os.background) store.setBackgroundOn(false);
  if (!_android && store.autoLaunchOn && !os.autoLaunch) {
    store.setAutoLaunchOn(false);
  }
  if (store.locationOn && !os.location) store.setLocationOn(false);
  await _syncNativeFlags(store);
  if (!store.notifyOn) await cancelAllReminders();
}

Future<void> writeGrantedFlags(AppStore store) async {
  final os = await readOsPermissions();
  store.setNotifyOn(os.notify);
  store.setBackgroundOn(os.background);
  if (!_android) store.setAutoLaunchOn(os.autoLaunch);
  store.setLocationOn(os.location);
  await _syncNativeFlags(store);
  if (os.notify) {
    await initReminderEngine();
  } else {
    await cancelAllReminders();
  }
}

Future<bool> requestNotifications(AppStore store) async {
  try {
    if (kIsWeb) {
      await webnotify.requestBrowserNotification();
    } else {
      await requestOsNotificationPermission();
      try {
        await Permission.notification.request();
      } catch (e) {
        debugPrint('permission_handler notify: $e');
      }
    }
  } catch (e) {
    debugPrint('requestNotifications: $e');
  }
  final ok = await notificationsAllowed();
  store.setNotifyOn(ok);
  if (ok) {
    await initReminderEngine();
  } else {
    await cancelAllReminders();
  }
  return ok;
}

Future<bool> requestBackground(AppStore store, {BuildContext? context}) async {
  if (kIsWeb) {
    store.setBackgroundOn(false);
    return false;
  }
  try {
    if (_android) {
      if (!await backgroundAllowed()) {
        await _pause();
        await _native('requestBatteryExemption');
      }
      try {
        await Permission.scheduleExactAlarm.request();
      } catch (_) {}
      await _pause();
      await _native('requestExactAlarm');
    } else if (_apple) {
      await requestOsNotificationPermission();
    }
  } catch (e) {
    debugPrint('requestBackground: $e');
  }
  final ok = await backgroundAllowed();
  store.setBackgroundOn(ok);
  await _syncNativeFlags(store);
  if (ok) {
    await initReminderEngine();
    // Desktop: turn on login bg helper and start it now.
    if (_desktop) {
      store.setAutoLaunchOn(true);
      await _desktopBackgroundOn();
    }
  }
  return ok;
}

Future<void> stopBackground(AppStore store) async {
  store.setBackgroundOn(false);
  await _syncNativeFlags(store);
  if (_desktop) {
    store.setAutoLaunchOn(false);
    await _desktopBackgroundOff();
  }
}

Future<bool> requestAutoLaunch(AppStore store, {BuildContext? context}) async {
  if (kIsWeb) {
    store.setAutoLaunchOn(false);
    return false;
  }
  try {
    if (_android) {
      final s = await _androidStatus();
      if (s['oemAutoStart'] == true) {
        final ctx = context;
        if (ctx != null && ctx.mounted) {
          final go = await _confirm(
              ctx, store.lang, 'autoLaunchConfirm', 'autoLaunchConfirmSub');
          if (!go) {
            store.setAutoLaunchOn(false);
            await _syncNativeFlags(store);
            return false;
          }
        }
        await _native('openAutoStart');
        await _waitForResume();
      }
      store.setAutoLaunchOn(true);
      await _syncNativeFlags(store);
      return true;
    }
    if (_desktop) {
      try {
        await autostart.enableDesktopAutostart();
        await autostart.ensureDesktopBackgroundRunning();
      } catch (e) {
        debugPrint('desktop autostart: $e');
      }
    }
  } catch (e) {
    debugPrint('requestAutoLaunch: $e');
  }
  final ok = await autoLaunchAllowed();
  store.setAutoLaunchOn(ok);
  await _syncNativeFlags(store);
  return ok;
}

Future<void> stopAutoLaunch(AppStore store) async {
  store.setAutoLaunchOn(false);
  await _syncNativeFlags(store);
  if (_desktop) {
    try {
      await autostart.disableDesktopAutostart();
    } catch (_) {}
  }
}

Future<GpsResult> requestLocationPerm(AppStore store) async {
  GpsResult r = GpsResult.denied;
  try {
    r = await requestNearbyCity(store);
  } catch (e) {
    debugPrint('requestLocationPerm: $e');
  }
  final ok = await locationAllowed();
  store.setLocationOn(ok);
  if (!ok) {
    if (r != GpsResult.disabled) r = GpsResult.denied;
  }
  return r;
}

Future<bool> requestAllPermissions(
  AppStore store, {
  BuildContext? context,
  void Function(String key)? onStep,
}) async {
  Future<bool> step(String asking, String kind, Future<void> Function() ask,
      Future<bool> Function() allowed) async {
    onStep?.call(asking);
    try {
      await ask();
    } catch (e) {
      debugPrint('all/$kind: $e');
    }
    onStep?.call(asking);
    final ctx = context;
    final ok = await promptIfDenied(
      store,
      context: ctx != null && ctx.mounted ? ctx : null,
      kind: kind,
      allowed: allowed,
    );
    return ok;
  }

  if (!await step('askingNotify', 'notify', () => requestNotifications(store),
      notificationsAllowed)) {
    await writeGrantedFlags(store);
    return false;
  }
  await _pause();
  if (!await step(
    'askingBackground',
    'background',
    () async {
      final bgCtx = context;
      await requestBackground(
          store, context: bgCtx != null && bgCtx.mounted ? bgCtx : null);
    },
    backgroundAllowed,
  )) {
    await writeGrantedFlags(store);
    return false;
  }
  await _pause();
  if (_android) {
    onStep?.call('askingAutoLaunch');
    try {
      final autoCtx = context;
      await requestAutoLaunch(
          store, context: autoCtx != null && autoCtx.mounted ? autoCtx : null);
    } catch (e) {
      debugPrint('all/auto: $e');
    }
  } else if (!await step(
    'askingAutoLaunch',
    'auto',
    () async {
      final autoCtx = context;
      await requestAutoLaunch(
          store, context: autoCtx != null && autoCtx.mounted ? autoCtx : null);
    },
    autoLaunchAllowed,
  )) {
    await writeGrantedFlags(store);
    return false;
  }
  await _pause();
  if (!await step('askingLocation', 'location', () => requestLocationPerm(store),
      locationAllowed)) {
    await writeGrantedFlags(store);
    return false;
  }
  await writeGrantedFlags(store);
  return true;
}

Future<void> applyStoredPermissions(AppStore store) async {
  await keepOnlyGranted(store);
  bindReminderSync(store);
  bindHomeWidget(store);
  warmNotifyLists();
  if (store.notifyOn) {
    await initReminderEngine();
    Future<void>.delayed(
        const Duration(milliseconds: 120), () => syncReminders(store));
  }
  // On every launch: if background (or auto-launch) is on, keep the login
  // bg helper registered and make sure a headless instance can run.
  if (_desktop && (store.backgroundOn || store.autoLaunchOn)) {
    try {
      await autostart.enableDesktopAutostart();
      await autostart.ensureDesktopBackgroundRunning();
    } catch (_) {}
  }
}

String permSnack(Lang lang, String kind, bool ok) {
  if (ok) {
    switch (kind) {
      case 'notify':
        return t(lang, 'notifyGranted');
      case 'background':
        return t(lang, 'bgGranted');
      case 'auto':
        return t(lang, 'autoGranted');
      default:
        return t(lang, 'permGranted');
    }
  }
  switch (kind) {
    case 'notify':
      return t(lang, 'notifyDenied');
    case 'background':
      return t(lang, 'bgDenied');
    case 'auto':
      return t(lang, 'autoDenied');
    default:
      return t(lang, 'permDenied');
  }
}

void showPermSnack(BuildContext context, Lang lang, String kind, bool ok) {
  if (!context.mounted) return;
  SlideSnackBar.show(context,
      message: permSnack(lang, kind, ok), behavior: SnackBarBehavior.floating);
}
