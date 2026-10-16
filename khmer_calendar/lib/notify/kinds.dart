import 'package:flutter/foundation.dart';

import '../calendar/chhankitek.dart';
import '../calendar/observances.dart';
import '../dates.dart';
import '../i18n.dart';
import '../store.dart';

class ReminderShot {
  const ReminderShot(this.key, this.title, this.body, this.when, {this.channel = 'tasks', this.bodyOf});
  final String key;
  final String title;
  final String body;
  final DateTime when;
  final String channel;
  final String Function()? bodyOf;

  String resolveBody() => bodyOf == null ? body : bodyOf!();
}

abstract class ReminderKind {
  const ReminderKind();
  bool enabled(AppStore store);
  bool get nativeAndroid => false;
  List<ReminderShot> collect(AppStore store, DateTime now);
}

const reminderKinds = <ReminderKind>[
  DailyReminder(),
  SilReminder(),
  PublicHolidayReminder(),
  OtherHolidayReminder(),
  TaskReminder(),
  TomorrowReminder(),
];

String silPhaseLabel(LunarDay info, Lang lang) {
  if (lang == Lang.en) {
    final wax = info.moonStatus == 'កើត' ? 'waxing' : 'waning';
    return '${info.moonDay} $wax';
  }
  return '${info.moonDayKhmer}${info.moonStatus}';
}

String calendarDetail(DateTime day, Lang lang) {
  final info = lunarOf(day);
  final lunar = lang == Lang.en ? lunarLabel(isoOf(day), lang) : info.lunarDateText;
  final greg = lang == Lang.en ? gregorianLabel(day, lang) : info.gregorianDateText;
  return '$lunar\n$greg';
}

String dayNotifyBody(DateTime day, AppStore store) {
  final lang = store.lang;
  final iso = isoOf(day);
  final info = lunarOf(day);
  final lines = <String>[calendarDetail(day, lang)];
  if (info.isSilDay && store.notifySil) {
    lines.add('${t(lang, 'silDay')} (${silPhaseLabel(info, lang)})');
  }
  for (final h in holidayObservancesOn(iso)) {
    lines.add('${holidayTypeLabel(h.holidayType ?? HolidayType.traditional, lang)}: ${obsTitle(h, lang)}');
  }
  final tasks = store.events.where((e) => e.date == iso && e.done != true).toList();
  if (tasks.isNotEmpty) {
    lines.add('${t(lang, 'tasks')}: ${tasks.map((e) => e.title).join(', ')}');
  }
  return lines.join('\n');
}

class DailyReminder extends ReminderKind {
  const DailyReminder();

  @override
  bool enabled(AppStore store) => store.notifyDaily;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) {
    var when = DateTime(now.year, now.month, now.day, 7);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    final lang = store.lang;
    return [
      ReminderShot(
        'daily-${isoOf(when)}',
        t(lang, 'notifyTodayTitle'),
        dayNotifyBody(when, store),
        when,
        channel: 'daily',
      ),
    ];
  }
}

class SilReminder extends ReminderKind {
  const SilReminder();

  @override
  bool enabled(AppStore store) => store.notifySil;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) {
    final lang = store.lang;
    final out = <ReminderShot>[];
    for (final iso in upcomingSilDates()) {
      final d = fromIso(iso);
      final when = DateTime(d.year, d.month, d.day, 7);
      if (!when.isAfter(now)) continue;
      out.add(
        ReminderShot(
          'sil-$iso',
          t(lang, 'silDay'),
          '',
          when,
          channel: 'sil',
          bodyOf: () {
            final info = lunarOf(d);
            final phase = silPhaseLabel(info, lang);
            return '${t(lang, 'silDay')} ($phase)\n${calendarDetail(d, lang)}';
          },
        ),
      );
    }
    return out;
  }
}

List<ReminderShot> _holidayShotsFrom(
  AppStore store,
  DateTime now,
  List<Map<String, String>> items,
  String channel,
) {
  final lang = store.lang;
  final out = <ReminderShot>[];
  for (final h in items) {
    final day = fromIso(h['d']!);
    final when = DateTime(day.year, day.month, day.day, 8);
    if (!when.isAfter(now)) continue;
    final name = lang == Lang.en ? h['en']! : h['km']!;
    final type = switch (h['type']) {
      'public' => HolidayType.public,
      'international' => HolidayType.international,
      'traditional' => HolidayType.traditional,
      _ => HolidayType.religious,
    };
    out.add(
      ReminderShot(
        'hol-${h['type']}-${h['d']}-${h['km']}',
        name,
        '',
        when,
        channel: channel,
        bodyOf: () => '${holidayTypeLabel(type, lang)}\n${calendarDetail(day, lang)}',
      ),
    );
  }
  return out;
}

class PublicHolidayReminder extends ReminderKind {
  const PublicHolidayReminder();

  @override
  bool enabled(AppStore store) => store.notifyPublic;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) =>
      _holidayShotsFrom(store, now, upcomingHolidays(HolidayType.public), 'public');
}

class OtherHolidayReminder extends ReminderKind {
  const OtherHolidayReminder();

  @override
  bool enabled(AppStore store) => store.notifyOthers;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) =>
      _holidayShotsFrom(store, now, upcomingOtherHolidays(), 'others');
}

class TaskReminder extends ReminderKind {
  const TaskReminder();

  @override
  bool enabled(AppStore store) => store.notifyTasks;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) {
    final lang = store.lang;
    final out = <ReminderShot>[];
    for (final e in store.events) {
      if (e.done == true) continue;
      final reminder = (e.reminderDate ?? '').trim();
      if (reminder.isNotEmpty) {
        final shot = _taskShot(store, lang, e, fromIso(reminder), e.reminderTime, now);
        if (shot != null) out.add(shot);
        continue;
      }
      if (e.date.isEmpty) continue;
      final start = fromIso(e.date);
      var end = fromIso(e.endDate ?? e.date);
      if (end.isBefore(start)) end = start;
      for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
        final shot = _taskShot(store, lang, e, d, e.allDay == true ? null : e.startTime, now);
        if (shot != null) out.add(shot);
      }
    }
    return out;
  }
}

class TomorrowReminder extends ReminderKind {
  const TomorrowReminder();

  static const _hour = 20;
  static const _days = 45;

  @override
  bool enabled(AppStore store) => store.notifyTomorrow;

  @override
  bool get nativeAndroid => true;

  @override
  List<ReminderShot> collect(AppStore store, DateTime now) {
    final lang = store.lang;
    final out = <ReminderShot>[];
    final first = DateTime(now.year, now.month, now.day);
    for (var i = 0; i <= _days; i++) {
      final target = addDays(first, i + 1);
      final when = DateTime(target.year, target.month, target.day - 1, _hour);
      if (!when.isAfter(now)) continue;
      final iso = isoOf(target);
      final lines = _tomorrowLines(store, target, iso, lang);
      if (lines.isEmpty) continue;
      out.add(
        ReminderShot(
          'tomorrow-$iso',
          t(lang, 'notifyTomorrowTitle'),
          '',
          when,
          channel: 'tasks',
          bodyOf: () => [if (store.tomorrowLunar) calendarDetail(target, lang), ..._tomorrowLines(store, target, iso, lang)].join('\n'),
        ),
      );
    }
    return out;
  }
}

List<String> _tomorrowLines(AppStore store, DateTime day, String iso, Lang lang) {
  final lines = <String>[];
  if (store.tomorrowHolidays) {
    for (final h in holidayObservancesOn(iso)) {
      lines.add('${holidayTypeLabel(h.holidayType ?? HolidayType.traditional, lang)}: ${obsTitle(h, lang)}');
    }
  }
  if (!store.tomorrowTasks) return lines;
  for (final e in store.events) {
    if (e.done == true || e.date.isEmpty) continue;
    final start = fromIso(e.date);
    var end = fromIso(e.endDate ?? e.date);
    if (end.isBefore(start)) end = start;
    if (day.isBefore(start) || day.isAfter(end)) continue;
    final clock = e.allDay == true ? '' : (e.startTime ?? '');
    lines.add(clock.isEmpty ? e.title : '$clock ${e.title}');
  }
  return lines;
}

ReminderShot? _taskShot(
  AppStore store,
  Lang lang,
  CalendarEvent e,
  DateTime day,
  String? clock,
  DateTime now,
) {
  var hour = 8;
  var minute = 0;
  final tm = clock ?? '';
  if (tm.contains(':')) {
    final p = tm.split(':');
    hour = int.tryParse(p[0]) ?? 8;
    minute = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
  }
  final when = DateTime(day.year, day.month, day.day, hour, minute);
  if (!when.isAfter(now)) return null;
  final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  final notes = (e.notes ?? '').trim();
  return ReminderShot(
    'task-${e.id}-${isoOf(day)}-$time',
    e.title,
    notes,
    when,
    channel: 'tasks',
    bodyOf: () {
      final lines = <String>[t(lang, 'notifyTaskKind'), calendarDetail(day, lang), time];
      if (notes.isNotEmpty) lines.add(notes);
      return lines.join('\n');
    },
  );
}

bool get androidNativeAlarms => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

int notifyEndYear([DateTime? now]) {
  final n = now ?? DateTime.now();
  return n.year + 1;
}

String _horizonKey() => '${isoOf(DateTime.now())}|${notifyEndYear()}';

String? _silKey;
List<String>? _silCache;
String? _otherKey;
List<Map<String, String>>? _otherCache;
final _typeCache = <String, List<Map<String, String>>>{};

String _silKeyOf(DateTime now, int endYear) => '${isoOf(DateTime(now.year, now.month, now.day))}|$endYear';

/// Runs in a background isolate: the first (cold) computation walks ~2 years of lunar days and
/// holiday tables, which freezes the UI if done on the main isolate.
Map<String, Object> _notifyListsIsolate(int _) => {
      'sil': upcomingSilDates(),
      'pub': upcomingHolidays(HolidayType.public),
      'others': upcomingOtherHolidays(),
    };

/// Fills the caches used by [upcomingSilDates], [upcomingHolidays] and [upcomingOtherHolidays]
/// with lists that were computed in another isolate.
void seedNotifyListsFrom(Map<dynamic, dynamic> raw) {
  final now = DateTime.now();
  final sil = raw['sil'];
  if (sil is List) {
    _silKey = _silKeyOf(now, notifyEndYear(now));
    _silCache = sil.cast<String>().toList();
  }
  List<Map<String, String>> holidays(Object? v) =>
      (v as List).map((e) => Map<String, String>.from(e as Map)).toList();
  final pub = raw['pub'];
  if (pub is List) _typeCache['${_horizonKey()}|${HolidayType.public.name}'] = holidays(pub);
  final others = raw['others'];
  if (others is List) {
    _otherKey = _horizonKey();
    _otherCache = holidays(others);
  }
}

bool _notifyListsWarm() {
  final now = DateTime.now();
  return _silCache != null &&
      _silKey == _silKeyOf(now, notifyEndYear(now)) &&
      _otherCache != null &&
      _otherKey == _horizonKey() &&
      _typeCache.containsKey('${_horizonKey()}|${HolidayType.public.name}');
}

Future<void>? _notifyListsFuture;

Future<void> _loadNotifyLists() async {
  try {
    final raw = await compute<int, Map<String, Object>>(_notifyListsIsolate, 0);
    seedNotifyListsFrom(raw);
  } catch (_) {}
}

/// Makes sure the upcoming-holiday caches are warm without blocking the UI thread.
Future<void> ensureNotifyLists() {
  if (_notifyListsWarm()) return Future<void>.value();
  return _notifyListsFuture ??= _loadNotifyLists().whenComplete(() => _notifyListsFuture = null);
}

void warmNotifyLists() {
  // On Android the widget sync computes and seeds these lists in the background already.
  if (androidNativeAlarms) return;
  Future<void>.delayed(const Duration(milliseconds: 300), () {
    ensureNotifyLists();
  });
}

List<String> upcomingSilDates({int? throughYear}) {
  final now = DateTime.now();
  final endYear = throughYear ?? notifyEndYear(now);
  final key = _silKeyOf(now, endYear);
  if (_silCache != null && _silKey == key) return _silCache!;
  final last = DateTime(endYear, 12, 31);
  final out = <String>[];
  var d = DateTime(now.year, now.month, now.day);
  while (!d.isAfter(last)) {
    if (lunarOf(d).isSilDay) out.add(isoOf(d));
    d = addDays(d, 1);
  }
  _silKey = key;
  _silCache = out;
  return out;
}

List<Map<String, String>> upcomingHolidays(HolidayType type) {
  final key = '${_horizonKey()}|${type.name}';
  final hit = _typeCache[key];
  if (hit != null) return hit;
  final out = _upcomingHolidayMaps((t) => t == type);
  _typeCache[key] = out;
  return out;
}

List<Map<String, String>> upcomingOtherHolidays() {
  final key = _horizonKey();
  if (_otherCache != null && _otherKey == key) return _otherCache!;
  final out = _upcomingHolidayMaps((type) => type != HolidayType.public);
  out.sort((a, b) => a['d']!.compareTo(b['d']!));
  _otherKey = key;
  _otherCache = out;
  return out;
}

List<Map<String, String>> _upcomingHolidayMaps(bool Function(HolidayType type) keep) {
  final now = DateTime.now();
  final today = isoOf(DateTime(now.year, now.month, now.day));
  final out = <Map<String, String>>[];
  final seen = <String>{};
  for (var y = now.year; y <= notifyEndYear(now); y++) {
    List<Observance> list;
    try {
      list = holidayObservancesOfYear(y);
    } catch (_) {
      continue;
    }
    for (final h in list) {
      final type = h.holidayType;
      if (type == null || !keep(type)) continue;
      if (h.date.compareTo(today) < 0) continue;
      final key = '${h.date}-${h.title}';
      if (!seen.add(key)) continue;
      out.add({'d': h.date, 'km': h.title, 'en': h.titleEn, 'type': type.name});
    }
  }
  return out;
}

List<Map<String, dynamic>> notifyItemsOf(AppStore store) {
  if (!store.notifyOn) return [];
  final now = DateTime.now();
  final out = <Map<String, dynamic>>[];
  for (final kind in reminderKinds) {
    if (kind is DailyReminder) continue;
    if (!kind.enabled(store)) continue;
    for (final shot in kind.collect(store, now)) {
      final row = <String, dynamic>{
        'd': isoOf(DateTime(shot.when.year, shot.when.month, shot.when.day)),
        'h': shot.when.hour,
        'm': shot.when.minute,
        'ch': shot.channel,
        'title': shot.title,
      };
      if (shot.body.isNotEmpty) row['notes'] = shot.body;
      out.add(row);
    }
  }
  return out;
}

