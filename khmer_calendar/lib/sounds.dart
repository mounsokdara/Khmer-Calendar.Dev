import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'custom_sound.dart';
import 'haptics.dart';

const wheelSoundNone = 'none';
const wheelSoundCustom = 'custom';
const defaultWheelSoundId = 'wheel1';

enum CustomPickResult { picked, cancelled, tooLarge, failed }

class WheelConfig {
  WheelConfig._(this.raw);

  final Map<String, dynamic> raw;

  static Future<WheelConfig>? _future;

  static Future<WheelConfig> load() => _future ??= _load();

  static Future<WheelConfig> _load() async {
    try {
      final text = await rootBundle.loadString('assets/config/wheel_picker_audio.json');
      final value = jsonDecode(text);
      if (value is Map) return WheelConfig._(Map<String, dynamic>.from(value));
    } catch (e) {
      debugPrint('wheel config failed: $e');
    }
    return WheelConfig._({});
  }

  Map<String, dynamic> get wheel => raw['wheel'] is Map ? Map<String, dynamic>.from(raw['wheel']) : const {};

  List<Map<String, dynamic>> get soundOptions {
    final sounds = raw['sounds'];
    if (sounds is! List) return const [];
    return [
      for (final item in sounds)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  int get minGapMs => (wheel['min_gap_ms'] as num?)?.toInt() ?? 45;
  int get maxLivePlayers => (wheel['max_live_players'] as num?)?.toInt() ?? 3;
  int get maxLifetimeMs => (wheel['max_lifetime_ms'] as num?)?.toInt() ?? 3000;
  int get customMaxBytes => (wheel['custom_max_bytes'] as num?)?.toInt() ?? 1024 * 1024;
  Map<String, dynamic>? sound(String id) {
    final sounds = raw['sounds'];
    if (sounds is! List) return null;
    for (final item in sounds) {
      if (item is Map && item['id']?.toString() == id) return Map<String, dynamic>.from(item);
    }
    return null;
  }

  String? soundAsset(String id) => sound(id)?['asset']?.toString();
  String soundLabel(String id, {required bool khmer}) =>
      sound(id)?[khmer ? 'km' : 'en']?.toString() ?? id;
}

Future<({CustomPickResult result, String? name})> pickCustomSound() async {
  try {
    final config = await WheelConfig.load();
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return (result: CustomPickResult.cancelled, name: null);
    if (await file.length() > config.customMaxBytes) {
      return (result: CustomPickResult.tooLarge, name: null);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return (result: CustomPickResult.failed, name: null);
    await saveCustomSound(bytes, _extOf(file.name));
    return (result: CustomPickResult.picked, name: file.name);
  } catch (e) {
    debugPrint('pickCustomSound failed: $e');
    return (result: CustomPickResult.failed, name: null);
  }
}

String _extOf(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0 || i == name.length - 1) return 'mp3';
  final e = name.substring(i + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(e) ? e : 'mp3';
}

class AppSounds {
  AppSounds._();
  static final AppSounds instance = AppSounds._();

  String _wheel = wheelSoundNone;
  int _gen = 0;
  Future<Source?>? _custom;
  AudioPlayer? _player;
  bool _ready = false;
  bool _playing = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  WheelConfig? _config;
  String? _loadedId;

  String get wheel => _wheel;

  void setWheel(String id) {
    final normalized = id.trim();
    _wheel = normalized.isEmpty ? wheelSoundNone : normalized;
    _gen++;
    _custom = null;
    _loadedId = null;
    unawaited(_stop());
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    _config ??= await WheelConfig.load();
  }

  /// One short click for the scroll wheel / sound picker. Reuses a single player and
  /// stops the previous play so rapid taps never stack audio sessions.
  void playWheel() {
    Haptics.instance.tick();
    if (_wheel == wheelSoundNone) return;
    unawaited(_play(_wheel, _gen));
  }

  Future<void> _play(String id, int gen) async {
    final config = _config ??= await WheelConfig.load();
    final minGap = Duration(milliseconds: config.minGapMs.clamp(20, 200));
    final now = DateTime.now();
    if (now.difference(_last) < minGap) return;
    if (_playing) {
      // Still finishing a previous play — drop this tick instead of queuing another player.
      return;
    }
    _last = now;
    _playing = true;

    try {
      if (gen != _gen) return;
      final source = await _sourceFor(id, config);
      if (source == null || gen != _gen) return;

      final player = await _ensurePlayer();
      if (gen != _gen) return;

      // Stop + seek + play on the same player — never allocate a new one per tick.
      try {
        await player.stop();
      } catch (_) {}
      if (_loadedId != id) {
        await player.setSource(source);
        _loadedId = id;
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('wheel sound failed: $e');
      _loadedId = null;
    } finally {
      _playing = false;
    }
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null && _ready) return existing;

    final player = existing ?? AudioPlayer();
    _player = player;
    if (!_ready) {
      final ctx = _context();
      if (ctx != null) {
        try {
          await player.setAudioContext(ctx);
        } catch (_) {}
      }
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
      _ready = true;
    }
    return player;
  }

  Future<void> _stop() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<Source?> _sourceFor(String id, WheelConfig config) async {
    final asset = config.soundAsset(id);
    if (asset != null && asset.isNotEmpty) return AssetSource(asset);
    if (id == wheelSoundCustom) return _custom ??= customSoundSource();
    return null;
  }

  AudioContext? _context() {
    if (kIsWeb) return null;
    final p = defaultTargetPlatform;
    if (p != TargetPlatform.android && p != TargetPlatform.iOS) return null;
    return AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: p == TargetPlatform.iOS,
    ).build();
  }
}
