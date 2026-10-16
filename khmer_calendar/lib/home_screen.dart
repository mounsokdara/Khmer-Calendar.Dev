import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, ColorScheme;
import 'package:flutter/services.dart';

import 'calendar/chhankitek.dart';
import 'calendar/observances.dart';
import 'dates.dart';
import 'i18n.dart';
import 'net.dart';
import 'notify/kinds.dart';
import 'store.dart';
import 'theme.dart';
import 'weather.dart';
import 'wx_cache.dart';

const _ch = MethodChannel('khmer.permissions');
var _bound = false;
Timer? _widgetDebounce;
String _displaySig = '';
String _notifySig = '';
Map<String, dynamic>? _displayPayload;

bool get canPinHomeWidget {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

String _widgetDisplaySig(AppStore store) =>
    '${store.lang}|${store.weekStartsOn}|${store.events.map((e) => '${e.id}:${e.date}:${e.endDate}:${e.title}').join(',')}|${todayIso()}';

String _widgetNotifySig(AppStore store) =>
    '${store.notifyOn}|${store.notifyDaily}|${store.notifySil}|${store.notifyPublic}|${store.notifyOthers}|${store.notifyTasks}|${store.events.map((e) => '${e.id}:${e.date}:${e.endDate}:${e.startTime}:${e.reminderDate}:${e.reminderTime}:${e.done}:${e.title}').join(',')}';

void bindHomeWidget(AppStore store) {
  if (_bound) return;
  _bound = true;
  store.addListener(() {
    final sig = '${_widgetDisplaySig(store)}|${_widgetNotifySig(store)}';
    if (sig == '$_displaySig|$_notifySig') return;
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 450), () {
      syncHomeWidget(store);
    });
  });
  syncHomeWidget(store);
  syncWeatherWidget(store);
  _ch.setMethodCallHandler((call) async {
    if (call.method == 'open') applyWidgetLaunch(store, call.arguments);
  });
  _ch.invokeMethod<dynamic>('getLaunch').then((raw) => applyWidgetLaunch(store, raw)).catchError((_) {});
}

void applyWidgetLaunch(AppStore store, Object? raw) {
  if (raw is! Map) return;
  final tab = raw['tab']?.toString() ?? '';
  final date = raw['date']?.toString() ?? '';
  if (tab.isEmpty && date.isEmpty) return;
  store.applyLaunch(tab: tab, date: date);
}

String _themeSig = '';

/// Sends the app's Material 3 colours (both light and dark) plus the app's theme mode to the
/// widgets, so they follow the app's colour scheme and light/dark setting.
void syncWidgetTheme(AppStore store, ColorScheme light, ColorScheme dark) {
  if (!canPinHomeWidget) return;
  String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';
  String palette(ColorScheme cs, bool isDark) => jsonEncode({
        'surface': hex(cs.surfaceContainer),
        'onSurface': hex(cs.onSurface),
        'onVariant': hex(cs.onSurfaceVariant),
        'primary': hex(cs.primary),
        'onPrimary': hex(cs.onPrimary),
        'container': hex(cs.primaryContainer),
        'onContainer': hex(cs.onPrimaryContainer),
        'public': hex(publicHolidayFill),
        'holiday': hex(isDark ? religiousColorOnDark : religiousColor),
      });
  final mode = store.theme == 'light' ? 'light' : (store.theme == 'dark' ? 'dark' : 'system');
  final lightJson = palette(light, false);
  final darkJson = palette(dark, true);
  final sig = '$mode|$lightJson|$darkJson';
  if (sig == _themeSig) return;
  _themeSig = sig;
  _ch.invokeMethod<void>('updateWidget', {'wp_light': lightJson, 'wp_dark': darkJson, 'wp_mode': mode}).catchError((_) {});
}

bool _syncBusy = false;
bool _syncQueued = false;

/// Pushes calendar data to the Android widgets. Calls made while a sync is running are merged
/// into one follow-up run, so rapid changes never pile up heavy work.
Future<void> syncHomeWidget(AppStore store) async {
  if (!canPinHomeWidget) return;
  if (_syncBusy) {
    _syncQueued = true;
    return;
  }
  _syncBusy = true;
  try {
    do {
      _syncQueued = false;
      await _syncHomeWidgetOnce(store);
    } while (_syncQueued);
  } catch (_) {
  } finally {
    _syncBusy = false;
  }
}

Future<void> _syncHomeWidgetOnce(AppStore store) async {
  final displaySig = _widgetDisplaySig(store);
  final notifySig = _widgetNotifySig(store);
  if (displaySig == _displaySig && notifySig == _notifySig) return;
  if (displaySig != _displaySig || _displayPayload == null) {
    _displayPayload = await _buildWidgetDisplay(store);
    _displaySig = displaySig;
  }
  _notifySig = notifySig;
  try {
    await _ch.invokeMethod<void>('updateWidget', {
      ..._displayPayload!,
      'notifyOn': store.notifyOn,
      'notifyDaily': store.notifyDaily,
      'notifySil': store.notifySil,
      'notifyPublic': store.notifyPublic,
      'notifyOthers': store.notifyOthers,
      'notifyReligious': store.notifyOthers,
      'notifyTasks': store.notifyTasks,
      'notify_items': jsonEncode(notifyItemsOf(store)),
    });
  } catch (_) {}
}

Map<String, String> _dayNotifyFields(DateTime d, Lang lang, List<CalendarEvent> events) {
  final di = isoOf(d);
  final lu = lunarOf(d);
  final hs = observancesOn(di, events).where((e) => e.kind == Kind.holiday);
  return {
    'lunar': lang == Lang.en ? lunarLabel(di, lang) : lu.lunarDateText,
    'holiday': hs.isEmpty ? '' : obsTitle(hs.first, lang),
    'weekday': weekdaysFull(lang)[d.weekday % 7],
    'gregorian': lang == Lang.en ? gregorianLabel(d, lang) : lu.gregorianDateText,
    'be': lang == Lang.en ? 'B.E. ${lu.buddhistEraYear}' : 'ព.ស. ${lu.buddhistEraYearKhmer}',
    'moon': silPhaseLabel(lu, lang),
    'sil': lu.isSilDay ? '1' : '',
    'hkind': hs.isEmpty
        ? ''
        : (hs.first.holidayType == HolidayType.public
            ? 'public'
            : hs.first.holidayType == HolidayType.religious
                ? 'religious'
                : hs.first.holidayType == HolidayType.international
                    ? 'international'
                    : 'traditional'),
  };
}

/// Everything that does not depend on the user's events. It scans 1900-2100 for holiday and silday marks (the widget can page to any year) and
/// holiday tables, so it must run in a background isolate (never on the UI thread).
Map<String, Object> _staticWidgetIsolate(bool en) {
  final lang = en ? Lang.en : Lang.km;
  IntlHelper.localeName = en ? 'en' : 'km';
  final now = DateTime.now();
  final publicHols = upcomingHolidays(HolidayType.public);
  final otherHols = upcomingOtherHolidays();
  final silDays = upcomingSilDates();
  final dayIsos = <String>{};
  for (var i = 0; i < 90; i++) {
    dayIsos.add(isoOf(DateTime(now.year, now.month, now.day + i)));
  }
  for (final h in publicHols) {
    dayIsos.add(h['d']!);
  }
  for (final h in otherHols) {
    dayIsos.add(h['d']!);
  }
  dayIsos.addAll(silDays);
  const noEvents = <CalendarEvent>[];
  final days = <String, Map<String, String>>{};
  for (final di in dayIsos) {
    days[di] = _dayNotifyFields(fromIso(di), lang, noEvents);
  }
  final marks = <String, String>{};
  final names = <String, String>{};
  void flag(String day, String f) {
    final cur = marks[day] ?? '';
    if (!cur.contains(f)) marks[day] = '$cur$f';
  }

  for (var y = 1900; y <= 2100; y++) {
    List<Observance> yearHols;
    try {
      yearHols = holidayObservancesOfYear(y);
    } catch (_) {
      continue;
    }
    for (final h in yearHols) {
      flag(h.date, h.holidayType == HolidayType.public ? 'p' : 'h');
      names.putIfAbsent(h.date, () => obsTitle(h, lang));
    }
    var d = DateTime(y, 1, 1);
    final last = DateTime(y, 12, 31);
    while (!d.isAfter(last)) {
      if (lunarOf(d).isSilDay) flag(isoOf(d), 's');
      d = addDays(d, 1);
    }
  }
  return {
    'marks': marks,
    'names': names,
    'daysJson': jsonEncode(days),
    'silCsv': silDays.join(','),
    'publicJson': jsonEncode(publicHols),
    'otherJson': jsonEncode(otherHols),
    // raw lists, used to warm the notification caches on the main isolate
    'sil': silDays,
    'pub': publicHols,
    'others': otherHols,
  };
}

class _StaticWidget {
  _StaticWidget({
    required this.marks,
    required this.names,
    required this.daysJson,
    required this.silCsv,
    required this.publicJson,
    required this.otherJson,
  });
  final Map<String, String> marks;
  final Map<String, String> names;
  final String daysJson;
  final String silCsv;
  final String publicJson;
  final String otherJson;
}

String _staticKey = '';
_StaticWidget? _static;
Future<_StaticWidget>? _staticFuture;
String _staticFutureKey = '';

Future<_StaticWidget> _computeStatic(bool en, String key) async {
  final raw = await compute<bool, Map<String, Object>>(_staticWidgetIsolate, en);
  seedNotifyListsFrom(raw);
  final data = _StaticWidget(
    marks: Map<String, String>.from(raw['marks']! as Map),
    names: Map<String, String>.from(raw['names']! as Map),
    daysJson: raw['daysJson']! as String,
    silCsv: raw['silCsv']! as String,
    publicJson: raw['publicJson']! as String,
    otherJson: raw['otherJson']! as String,
  );
  _static = data;
  _staticKey = key;
  return data;
}

Future<_StaticWidget> _staticWidgetData(Lang lang) async {
  final key = '${lang == Lang.en}|${todayIso()}';
  final cached = _static;
  if (cached != null && _staticKey == key) return cached;
  var pending = _staticFuture;
  if (pending == null || _staticFutureKey != key) {
    _staticFutureKey = key;
    pending = _computeStatic(lang == Lang.en, key);
    _staticFuture = pending;
  }
  try {
    return await pending;
  } finally {
    if (identical(_staticFuture, pending)) _staticFuture = null;
  }
}

Future<Map<String, dynamic>> _buildWidgetDisplay(AppStore store) async {
  final lang = store.lang;
  final data = await _staticWidgetData(lang);
  final now = DateTime.now();
  final iso = todayIso();
  final events = store.events;
  final lunar = lunarOf(now);
  final lunarText = lang == Lang.en ? lunarLabel(iso, lang) : lunar.lunarDateText;
  final hols = observancesOn(iso, events).where((e) => e.kind == Kind.holiday);
  final holiday = hols.isEmpty
      ? ''
      : obsTitle(hols.firstWhere((h) => h.holidayType == HolidayType.public, orElse: () => hols.first), lang);

  // Cheap per-event overlay on top of the cached static data.
  final marks = Map<String, String>.of(data.marks);
  final names = Map<String, String>.of(data.names);
  for (final e in events) {
    if (e.date.isEmpty) continue;
    final cur = marks[e.date] ?? '';
    if (!cur.contains('t')) marks[e.date] = '${cur}t';
    names.putIfAbsent(e.date, () => e.title);
  }

  return {
    'iso': iso,
    'day': '${now.day}',
    'weekday': weekdaysFull(lang)[now.weekday % 7],
    'lunar': lunarText,
    'holiday': holiday,
    'hkind': hols.any((h) => h.holidayType == HolidayType.public) ? 'public' : (hols.isEmpty ? '' : 'other'),
    'gregorian': lang == Lang.en
        ? '${now.day} ${monthsEn[now.month - 1]} ${now.year} CE'
        : '${lunar.gregorianDayText} ${lunar.gregorianMonthText} គ.ស ${lunar.gregorianYearText}',
    'title': t(lang, 'appName'),
    'days': data.daysJson,
    'marks': jsonEncode(marks),
    'names': jsonEncode(names),
    'lang': lang == Lang.en ? 'en' : 'km',
    'weekStartsOn': store.weekStartsOn,
    'sil_days': data.silCsv,
    'public_hols': data.publicJson,
    'religious_hols': data.otherJson,
  };
}

Future<void> syncWeatherWidget(AppStore store) async {
  if (!canPinHomeWidget) return;
  if (store.weatherCities.isEmpty) return;
  if (NetStatus.isOffline) return;
  final cache = <String, WeatherSnap>{};
  await Future.wait(store.weatherCities.map((id) async {
    final city = cityById(id);
    if (city == null) return;
    try {
      cache[id] = await fetchWeather(city);
    } catch (_) {}
  }));
  await pushWeatherList(store, cache);
}

String encodeHourly(WeatherSnap snap) {
  final now = DateTime.now();
  return snap.hourly
      .where((h) {
        final t = DateTime.tryParse(h.time);
        return t != null && !t.isBefore(now.subtract(const Duration(minutes: 40)));
      })
      .take(6)
      .map((h) {
        final t = DateTime.tryParse(h.time);
        final hh = (t?.hour ?? 0).toString().padLeft(2, '0');
        return '$hh|${h.temp}|${h.code}';
      })
      .join(';');
}

Future<void> pushWeatherList(
  AppStore store,
  Map<String, WeatherSnap> cache, {
  String? selectId,
}) async {
  if (!canPinHomeWidget) return;
  final rows = <Map<String, String>>[];
  var index = 0;
  for (var i = 0; i < store.weatherCities.length; i++) {
    final id = store.weatherCities[i];
    final city = cityById(id);
    if (city == null) continue;
    final snap = cache[id];
    if (selectId != null && id == selectId) index = rows.length;
    final meta = snap == null ? null : wmoOf(snap.code);
    rows.add({
      'id': id,
      'name': city.name,
      'nameEn': city.nameEn,
      'temp': snap == null ? '' : '${snap.temp}',
      'high': snap == null ? '' : '${snap.high}',
      'low': snap == null ? '' : '${snap.low}',
      'label': meta?.km ?? '',
      'labelEn': meta?.en ?? '',
      'code': '${snap?.code ?? 2}',
      'daily': snap == null
          ? ''
          : snap.daily.take(7).map((d) => '${d.date}|${d.high}|${d.low}|${d.code}').join(';'),
      'hourly': snap == null ? '' : encodeHourly(snap),
      'clouds': '${snap?.clouds ?? 0}',
      'icon': '',
      'photo': '',
    });
  }
  if (rows.isEmpty) return;
  Future<void> send() async {
    final first = rows[index.clamp(0, rows.length - 1)];
    await _ch.invokeMethod<void>('updateWidget', {
      'wx_list': jsonEncode(rows),
      'wx_index': index,
      'wx_city': first['name'],
      'wx_city_en': first['nameEn'],
      'wx_temp': first['temp'],
      'wx_high': first['high'],
      'wx_low': first['low'],
      'wx_label': first['label'],
      'wx_label_en': first['labelEn'],
      'lang': store.lang == Lang.en ? 'en' : 'km',
    });
  }

  try {
    await send();
  } catch (_) {}
  // Icons and photos are slow network/disk work; fill them in without making callers wait.
  final gen = ++_wxGen;
  unawaited(_fillWeatherAssets(rows, cache, gen, send));
}

int _wxGen = 0;

Future<void> _fillWeatherAssets(
  List<Map<String, String>> rows,
  Map<String, WeatherSnap> cache,
  int gen,
  Future<void> Function() send,
) async {
  try {
    await Future.wait(rows.map((row) async {
      final id = row['id'] ?? '';
      final city = cityById(id);
      if (city == null) return;
      final snap = cache[id];
      if (snap != null) {
        row['icon'] = await cacheUrl(wmoIconUrl(snap.code), 'wx_icon_$id.png') ?? '';
      }
      // Reuse the photo already on disk instead of searching Wikimedia again on every launch.
      var photo = await cachedPath('wx_photo_$id.jpg');
      if (photo == null) {
        final remote = await cityPhotoUrl(city);
        if (remote != null) photo = await cacheUrl(remote, 'wx_photo_$id.jpg');
      }
      row['photo'] = photo ?? '';
    }));
    if (gen != _wxGen) return;
    await send();
  } catch (_) {}
}

Future<bool> pinHomeWidget([String kind = 'today']) async {
  if (!canPinHomeWidget) return false;
  try {
    return await _ch.invokeMethod<bool>('pinWidget', {'kind': kind}) ?? false;
  } catch (_) {
    return false;
  }
}
