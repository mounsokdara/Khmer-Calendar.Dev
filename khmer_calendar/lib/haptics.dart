import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptics_platform.dart';

enum HapticsMode { system, on, off }

/// Vibration only exists on phones and the web app, never on desktop.
bool get hapticsSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class Haptics {
  Haptics._();
  static final Haptics instance = Haptics._();

  static const _key = 'hapticsMode';
  static const _channel = MethodChannel('khmer.permissions');
  HapticsMode _mode = HapticsMode.system;

  HapticsMode get mode => _mode;

  Future<void> init() async {
    if (!hapticsSupported) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _mode = switch (raw) {
      'on' => HapticsMode.on,
      'off' => HapticsMode.off,
      _ => kIsWeb ? HapticsMode.on : HapticsMode.system,
    };
  }

  Future<void> setMode(HapticsMode mode) async {
    if (kIsWeb && mode == HapticsMode.system) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  Future<void> tick() => _pulse(8, 40);

  /// A heavier pulse, for hitting the end of a gesture (e.g. the last zoom level).
  Future<void> thud() => _pulse(22, 160);

  Future<void> _pulse(int duration, int amplitude) async {
    if (!hapticsSupported || _mode == HapticsMode.off) return;

    if (kIsWeb) {
      await platformHapticTick();
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    if (_mode == HapticsMode.system &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        final enabled =
            await _channel.invokeMethod<bool>('isHapticFeedbackEnabled') ?? false;
        if (!enabled) return;
      } catch (_) {
        return;
      }
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<bool>('vibrate', {'duration': duration, 'amplitude': amplitude});
      } else if (duration > 15) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }
}
