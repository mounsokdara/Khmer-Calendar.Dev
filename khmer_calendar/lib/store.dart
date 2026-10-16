import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_sound.dart';
import 'dates.dart';
import 'i18n.dart';
import 'sounds.dart';
import 'theme.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    this.notes,
    required this.date,
    this.endDate,
    this.startTime,
    this.endTime,
    this.allDay,
    this.reminderDate,
    this.reminderTime,
    this.done,
  });

  String id;
  String title;
  String? notes;
  String date;
  String? endDate;
  String? startTime;
  String? endTime;
  bool? allDay;
  String? reminderDate;
  String? reminderTime;
  bool? done;

  CalendarEvent copy() => CalendarEvent(
        id: id,
        title: title,
        notes: notes,
        date: date,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        allDay: allDay,
        reminderDate: reminderDate,
        reminderTime: reminderTime,
        done: done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'date': date,
        'endDate': endDate,
        'startTime': startTime,
        'endTime': endTime,
        'allDay': allDay,
        'reminderDate': reminderDate,
        'reminderTime': reminderTime,
        'done': done,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String?,
        date: j['date'] as String? ?? '',
        endDate: j['endDate'] as String?,
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
        allDay: j['allDay'] as bool?,
        reminderDate: j['reminderDate'] as String?,
        reminderTime: j['reminderTime'] as String?,
        done: j['done'] as bool?,
      );
}

enum TabId { today, calendar, events, weather, more }

/// Calendar zoom levels, from most zoomed-out to most zoomed-in.
const calViewIds = ['years', 'month', 'monthFull', 'week'];

class RouterTick extends ChangeNotifier {
  void bump() => notifyListeners();
}

const _legacyDefaultCities = ['phnom-penh', 'banteay-meanchey', 'kampong-cham', 'kratie'];

class AppStore extends ChangeNotifier {
  List<CalendarEvent> events = [];
  String cursor = todayIso();
  String selected = todayIso();
  String theme = 'system';
  ColorSchemeId colorScheme = ColorSchemeId.slate;
  bool materialYou = true;
  bool dynamicColor = false;
  bool extraDark = false;
  String accentColor = '#F5C400';
  String highlightColor = '#FF3B30';
  double highlightAlpha = 0.22;
  String langPref = 'auto';
  Lang lang = deviceLang();
  bool setupDone = false;
  TabId lastTab = TabId.calendar;
  String lastEventsPane = 'holidays';
  String calView = 'month';
  List<String> weatherCities = [];
  bool installed = false;
  bool notifyOn = false;
  bool backgroundOn = false;
  bool locationOn = false;
  bool autoLaunchOn = false;
  bool notifyTasks = true;
  bool notifyTomorrow = true;
  bool textStroke = true;
  bool tomorrowTasks = true;
  bool tomorrowHolidays = true;
  bool tomorrowLunar = true;
  bool notifyDaily = false;
  bool notifySil = true;
  bool notifyPublic = true;
  bool notifyOthers = true;
  int weekStartsOn = 1;
  String wheelSound = defaultWheelSoundId;
  String? wheelSoundName;
  bool hydrated = false;
  String? pendingRoute;
  Timer? _persistDebounce;
  final routerTick = RouterTick();

  Brightness get brightness {
    if (theme == 'light') return Brightness.light;
    if (theme == 'dark') return Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  Future<void> hydrate() async {
    final started = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('khmer-calendar-v4') ?? prefs.getString('khmer-calendar-v3');
      if (raw != null) {
        final p = jsonDecode(raw) as Map<String, dynamic>;
        events = ((p['events'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        theme = p['theme'] as String? ?? theme;
        final scheme = p['colorScheme'] as String?;
        if (scheme != null) {
          colorScheme = ColorSchemeId.values.firstWhere(
            (s) => s.name == scheme,
            orElse: () => ColorSchemeId.slate,
          );
        }
        materialYou = p['materialYou'] as bool? ?? true;
        dynamicColor = p['dynamicColor'] as bool? ?? false;
        extraDark = p['extraDark'] as bool? ?? false;
        accentColor = p['accentColor'] as String? ?? accentColor;
        highlightColor = p['highlightColor'] as String? ?? highlightColor;
        highlightAlpha = (p['highlightAlpha'] as num?)?.toDouble() ?? highlightAlpha;
        langPref = p['langPref'] as String? ?? 'auto';
        setupDone = p['setupDone'] as bool? ?? false;
        final tab = p['lastTab'] as String?;
        if (tab != null) {
          lastTab = TabId.values.firstWhere((t) => t.name == tab, orElse: () => TabId.calendar);
        }
        lastEventsPane = p['lastEventsPane'] as String? ?? 'holidays';
        final view = p['calView'] as String?;
        calView = calViewIds.contains(view) ? view! : 'month';
        weatherCities = ((p['weatherCities'] as List?) ?? []).cast<String>();
        if (listEquals(weatherCities, _legacyDefaultCities)) weatherCities = [];
        installed = p['installed'] as bool? ?? false;
        notifyOn = p['notifyOn'] as bool? ?? false;
        backgroundOn = p['backgroundOn'] as bool? ?? false;
        locationOn = p['locationOn'] as bool? ?? false;
        autoLaunchOn = p['autoLaunchOn'] as bool? ?? false;
        notifyTasks = p['notifyTasks'] as bool? ?? true;
        notifyTomorrow = p['notifyTomorrow'] as bool? ?? true;
        textStroke = p['textStroke'] as bool? ?? true;
        tomorrowTasks = p['tomorrowTasks'] as bool? ?? true;
        tomorrowHolidays = p['tomorrowHolidays'] as bool? ?? true;
        tomorrowLunar = p['tomorrowLunar'] as bool? ?? true;
        notifyDaily = p['notifyDaily'] as bool? ?? false;
        notifySil = p['notifySil'] as bool? ?? true;
        final oldHolidays = p['notifyHolidays'] as bool? ?? true;
        notifyPublic = p['notifyPublic'] as bool? ?? oldHolidays;
        notifyOthers = p['notifyOthers'] as bool? ?? p['notifyReligious'] as bool? ?? oldHolidays;
        weekStartsOn = p['weekStartsOn'] as int? ?? 1;
        final ws = p['wheelSound'] as String?;
        if (ws != null) {
          final config = await WheelConfig.load();
          wheelSound = config.sound(ws) != null ? ws : defaultWheelSoundId;
        } else {
          wheelSound = defaultWheelSoundId;
        }
        wheelSoundName = p['wheelSoundName'] as String?;
      }
    } catch (_) {

    }
    AppSounds.instance.setWheel(wheelSound);
    lang = resolveLang(langPref);
    IntlHelper.localeName = lang == Lang.km ? 'km' : 'en';
    final wait = 720 - DateTime.now().difference(started).inMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    hydrated = true;
    notifyListeners();
    routerTick.bump();
  }

  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
      'khmer-calendar-v4',
      jsonEncode({
        'events': events.map((e) => e.toJson()).toList(),
        'theme': theme,
        'colorScheme': colorScheme.name,
        'materialYou': materialYou,
        'dynamicColor': dynamicColor,
        'extraDark': extraDark,
        'accentColor': accentColor,
        'highlightColor': highlightColor,
        'highlightAlpha': highlightAlpha,
        'langPref': langPref,
        'setupDone': setupDone,
        'lastTab': lastTab.name,
        'lastEventsPane': lastEventsPane,
        'calView': calView,
        'weatherCities': weatherCities,
        'installed': installed,
        'notifyOn': notifyOn,
        'backgroundOn': backgroundOn,
        'locationOn': locationOn,
        'autoLaunchOn': autoLaunchOn,
        'notifyTasks': notifyTasks,
        'notifyTomorrow': notifyTomorrow,
        'textStroke': textStroke,
        'tomorrowTasks': tomorrowTasks,
        'tomorrowHolidays': tomorrowHolidays,
        'tomorrowLunar': tomorrowLunar,
        'notifyDaily': notifyDaily,
        'notifySil': notifySil,
        'notifyPublic': notifyPublic,
        'notifyOthers': notifyOthers,
        'weekStartsOn': weekStartsOn,
        'wheelSound': wheelSound,
        'wheelSoundName': wheelSoundName,
      }),
      );
    } catch (_) {}
  }

  void _touch({bool save = true}) {
    notifyListeners();
    if (!save) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 180), persist);
  }

  void addEvent(CalendarEvent e) {
    events = [...events, e];
    _touch();
  }

  void updateEvent(CalendarEvent e) {
    events = events.map((x) => x.id == e.id ? e : x).toList();
    _touch();
  }

  void deleteEvent(String id) {
    events = events.where((x) => x.id != id).toList();
    _touch();
  }

  void toggleEventDone(String id) {
    events = events.map((x) {
      if (x.id != id) return x;
      final c = x.copy();
      c.done = !(x.done ?? false);
      return c;
    }).toList();
    _touch();
  }

  void setCursor(String iso) {
    cursor = iso;
    _touch(save: false);
  }

  void goToDate(String iso) {
    cursor = iso;
    selected = iso;
    _touch(save: false);
  }

  String? takePendingRoute() {
    final route = pendingRoute;
    pendingRoute = null;
    return route;
  }

  void applyLaunch({String? tab, String? date}) {
    final iso = (date ?? '').trim();
    if (iso.isNotEmpty) goToDate(iso);
    final key = (tab ?? '').trim();
    String? route;
    switch (key) {
      case 'today':
      case 'day':
        lastTab = TabId.today;
        route = '/day';
      case 'calendar':
        lastTab = TabId.calendar;
        route = '/calendar';
      case 'events':
        lastTab = TabId.events;
        route = '/events';
      case 'weather':
        lastTab = TabId.weather;
        route = '/weather';
      case 'more':
        lastTab = TabId.more;
        route = '/more';
      default:
        if (iso.isNotEmpty) {
          lastTab = TabId.today;
          route = '/day';
        }
    }
    if (route != null) pendingRoute = route;
    _touch();
    routerTick.bump();
  }

  void setTheme(String v) {
    theme = v;
    _touch();
  }

  void setColorScheme(ColorSchemeId id) {
    colorScheme = id;
    materialYou = true;
    _touch();
  }

  void setMaterialYou(bool v) {
    materialYou = v;
    _touch();
  }

  void setDynamicColor(bool v) {
    dynamicColor = v;
    _touch();
  }

  void setExtraDark(bool v) {
    extraDark = v;
    _touch();
  }

  void setAccentColor(String v) {
    accentColor = v;
    _touch();
  }

  void setHighlightColor(String v) {
    highlightColor = v;
    _touch();
  }

  void setHighlightAlpha(double v) {
    highlightAlpha = v.clamp(0, 1);
    _touch();
  }

  void setLang(String pref) {
    langPref = pref;
    lang = resolveLang(pref);
    IntlHelper.localeName = lang == Lang.km ? 'km' : 'en';
    _touch();
  }

  void setSetupDone(bool v) {
    if (setupDone == v) return;
    setupDone = v;
    _touch();
    routerTick.bump();
  }

  void setLastTab(TabId v) {
    lastTab = v;
    _touch();
  }

  void setLastEventsPane(String v) {
    lastEventsPane = v;
    _touch();
  }

  void setCalView(String v) {
    if (!calViewIds.contains(v) || calView == v) return;
    calView = v;
    _touch();
  }

  bool addWeatherCity(String id) {
    if (weatherCities.contains(id)) return false;
    weatherCities = [...weatherCities, id];
    _touch();
    return true;
  }

  void removeWeatherCity(String id) {
    weatherCities = weatherCities.where((c) => c != id).toList();
    _touch();
  }

  void setNotifyOn(bool v) {
    if (notifyOn == v) return;
    notifyOn = v;
    _touch();
  }

  void setBackgroundOn(bool v) {
    if (backgroundOn == v) return;
    backgroundOn = v;
    _touch();
  }

  void setLocationOn(bool v) {
    if (locationOn == v) return;
    locationOn = v;
    _touch();
  }

  void setAutoLaunchOn(bool v) {
    if (autoLaunchOn == v) return;
    autoLaunchOn = v;
    _touch();
  }

  void setNotifyPublic(bool v) {
    if (notifyPublic == v) return;
    notifyPublic = v;
    _touch();
  }

  void setNotifyOthers(bool v) {
    if (notifyOthers == v) return;
    notifyOthers = v;
    _touch();
  }

  void setTextStroke(bool v) {
    if (textStroke == v) return;
    textStroke = v;
    _touch();
  }

  void setTomorrowTasks(bool v) {
    if (tomorrowTasks == v) return;
    tomorrowTasks = v;
    _touch();
  }

  void setTomorrowHolidays(bool v) {
    if (tomorrowHolidays == v) return;
    tomorrowHolidays = v;
    _touch();
  }

  void setTomorrowLunar(bool v) {
    if (tomorrowLunar == v) return;
    tomorrowLunar = v;
    _touch();
  }

  void setNotifyTomorrow(bool v) {
    if (notifyTomorrow == v) return;
    notifyTomorrow = v;
    _touch();
  }

  void setNotifyTasks(bool v) {
    if (notifyTasks == v) return;
    notifyTasks = v;
    _touch();
  }

  void setNotifyDaily(bool v) {
    if (notifyDaily == v) return;
    notifyDaily = v;
    _touch();
  }

  void setNotifySil(bool v) {
    if (notifySil == v) return;
    notifySil = v;
    _touch();
  }

  void setWeekStartsOn(int v) {
    weekStartsOn = v;
    _touch();
  }



  void setWheelSound(String id, {String? customName}) {
    final normalized = id.trim();
    wheelSound = normalized.isEmpty ? wheelSoundNone : normalized;
    if (customName != null) wheelSoundName = customName;
    AppSounds.instance.setWheel(wheelSound);
    _touch();
  }

  void setInstalled(bool v) {
    installed = v;
    _touch();
  }

  void clearEventReminders() {
    events = events.map((e) {
      final c = e.copy();
      c.reminderDate = '';
      c.reminderTime = '';
      return c;
    }).toList();
    _touch();
  }

  void resetWeatherCities() {
    weatherCities = [];
    _touch();
  }

  void resetAppData() {
    events = [];
    theme = 'system';
    colorScheme = ColorSchemeId.slate;
    materialYou = true;
    dynamicColor = false;
    extraDark = false;
    accentColor = '#F5C400';
    highlightColor = '#FF3B30';
    highlightAlpha = 0.22;
    lastEventsPane = 'holidays';
    calView = 'month';
    weatherCities = [];
    installed = false;
    notifyOn = false;
    backgroundOn = false;
    locationOn = false;
    autoLaunchOn = false;
    notifyTasks = true;
    notifyTomorrow = true;
    textStroke = true;
    tomorrowTasks = true;
    tomorrowHolidays = true;
    tomorrowLunar = true;
    notifyDaily = false;
    notifySil = true;
    notifyPublic = true;
    notifyOthers = true;
    weekStartsOn = 1;
    wheelSound = defaultWheelSoundId;
    wheelSoundName = null;
    AppSounds.instance.setWheel(defaultWheelSoundId);
    unawaited(clearCustomSound());
    _touch();
  }
}
