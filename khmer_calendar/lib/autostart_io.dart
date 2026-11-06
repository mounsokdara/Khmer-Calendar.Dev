import 'package:flutter/services.dart';

const _ch = MethodChannel('khmer.autostart');

Future<bool> _call(String method) async {
  try {
    return await _ch.invokeMethod<bool>(method) ?? false;
  } on MissingPluginException {
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> enableDesktopAutostart() => _call('enable');

Future<void> disableDesktopAutostart() async {
  await _call('disable');
}

Future<bool> isDesktopAutostartEnabled() => _call('isEnabled');

/// Start the dedicated background helper (or main --autostart) if needed.
Future<bool> ensureDesktopBackgroundRunning() => _call('ensureRunning');
