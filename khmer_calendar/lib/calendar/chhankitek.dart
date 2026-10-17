

import 'chinese_lunar.dart';

enum HolidayType { public, religious, traditional, international }

class Holiday {
  const Holiday({
    required this.date,
    required this.nameKm,
    required this.nameEn,
    required this.type,
  });

  final String date;
  final String nameKm;
  final String nameEn;
  final HolidayType type;

  Holiday copy() => Holiday(date: date, nameKm: nameKm, nameEn: nameEn, type: type);
}

class LunarDay {
  const LunarDay({
    required this.gregorianDate,
    required this.dayOfWeek,
    required this.buddhistEraYear,
    required this.buddhistEraYearKhmer,
    required this.khmerYear,
    required this.khmerYearKhmer,
    required this.khmerMonth,
    required this.moonStatus,
    required this.moonDay,
    required this.moonDayKhmer,
    required this.animalYear,
    required this.sak,
    required this.isLeapMonth,
    required this.isSilDay,
    required this.lunarDateText,
    required this.gregorianDateText,
    required this.gregorianDayText,
    required this.gregorianMonthText,
    required this.gregorianYearText,
    this.observanceText,
    required this.fullText,
    this.holidays,
  });

  final String gregorianDate;
  final String dayOfWeek;
  final int buddhistEraYear;
  final String buddhistEraYearKhmer;
  final int khmerYear;
  final String khmerYearKhmer;
  final String khmerMonth;
  final String moonStatus;
  final int moonDay;
  final String moonDayKhmer;
  final String animalYear;
  final String sak;
  final bool isLeapMonth;
  final bool isSilDay;
  final String lunarDateText;
  final String gregorianDateText;
  final String gregorianDayText;
  final String gregorianMonthText;
  final String gregorianYearText;
  final String? observanceText;
  final String fullText;
  final List<Holiday>? holidays;

  LunarDay withHolidays(List<Holiday> list) => LunarDay(
        gregorianDate: gregorianDate,
        dayOfWeek: dayOfWeek,
        buddhistEraYear: buddhistEraYear,
        buddhistEraYearKhmer: buddhistEraYearKhmer,
        khmerYear: khmerYear,
        khmerYearKhmer: khmerYearKhmer,
        khmerMonth: khmerMonth,
        moonStatus: moonStatus,
        moonDay: moonDay,
        moonDayKhmer: moonDayKhmer,
        animalYear: animalYear,
        sak: sak,
        isLeapMonth: isLeapMonth,
        isSilDay: isSilDay,
        lunarDateText: lunarDateText,
        gregorianDateText: gregorianDateText,
        gregorianDayText: gregorianDayText,
        gregorianMonthText: gregorianMonthText,
        gregorianYearText: gregorianYearText,
        observanceText: observanceText,
        fullText: fullText,
        holidays: list,
      );
}

const monthEn = {
  'ចេត្រ': 'Chet',
  'ពិសាខ': 'Vesak',
  'ជេស្ឋ': 'Jeṭṭha',
  'អាសាឍ': 'Asadha',
  'បឋមាសាឍ': 'Pathamasadha',
  'ទុតិយាសាឍ': 'Tutiyasadha',
  'ស្រាពណ៍': 'Srapon',
  'ភទ្របទ': 'Photrobot',
  'អស្សុជ': 'Assuj',
  'កត្តិក': 'Kattik',
  'មិគសិរ': 'Migasir',
  'បុស្ស': 'Pous',
  'មាឃ': 'Magha',
  'ផល្គុន': 'Phalguna',
};

const zodiac = ['ជូត', 'ឆ្លូវ', 'ខាល', 'ថោះ', 'រោង', 'ម្សាញ់', 'មមី', 'មមែ', 'វក', 'រកា', 'ច', 'កុរ'];

const zodiacEn = {
  'ជូត': 'Rat',
  'ឆ្លូវ': 'Ox',
  'ខាល': 'Tiger',
  'ថោះ': 'Rabbit',
  'រោង': 'Dragon',
  'ម្សាញ់': 'Snake',
  'មមី': 'Horse',
  'មមែ': 'Goat',
  'វក': 'Monkey',
  'រកា': 'Rooster',
  'ច': 'Dog',
  'កុរ': 'Pig',
};

const sak = [
  'ឯកស័ក',
  'ទោស័ក',
  'ត្រីស័ក',
  'ចត្វាស័ក',
  'បញ្ចស័ក',
  'ឆស័ក',
  'សប្តស័ក',
  'អដ្ឋស័ក',
  'នព្វស័ក',
  'សំរឹទ្ធិស័ក',
];

const _waxing = 'កើត';
const _waning = 'រោច';
const weekdaysKm = ['អាទិត្យ', 'ចន្ទ', 'អង្គារ', 'ពុធ', 'ព្រហស្បតិ៍', 'សុក្រ', 'សៅរ៍'];
const _monthsKm = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
const _khmerDigits = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩'];

const _epoch = 1900;
// The cursor table is anchored at _epoch but walked backwards for earlier years.
const _minYear = 1;
const _epochMonth = 2;
const _epochDay = 1;
const _normalYear = 354;
const _leapDayYear = 355;
const _leapMonthYear = 384;
const _smallMonth = 29;
const _bigMonth = 30;

const _normalMonths = ['មិគសិរ', 'បុស្ស', 'មាឃ', 'ផល្គុន', 'ចេត្រ', 'ពិសាខ', 'ជេស្ឋ', 'អាសាឍ', 'ស្រាពណ៍', 'ភទ្របទ', 'អស្សុជ', 'កត្តិក'];
const _leapMonths = ['មិគសិរ', 'បុស្ស', 'មាឃ', 'ផល្គុន', 'ចេត្រ', 'ពិសាខ', 'ជេស្ឋ', 'បឋមាសាឍ', 'ទុតិយាសាឍ', 'ស្រាពណ៍', 'ភទ្របទ', 'អស្សុជ', 'កត្តិក'];

final _yearHolidays = <int, List<Holiday>>{};
final _newYearCache = <int, ({DateTime gregorianStartDate, int totalDays})>{};
final _vesak16 = <int, DateTime>{};
final _dayCache = <String, LunarDay>{};
final _lunarCache = <String, LunarDay>{};
final _yearCursorCache = <int, ({int month, int day})>{};
final _cwCache = <int, int>{};
final _yearTypeCache = <int, String>{};
final _yearTableCache = <int, List<({int month, int day, int length})>>{};

int _mod(int e, int t) => (e % t + t) % t;

DateTime _dateOnly(DateTime e) => DateTime(e.year, e.month, e.day);

DateTime _addDays(DateTime e, int t) => DateTime(e.year, e.month, e.day + t);

bool _onOrAfter(DateTime e, DateTime t) => !_dateOnly(e).isBefore(_dateOnly(t));

int _jsWeekday(DateTime d) => d.weekday % 7;

String toIso(DateTime e) {
  final y = e.year.toString().padLeft(4, '0');
  final m = e.month.toString().padLeft(2, '0');
  final d = e.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

DateTime parseDate(Object e) {
  if (e is DateTime) {
    if (e.year < _minYear) throw ArgumentError('Dates before $_minYear-01-01 are not supported.');
    return _dateOnly(e);
  }
  if (e is String) {
    final t = e.trim();
    final iso = _isoPattern.firstMatch(t);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final m = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      final r = DateTime(y, m, d);
      if (r.year != y || r.month != m || r.day != d) throw ArgumentError('Invalid date provided.');
      if (y < _minYear) throw ArgumentError('Dates before $_minYear-01-01 are not supported.');
      return r;
    }
  }
  throw ArgumentError('Invalid date provided.');
}

String khmerNum(Object v) {
  final s = v.toString();
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    if (c >= 0x30 && c <= 0x39) {
      b.write(_khmerDigits[c - 0x30]);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

List<int> _normHms(int e, int t, int n) {
  var r = e, i = t, a = n;
  while (a >= 60) {
    a -= 60;
    i += 1;
  }
  while (a < 0) {
    a += 60;
    i -= 1;
  }
  while (i >= 30) {
    i -= 30;
    r += 1;
  }
  while (i < 0) {
    i += 30;
    r -= 1;
  }
  r = _mod(r, 12);
  return [r, i, a];
}

List<int> _addHms(List<int> e, List<int> t) => _normHms(e[0] + t[0], e[1] + t[1], e[2] + t[2]);
List<int> _subHms(List<int> e, List<int> t) => _normHms(e[0] - t[0], e[1] - t[1], e[2] - t[2]);

int _wc(int e) => 800 - _mod(e * 292207 + 373, 800);

List<int> _gc(int e, int t) {
  final n = t * 800 + e;
  final r = n ~/ 24350;
  final i = n % 24350;
  final a = i ~/ 811;
  final o = i % 811;
  return [r, a, o ~/ 14 - 3];
}

List<int> _kc(List<int> e) {
  final t = e[0] - 2;
  final n = [t, e[1] - 20, e[2]];
  late List<int> r;
  switch (t) {
    case 0:
    case 1:
    case 2:
      r = [t, 0, 0];
      break;
    case 3:
    case 4:
    case 5:
      r = _subHms([5, 29, 60], n);
      break;
    case 6:
    case 7:
    case 8:
      r = _subHms(n, [6, 0, 0]);
      break;
    default:
      r = _subHms([11, 29, 60], n);
  }
  final i = r[0] * 2 + 1;
  final a = ((r[1] - 15) * 60 + 30) * i;
  final o = a ~/ 900 + 129;
  return [0, o ~/ 60, o % 60];
}

bool _hasDup(List<List<int>> e) {
  final t = <int, int>{};
  for (final n in e) {
    t[n[1]] = (t[n[1]] ?? 0) + 1;
  }
  return t.values.any((e) => e > 1);
}

int _newYearLengthHint(int e) {
  final t = _wc(e - 638 - 1);
  final n = <List<int>>[];
  for (var i = 0; i < 4; i += 1) {
    final r = _gc(t, 363 + i);
    n.add(_addHms(r, _kc(r)));
  }
  return _hasDup(n) ? 2 : 1;
}

bool _isLeapGregorian(int e) => e % 4 == 0 && (e % 100 != 0 || e % 400 == 0);
int _gregorianLength(int e) => _isLeapGregorian(e) ? 366 : 365;
int _beOf(int e) => e + 544;
int _iw(int e) => ((_beOf(e) * 292207 + 499) ~/ 800) + 4;
int _aw(int e) => (11 * _iw(e) + 25) % 692;
int _ow(int e) {
  final t = _iw(e);
  return (((11 * t + 25) ~/ 692) + t + 29) % 30;
}

bool _sw(int e) => 800 - (_beOf(e) * 292207 + 499) % 800 <= 207;

int _cw(int e) => _cwCache[e] ??= _cwCompute(e);

int _cwCompute(int e) {
  final t = _aw(e);
  final n = _ow(e);
  var r = n >= 25 || n <= 5;
  var i = false;
  if (_sw(e)) {
    i = t <= 126;
  } else if (t <= 137) {
    i = _aw(e + 1) != 0;
  }
  if (n == 25 && _ow(e + 1) == 5) r = false;
  if (n == 24 && _ow(e + 1) == 6) r = true;
  if (r && i) return 3;
  if (r) return 1;
  if (i) return 2;
  return 0;
}

String _yearType(int e) => _yearTypeCache[e] ??= _yearTypeCompute(e);

String _yearTypeCompute(int e) {
  final t = _cw(e);
  if (t == 3 || t == 1) return 'leap-month';
  if (t == 2 || _cw(e - 1) == 3) return 'leap-day';
  return 'normal';
}

int _yearLength(int e) {
  final t = _yearType(e);
  if (t == 'leap-month') return _leapMonthYear;
  if (t == 'leap-day') return _leapDayYear;
  return _normalYear;
}

int _monthCount(int e) => _yearType(e) == 'leap-month' ? _leapMonths.length : _normalMonths.length;

int _wrapMonth(int e, int t) => _mod(e - 1, _monthCount(t)) + 1;

String _monthName(int e, int t) {
  final n = _wrapMonth(e, t);
  return (_yearType(t) == 'leap-month' ? _leapMonths : _normalMonths)[n - 1];
}

int _monthLength(int e, int t) {
  final n = _wrapMonth(e, t);
  final r = _yearType(t);
  if (r == 'leap-month') {
    if (n == 8 || n == 9 || ((n > 9 ? n - 1 : n) % 2 == 0)) return _bigMonth;
    return _smallMonth;
  }
  if (n == 7) return r == 'leap-day' ? _bigMonth : _smallMonth;
  return n % 2 == 0 ? _bigMonth : _smallMonth;
}

int _dayOfYear(DateTime e) => e.difference(DateTime(e.year, 1, 1)).inDays;

/// One entry per day of the Gregorian [year] (index = day of year, 0-based):
/// the Khmer month, day-in-month and month length. Built once per year so a
/// date lookup is O(1) instead of walking up to 365 days with repeated
/// leap-year maths on every call.
List<({int month, int day, int length})> _yearTable(int year) {
  final hit = _yearTableCache[year];
  if (hit != null) return hit;
  final start = _cursorOf(year);
  var m = start.month;
  var d = start.day;
  var len = _monthLength(m, year);
  final out = <({int month, int day, int length})>[(month: m, day: d, length: len)];
  for (var k = 0; k < 366; k += 1) {
    d += 1;
    if (d > len) {
      d = 1;
      m = _wrapMonth(m + 1, year);
      len = _monthLength(m, year);
    }
    out.add((month: m, day: d, length: len));
  }
  _yearTableCache[year] = out;
  return out;
}

({int month, int day}) _cursorOf(int e) {
  final hit = _yearCursorCache[e];
  if (hit != null) return hit;
  if (e < _epoch) {
    // Walk backwards from the nearest known year: the exact inverse of the forward step below.
    var t = _epochMonth;
    var n = _epochDay;
    var from = _epoch;
    for (var y = e + 1; y < _epoch; y += 1) {
      final next = _yearCursorCache[y];
      if (next != null) {
        from = y;
        t = next.month;
        n = next.day;
        break;
      }
    }
    for (var r = from - 1; r >= e; r -= 1) {
      n -= _gregorianLength(r) - _yearLength(r);
      while (n <= 0) {
        t = _wrapMonth(t - 1, r);
        n += _monthLength(t, r);
      }
      while (n > _monthLength(t, r)) {
        n -= _monthLength(t, r);
        t = _wrapMonth(t + 1, r);
      }
      _yearCursorCache[r] = (month: t, day: n);
    }
    return _yearCursorCache[e]!;
  }
  var t = _epochMonth;
  var n = _epochDay;
  var from = _epoch;
  for (var y = e - 1; y > _epoch; y -= 1) {
    final prev = _yearCursorCache[y];
    if (prev != null) {
      from = y;
      t = prev.month;
      n = prev.day;
      break;
    }
  }
  for (var r = from; r < e; r += 1) {
    n += _gregorianLength(r) - _yearLength(r);
    while (n > _monthLength(t, r)) {
      n -= _monthLength(t, r);
      t = _wrapMonth(t + 1, r);
    }
    while (n <= 0) {
      t = _wrapMonth(t - 1, r);
      n += _monthLength(t, r);
    }
  }
  final out = (month: t, day: n);
  _yearCursorCache[e] = out;
  return out;
}

({String khmerMonth, int monthDay, int monthLength, String yearType}) _lunarParts(DateTime e) {
  final t = e.year;
  final r = _yearTable(t)[_dayOfYear(e)];
  return (
    khmerMonth: _monthName(r.month, t),
    monthDay: r.day,
    monthLength: r.length,
    yearType: _yearType(t),
  );
}

// The Khmer year is sidereal (365.25875 d) so its new year drifts against the Gregorian
// calendar. A month + day label repeats about every 354 days, so it can occur twice inside
// one Gregorian year; take the occurrence closest to where it falls in the modern era,
// shifted by the estimated drift. For 1900-2100 this is the same date the old fixed
// April 10 - June 15 window gave.
int _driftDays(int year) => ((year - 2000) * 0.01625).round();

DateTime _locate(int year, String khmerMonth, int monthDay) {
  final center = DateTime(year, 5, 13).difference(DateTime(year, 1, 1)).inDays + _driftDays(year);
  DateTime? best;
  var bestGap = 1 << 30;
  var n = DateTime(year, 1, 1);
  final r = DateTime(year, 12, 31);
  while (!n.isAfter(r)) {
    final parts = _lunarParts(n);
    if (parts.khmerMonth == khmerMonth && parts.monthDay == monthDay) {
      final gap = (_dayOfYear(n) - center).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = _dateOnly(n);
      }
    }
    n = _addDays(n, 1);
  }
  if (best != null) return best;
  throw StateError('Unable to locate Khmer boundary date for Gregorian year $year.');
}

({String khmerMonth, int monthDay}) _newYearAnchor(int e) {
  final t = _ow(e);
  if (t >= 6) {
    return (khmerMonth: 'ចេត្រ', monthDay: t + (_cw(e - 1) == 3 ? 1 : 0));
  }
  return (khmerMonth: 'ពិសាខ', monthDay: t + 1);
}

({DateTime gregorianStartDate, int totalDays}) _khmerNewYear(int e) {
  final hit = _newYearCache[e];
  if (hit != null) return (gregorianStartDate: _dateOnly(hit.gregorianStartDate), totalDays: hit.totalDays);
  final n = _newYearLengthHint(e);
  final anchor = _newYearAnchor(e);
  final r = (
    gregorianStartDate: _addDays(_locate(e, anchor.khmerMonth, anchor.monthDay), -(n + 1)),
    totalDays: n + 2,
  );
  _newYearCache[e] = r;
  return (gregorianStartDate: _dateOnly(r.gregorianStartDate), totalDays: r.totalDays);
}

int _khmerYearOf(DateTime e) {
  final t = e.year;
  final n = _khmerNewYear(t).gregorianStartDate;
  return _onOrAfter(e, n) ? t : t - 1;
}

String _animalOf(int e) => zodiac[_mod(e - 2020, zodiac.length)];
String _sakOf(int e) => sak[_mod(e - 2019, sak.length)];

DateTime _vesak16Of(int e) {
  final t = _vesak16[e];
  if (t != null) return _dateOnly(t);
  final n = _locate(e, 'ពិសាខ', 16);
  _vesak16[e] = n;
  return _dateOnly(n);
}

({String moonStatus, int moonDay}) _moonOf(int e) {
  final t = e <= 15;
  return (moonStatus: t ? _waxing : _waning, moonDay: t ? e : e - 15);
}

bool _isLeapMonthName(String e) => e == 'បឋមាសាឍ' || e == 'ទុតិយាសាឍ';
bool _isSil(int e, int t) => e == 8 || e == 15 || e == 23 || e == t;

String? _silText(int e, String t, bool n) {
  if (e == 15 && t == _waxing) return 'ថ្ងៃនេះ ជាថ្ងៃសីល និងពេញបូណ៌មី';
  if (n) return 'ថ្ងៃនេះ ជាថ្ងៃសីល';
  return null;
}

String _lunarLine(String e, int t, String n, String r, String i, String a, int o) =>
    'ថ្ងៃ$e ${khmerNum(t)}$n ខែ$r ឆ្នាំ$i $a ពុទ្ធសករាជ ${khmerNum(o)}';

String _gregLine(DateTime e) => 'ថ្ងៃទី${khmerNum(e.day)} ខែ${_monthsKm[e.month - 1]} ឆ្នាំ${khmerNum(e.year)}';

String _fullLine(String e, String t, String? n) {
  final r = '$e ត្រូវនឹង$t';
  return n != null ? '$r $n' : r;
}

LunarDay lunarOf(Object d) {
  final e = parseDate(d);
  final iso = toIso(e);
  final hit = _lunarCache[iso];
  if (hit != null) return hit;
  final t = _khmerYearOf(e);
  final n = _lunarParts(e);
  final moon = _moonOf(n.monthDay);
  final a = _onOrAfter(e, _vesak16Of(e.year)) ? e.year + 544 : e.year + 543;
  final s = _animalOf(t);
  final c = _sakOf(t);
  final l = weekdaysKm[_jsWeekday(e)];
  final u = _isSil(n.monthDay, n.monthLength);
  final observance = _silText(n.monthDay, moon.moonStatus, u);
  final h = _lunarLine(l, moon.moonDay, moon.moonStatus, n.khmerMonth, s, c, a);
  final g = _gregLine(e);
  final out = LunarDay(
    gregorianDate: toIso(e),
    dayOfWeek: l,
    buddhistEraYear: a,
    buddhistEraYearKhmer: khmerNum(a),
    khmerYear: a,
    khmerYearKhmer: khmerNum(a),
    khmerMonth: n.khmerMonth,
    moonStatus: moon.moonStatus,
    moonDay: moon.moonDay,
    moonDayKhmer: khmerNum(moon.moonDay),
    animalYear: s,
    sak: c,
    isLeapMonth: _isLeapMonthName(n.khmerMonth),
    isSilDay: u,
    lunarDateText: h,
    gregorianDateText: g,
    gregorianDayText: khmerNum(e.day),
    gregorianMonthText: _monthsKm[e.month - 1],
    gregorianYearText: khmerNum(e.year),
    observanceText: observance,
    fullText: _fullLine(h, g, observance),
  );
  _lunarCache[iso] = out;
  return out;
}

bool _lunarMatches(LunarDay e, {required String month, required String status, required List<int> days}) =>
    e.khmerMonth == month && e.moonStatus == status && days.contains(e.moonDay);

void _pushHoliday(List<Holiday> e, Holiday t) {
  final n = e.indexWhere(
    (x) => x.date == t.date && x.type == t.type && (x.nameEn == t.nameEn || x.nameKm == t.nameKm),
  );
  if (n == -1) {
    e.add(t);
    return;
  }
  e[n] = t;
}

void _applyLunarHolidays(List<Holiday> list, LunarDay t, String n) {
  void add(String km, String en, HolidayType type, bool ok) {
    if (ok) _pushHoliday(list, Holiday(date: n, nameKm: km, nameEn: en, type: type));
  }

  add('មាឃបូជា', 'Meak Bochea', HolidayType.religious, _lunarMatches(t, month: 'មាឃ', status: _waxing, days: const [15]));
  add('វិសាខបូជា', 'Visak Bochea', HolidayType.religious, _lunarMatches(t, month: 'ពិសាខ', status: _waxing, days: const [15]));
  add('វិសាខបូជា', 'Visak Bochea Day', HolidayType.public, _lunarMatches(t, month: 'ពិសាខ', status: _waxing, days: const [15]));
  add('ព្រះរាជពិធីច្រត់ព្រះនង្គ័ល', 'Royal Ploughing Ceremony', HolidayType.public,
      _lunarMatches(t, month: 'ពិសាខ', status: _waning, days: const [4]));
  add('ភ្ជុំបិណ្ឌ', 'Pchum Ben', HolidayType.religious, _lunarMatches(t, month: 'ភទ្របទ', status: _waning, days: const [15]));
  add(
    'ព្រះរាជពិធីបុណ្យភ្ជុំបិណ្ឌ',
    'Pchum Ben Festival',
    HolidayType.public,
    (_lunarMatches(t, month: 'ភទ្របទ', status: _waning, days: const [14, 15])) ||
        _lunarMatches(t, month: 'អស្សុជ', status: _waxing, days: const [1]),
  );
  add('ព្រះរាជពិធីបុណ្យអុំទូក', 'Water Festival', HolidayType.traditional,
      _lunarMatches(t, month: 'កត្តិក', status: _waxing, days: const [14, 15]));
  add(
    'ព្រះរាជពិធីបុណ្យអុំទូក',
    'Water Festival',
    HolidayType.public,
    _lunarMatches(t, month: 'កត្តិក', status: _waxing, days: const [14, 15]) ||
        _lunarMatches(t, month: 'កត្តិក', status: _waning, days: const [1]),
  );
  add(
    'ចូលព្រះវស្សា',
    'Entering Vassa',
    HolidayType.religious,
    _lunarMatches(t, month: 'អាសាឍ', status: _waxing, days: const [15]) ||
        _lunarMatches(t, month: 'ទុតិយាសាឍ', status: _waxing, days: const [15]),
  );
  add(
    'បុណ្យអាសាឡ្ហបូជា',
    'Asalha Puja',
    HolidayType.religious,
    _lunarMatches(t, month: 'អាសាឍ', status: _waxing, days: const [15]) ||
        _lunarMatches(t, month: 'ទុតិយាសាឍ', status: _waxing, days: const [15]),
  );
  add('ចេញព្រះវស្សា', 'Leaving Vassa', HolidayType.religious, _lunarMatches(t, month: 'អស្សុជ', status: _waxing, days: const [15]));
  add('កឋិន', 'Kathina', HolidayType.religious, _lunarMatches(t, month: 'អស្សុជ', status: _waning, days: const [1]));
  add(
    'តាំងពិធីត្រស្តិសង្ក្រាន្ត',
    'Trasat Sangkran Eve',
    HolidayType.traditional,
    _lunarMatches(t, month: 'ផល្គុន', status: _waning, days: const [12, 13, 14]),
  );
  add(
    'ព្រះរាជពិធីត្រស្តិសង្ក្រាន្ត',
    'Trasat Sangkran',
    HolidayType.traditional,
    _lunarMatches(t, month: 'ផល្គុន', status: _waning, days: const [15]),
  );
}

void _applyChineseHolidays(List<Holiday> list, DateTime gregorian, String iso) {
  final lunar = solarToChineseLunar(gregorian.year, gregorian.month, gregorian.day);
  if (lunar == null) return;

  void add(String km, String en, bool ok) {
    if (ok) {
      _pushHoliday(list, Holiday(date: iso, nameKm: km, nameEn: en, type: HolidayType.traditional));
    }
  }

  if (!lunar.isLeap) {
    add('សែនដកជើងធូប', 'Kitchen God Festival', lunar.month == 12 && lunar.day == 24);
    add('បុណ្យចូលឆ្នាំចិន', 'Chinese New Year', lunar.month == 1 && lunar.day >= 1 && lunar.day <= 3);
    add('សែននំចាំង', 'Sticky Rice Festival', lunar.month == 5 && lunar.day == 5);
    add('សែនក្បាលទឹក', 'Hungry Ghost Festival', lunar.month == 7 && lunar.day == 15);
    add('បុណ្យសែនព្រះខែ', 'Mid-Autumn Festival', lunar.month == 8 && lunar.day == 15);
  }

  final next = _addDays(gregorian, 1);
  final tomorrow = solarToChineseLunar(next.year, next.month, next.day);
  add(
    'សែនចូលឆ្នាំចិន',
    "Chinese New Year's Eve",
    tomorrow != null && tomorrow.month == 1 && tomorrow.day == 1 && !tomorrow.isLeap,
  );
}

int _qingmingAprilDay(int year) {
  final y = year % 100;
  final c = year >= 2000 ? 4.81 : 5.59;
  return (y * 0.2422 + c).floor() - (y ~/ 4);
}

DateTime _winterSolsticeIct(int year) {
  final y = (year - 2000) / 1000.0;
  final y2 = y * y;
  final y3 = y2 * y;
  final y4 = y2 * y2;
  final jde = 2451900.05952 + 365242.74049 * y - 0.06223 * y2 - 0.00823 * y3 + 0.00032 * y4;
  final unixMs = ((jde - 2440587.5) * 86400000).round();
  final ict = DateTime.fromMillisecondsSinceEpoch(unixMs + 7 * 3600 * 1000, isUtc: true);
  return DateTime(ict.year, ict.month, ict.day);
}

DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  final first = DateTime(year, month, 1);
  final delta = (weekday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + delta + (n - 1) * 7);
}

List<Holiday> _movableInternational(int e) {
  final mother = _nthWeekdayOfMonth(e, 5, DateTime.sunday, 2);
  final father = _nthWeekdayOfMonth(e, 6, DateTime.sunday, 3);
  return [
    Holiday(
      date: toIso(DateTime(e, 4, _qingmingAprilDay(e))),
      nameKm: 'សែនផ្នូរ',
      nameEn: 'Tomb-Sweeping Day',
      type: HolidayType.international,
    ),
    Holiday(date: toIso(mother), nameKm: 'ទិវាមាតា', nameEn: "Mother's Day", type: HolidayType.international),
    Holiday(date: toIso(father), nameKm: 'ទិវាបិតា', nameEn: "Father's Day", type: HolidayType.international),
  ];
}

List<Holiday> _solarTraditional(int e) {
  final winter = _winterSolsticeIct(e);
  return [
    Holiday(date: toIso(winter), nameKm: 'សែននំអ៊ី', nameEn: 'Winter Solstice', type: HolidayType.traditional),
  ];
}

List<Holiday> _khmerNewYearDays(int e) {
  final info = _khmerNewYear(e);
  return List.generate(info.totalDays, (n) {
    late final String km;
    late final String en;
    if (n == 0) {
      km = 'បុណ្យចូលឆ្នាំខ្មែរ (មហាសង្ក្រាន្ត)';
      en = 'Khmer New Year (Moha Sangkran)';
    } else if (n == info.totalDays - 1) {
      km = 'បុណ្យចូលឆ្នាំខ្មែរ (ឡើងស័ក)';
      en = 'Khmer New Year (Leung Sak)';
    } else {
      km = 'បុណ្យចូលឆ្នាំខ្មែរ (វ័នបត)';
      en = 'Khmer New Year (Vanabat)';
    }
    return Holiday(
      date: toIso(_addDays(info.gregorianStartDate, n)),
      nameKm: km,
      nameEn: en,
      type: HolidayType.public,
    );
  });
}

List<Holiday> _internationalEvents(int e) => [
      Holiday(date: '$e-02-14', nameKm: 'ថ្ងៃបុណ្យនៃសេចក្តីស្រលាញ់', nameEn: "Valentine's Day", type: HolidayType.international),
      Holiday(date: '$e-02-21', nameKm: 'ទិវាជាតិសុខភាពមាតា និងទារក', nameEn: 'National Day on Maternal, Newborn and Child Health', type: HolidayType.international),
      Holiday(date: '$e-02-24', nameKm: 'ទិវាជាតិយល់ដឹងពីមីន', nameEn: 'National Mine Awareness Day', type: HolidayType.international),
      Holiday(date: '$e-03-03', nameKm: 'ទិវាវប្បធម៌ជាតិ', nameEn: 'National Culture Day', type: HolidayType.international),
      Holiday(date: '$e-03-04', nameKm: 'ទិវានយោបាយទឹក', nameEn: 'Water Policy Day', type: HolidayType.international),
      Holiday(date: '$e-03-06', nameKm: 'គោរពវិញ្ញាណក្ខន្ធសម្តេចព្រះសុរាម្រឹត', nameEn: 'Commemoration of King Suramarit', type: HolidayType.international),
      Holiday(date: '$e-03-21', nameKm: 'សមរាត្រីនិទាឃរដូវអង្គរ', nameEn: 'Angkor Spring Equinox', type: HolidayType.international),
      Holiday(date: '$e-03-21', nameKm: 'ទិវាលុបបំបាត់ការរើសអើងពូជសាសន៍', nameEn: 'International Day for the Elimination of Racial Discrimination', type: HolidayType.international),
      Holiday(date: '$e-03-22', nameKm: 'ទិវាពិភពលោកទឹក', nameEn: 'World Water Day', type: HolidayType.international),
      Holiday(date: '$e-03-24', nameKm: 'ទិវាពិភពលោកកំចាត់ជម្ងឺរបេង', nameEn: 'World Tuberculosis Day', type: HolidayType.international),
      Holiday(date: '$e-04-07', nameKm: 'ទិវាសុខភាពពិភពលោក', nameEn: 'World Health Day', type: HolidayType.international),
      Holiday(date: '$e-04-22', nameKm: 'ទិវាផែនដី', nameEn: 'Earth Day', type: HolidayType.international),
      Holiday(date: '$e-04-28', nameKm: 'ទិវាសុវត្ថិភាព និងសុខភាពការងារ', nameEn: 'World Day for Safety and Health at Work', type: HolidayType.international),
      Holiday(date: '$e-05-03', nameKm: 'ទិវាសេរីភាពសារព័ត៌មានពិភពលោក', nameEn: 'World Press Freedom Day', type: HolidayType.international),
      Holiday(date: '$e-05-08', nameKm: 'ទិវាកាកបាទក្រហម', nameEn: 'World Red Cross Day', type: HolidayType.international),
      Holiday(date: '$e-05-20', nameKm: 'ទិវាជាតិនៃការចងចាំ', nameEn: 'National Day of Remembrance', type: HolidayType.international),
      Holiday(date: '$e-05-31', nameKm: 'ទិវាគ្មានថ្នាំជក់ពិភពលោក', nameEn: 'World No Tobacco Day', type: HolidayType.international),
      Holiday(date: '$e-06-01', nameKm: 'ទិវាកុមារអន្តរជាតិ', nameEn: "International Children's Day", type: HolidayType.international),
      Holiday(date: '$e-06-05', nameKm: 'ទិវាបរិស្ថានពិភពលោក', nameEn: 'World Environment Day', type: HolidayType.international),
      Holiday(date: '$e-06-12', nameKm: 'ទិវាពិភពលោកប្រឆាំងពលកម្មកុមារ', nameEn: 'World Day Against Child Labour', type: HolidayType.international),
      Holiday(date: '$e-06-26', nameKm: 'ទិវាអន្តរជាតិប្រឆាំងគ្រឿងញៀន', nameEn: 'International Day against Drug Abuse', type: HolidayType.international),
      Holiday(date: '$e-07-01', nameKm: 'ទិវាត្រីជាតិ', nameEn: 'National Fish Day', type: HolidayType.international),
      Holiday(date: '$e-07-03', nameKm: 'កម្ពុជាចូលជាសមាជិកអង្គការយូណេស្កូ', nameEn: 'Cambodia UNESCO Membership Day', type: HolidayType.international),
      Holiday(date: '$e-07-07', nameKm: 'ខួបបេតិកភណ្ឌពិភពលោក ប្រាសាទព្រះវិហារ', nameEn: 'Preah Vihear World Heritage Day', type: HolidayType.international),
      Holiday(date: '$e-07-08', nameKm: 'ខួបបេតិកភណ្ឌពិភពលោក សំបូរព្រៃគុក', nameEn: 'Sambor Prei Kuk World Heritage Day', type: HolidayType.international),
      Holiday(date: '$e-07-09', nameKm: 'ទិវាដាំដើមឈើ', nameEn: 'Arbor Day', type: HolidayType.international),
      Holiday(date: '$e-07-11', nameKm: 'ទិវាប្រជាជនពិភពលោក', nameEn: 'World Population Day', type: HolidayType.international),
      Holiday(date: '$e-07-31', nameKm: 'ទិវាអាស៊ាន', nameEn: 'ASEAN Day', type: HolidayType.international),
      Holiday(date: '$e-08-09', nameKm: 'ទិវាជនជាតិដើមអន្តរជាតិ', nameEn: "International Day of the World's Indigenous Peoples", type: HolidayType.international),
      Holiday(date: '$e-08-12', nameKm: 'ទិវាយុវជនអន្តរជាតិ', nameEn: 'International Youth Day', type: HolidayType.international),
      Holiday(date: '$e-09-08', nameKm: 'ទិវាអក្ខរកម្មអន្តរជាតិ', nameEn: 'International Literacy Day', type: HolidayType.international),
      Holiday(date: '$e-09-15', nameKm: 'ទិវាប្រជាធិបតេយ្យអន្តរជាតិ', nameEn: 'International Day of Democracy', type: HolidayType.international),
      Holiday(date: '$e-09-16', nameKm: 'ទិវាអន្តរជាតិអភិរក្សស្រទាប់អូហ្សូន', nameEn: 'International Day for the Preservation of the Ozone Layer', type: HolidayType.international),
      Holiday(date: '$e-09-17', nameKm: 'ខួបបេតិកភណ្ឌពិភពលោក កោះកេរ', nameEn: 'Koh Ker World Heritage Day', type: HolidayType.international),
      Holiday(date: '$e-09-21', nameKm: 'ទិវាសន្តិភាពអន្តរជាតិ', nameEn: 'International Day of Peace', type: HolidayType.international),
      Holiday(date: '$e-09-22', nameKm: 'សមរាត្រីសរទរដូវអង្គរ', nameEn: 'Angkor Autumn Equinox', type: HolidayType.international),
      Holiday(date: '$e-09-27', nameKm: 'ទិវាទេសចរណ៍ពិភពលោក', nameEn: 'World Tourism Day', type: HolidayType.international),
      Holiday(date: '$e-10-05', nameKm: 'ទិវាគ្រូបង្រៀនពិភពលោក', nameEn: "World Teachers' Day", type: HolidayType.international),
      Holiday(date: '$e-10-23', nameKm: 'ទិវាកិច្ចព្រមព្រៀងសន្តិភាពទីក្រុងប៉ារីស', nameEn: 'Paris Peace Agreements Day', type: HolidayType.international),
      Holiday(date: '$e-10-24', nameKm: 'ទិវាអង្គការសហប្រជាជាតិ', nameEn: 'United Nations Day', type: HolidayType.international),
      Holiday(date: '$e-10-31', nameKm: 'បុណ្យហាឡូវីន', nameEn: 'Halloween', type: HolidayType.international),
      Holiday(date: '$e-11-20', nameKm: 'ទិវាសិទ្ធិកុមារ', nameEn: "Universal Children's Day", type: HolidayType.international),
      Holiday(date: '$e-11-25', nameKm: 'ទិវាអន្តរជាតិលុបបំបាត់អំពើហិង្សាលើស្ត្រី', nameEn: 'International Day for the Elimination of Violence against Women', type: HolidayType.international),
      Holiday(date: '$e-12-01', nameKm: 'ទិវាពិភពលោកប្រយុទ្ធនឹងជំងឺអេដស៍', nameEn: 'World AIDS Day', type: HolidayType.international),
      Holiday(date: '$e-12-03', nameKm: 'ទិវាជនពិការអន្តរជាតិ', nameEn: 'International Day of Persons with Disabilities', type: HolidayType.international),
      Holiday(date: '$e-12-07', nameKm: 'ទិវាអាកាសចរណ៍ស៊ីវិលអន្តរជាតិ', nameEn: 'International Civil Aviation Day', type: HolidayType.international),
      Holiday(date: '$e-12-09', nameKm: 'ទិវាប្រឆាំងអំពើពុករលួយអន្តរជាតិ', nameEn: 'International Anti-Corruption Day', type: HolidayType.international),
      Holiday(date: '$e-12-10', nameKm: 'ទិវាសិទ្ធិមនុស្សអន្តរជាតិ', nameEn: 'Human Rights Day', type: HolidayType.international),
      Holiday(date: '$e-12-12', nameKm: 'ទិវាអន្តរជាតិអព្យាក្រឹតភាព', nameEn: 'International Day of Neutrality', type: HolidayType.international),
      Holiday(date: '$e-12-14', nameKm: 'ខួបបេតិកភណ្ឌពិភពលោក អង្គរ', nameEn: 'Angkor World Heritage Day', type: HolidayType.international),
      Holiday(date: '$e-12-25', nameKm: 'បុណ្យណូអែល', nameEn: 'Christmas Day', type: HolidayType.international),
      Holiday(date: '$e-12-31', nameKm: 'ថ្ងៃឆ្លងឆ្នាំសកល', nameEn: "New Year's Eve", type: HolidayType.international),
    ];

List<Holiday> _fixedHolidays(int e) => [
      Holiday(date: '$e-01-01', nameKm: 'បុណ្យចូលឆ្នាំសកល', nameEn: "International New Year's Day", type: HolidayType.public),
      Holiday(date: '$e-01-07', nameKm: 'ទិវាជ័យជម្នះលើរបបប្រល័យពូជសាសន៍', nameEn: 'Victory over Genocide Day', type: HolidayType.public),
      Holiday(date: '$e-03-08', nameKm: 'ទិវានារីអន្តរជាតិ', nameEn: "International Women's Day", type: HolidayType.public),
      ..._khmerNewYearDays(e),
      Holiday(date: '$e-05-01', nameKm: 'ទិវាពលកម្មអន្តរជាតិ', nameEn: 'International Labour Day', type: HolidayType.public),
      Holiday(date: '$e-05-14', nameKm: 'ព្រះរាជពិធីចម្រើនព្រះជន្ម ព្រះមហាក្សត្រ', nameEn: "King's Birthday", type: HolidayType.public),
      Holiday(date: '$e-06-18', nameKm: 'ព្រះរាជពិធីចម្រើនព្រះជន្ម ព្រះមហាក្សត្រី', nameEn: "Queen Mother's Birthday", type: HolidayType.public),
      Holiday(date: '$e-09-24', nameKm: 'ទិវារដ្ឋធម្មនុញ្ញ', nameEn: 'Constitution Day', type: HolidayType.public),
      Holiday(date: '$e-10-15', nameKm: 'ទិវាគោរពព្រះវិញ្ញាណក្ខន្ធ ព្រះបរមរតនកោដ្ឋ', nameEn: "Commemoration Day of King's Father", type: HolidayType.public),
      Holiday(date: '$e-10-29', nameKm: 'ព្រះរាជពិធីគ្រងរាជ្យ', nameEn: 'Coronation Day', type: HolidayType.public),
      Holiday(date: '$e-11-09', nameKm: 'បុណ្យឯករាជ្យជាតិ', nameEn: 'Independence Day', type: HolidayType.public),
      Holiday(date: '$e-12-29', nameKm: 'ទិវាសន្តិភាពនៅកម្ពុជា', nameEn: 'Peace Day in Cambodia', type: HolidayType.public),
      ..._internationalEvents(e),
      ..._movableInternational(e),
      ..._solarTraditional(e),
    ];

List<Holiday> holidaysOfYear(int e) {
  if (e < _minYear) throw ArgumentError('Year must be $_minYear or later.');
  final hit = _yearHolidays[e];
  if (hit != null) return hit.map((x) => x.copy()).toList();
  final t = _fixedHolidays(e);
  var n = DateTime(e, 1, 1);
  final last = DateTime(e, 12, 31);
  while (!n.isAfter(last)) {
    _applyLunarHolidays(t, lunarOf(n), toIso(n));
    _applyChineseHolidays(t, n, toIso(n));
    n = _addDays(n, 1);
  }
  t.sort((a, b) => a.date.compareTo(b.date));
  _yearHolidays[e] = t;
  return t.map((x) => x.copy()).toList();
}

LunarDay dayInfo(Object d) {
  final iso = toIso(parseDate(d));
  final cached = _dayCache[iso];
  if (cached != null) return cached;
  final n = lunarOf(iso);
  final r = holidaysOfYear(parseDate(iso).year).where((e) => e.date == n.gregorianDate).toList();
  final out = n.withHolidays(r);
  _dayCache[iso] = out;
  return out;
}

List<Holiday> holidaysOn(String iso) {
  final n = dayInfo(iso).holidays ?? const <Holiday>[];
  if (n.isNotEmpty) return n;
  final y = int.parse(iso.substring(0, 4));
  return holidaysOfYear(y).where((t) => t.date == iso).toList();
}

List<String> animalPair(LunarDay e) {
  final t = (e.moonDay + 10) % zodiac.length;
  return [zodiac[t], zodiac[(t + 6) % zodiac.length]];
}
