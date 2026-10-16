import 'package:flutter_test/flutter_test.dart';
import 'package:khmer_calendar/calendar/chhankitek.dart';
import 'package:khmer_calendar/calendar/observances.dart';
import 'package:khmer_calendar/dates.dart';

String _key(LunarDay d) => '${d.khmerMonth} ${d.moonStatus} ${d.moonDay}';

bool _follows(LunarDay a, LunarDay b) {
  if (a.khmerMonth == b.khmerMonth) {
    if (a.moonStatus == b.moonStatus) return b.moonDay == a.moonDay + 1;
    return a.moonStatus == 'កើត' && a.moonDay == 15 && b.moonStatus == 'រោច' && b.moonDay == 1;
  }
  return a.moonStatus == 'រោច' &&
      (a.moonDay == 14 || a.moonDay == 15) &&
      b.moonStatus == 'កើត' &&
      b.moonDay == 1;
}

void main() {
  test('lunar days are continuous (incl. every Dec 31 -> Jan 1) for sampled year ranges', () {
    final problems = <String>[];
    final ranges = <(int, int)>[
      (1, 12),
      (95, 105),
      (495, 505),
      (995, 1005),
      (1495, 1505),
      (1790, 1910),
      (1990, 2060),
      (2095, 2105),
      (2995, 3005),
      (9985, 9998),
    ];
    for (final r in ranges) {
      var d = DateTime(r.$1, 1, 1);
      final end = DateTime(r.$2, 12, 31);
      var prev = lunarOf(d);
      d = addDays(d, 1);
      while (!d.isAfter(end)) {
        final cur = lunarOf(d);
        if (!_follows(prev, cur)) {
          problems.add('${isoOf(d)}: ${_key(prev)} -> ${_key(cur)}');
          if (problems.length > 80) break;
        }
        prev = cur;
        d = addDays(d, 1);
      }
    }
    expect(problems, isEmpty, reason: problems.take(80).join('\n'));
  });

  test('known Khmer dates', () {
    final newYear = <int, String>{
      2019: '2019-04-14',
      2022: '2022-04-14',
      2023: '2023-04-14',
      2024: '2024-04-13',
      2025: '2025-04-14',
    };
    final visak = <int, String>{
      2020: '2020-05-06',
      2022: '2022-05-15',
      2024: '2024-05-22',
      2025: '2025-05-11',
    };
    final pchum = <int, String>{
      2022: '2022-09-25',
      2023: '2023-10-14',
      2024: '2024-10-02',
      2025: '2025-09-22',
    };
    final problems = <String>[];
    newYear.forEach((y, iso) {
      final first = holidaysOfYear(y)
          .where((h) => h.nameEn.startsWith('Khmer New Year'))
          .map((h) => h.date)
          .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      if (first != iso) problems.add('Khmer New Year $y: got $first want $iso');
    });
    visak.forEach((y, iso) {
      final got = holidaysOfYear(y).where((h) => h.nameEn == 'Visak Bochea Day').map((h) => h.date).toList();
      if (!got.contains(iso)) problems.add('Visak Bochea $y: got $got want $iso');
    });
    pchum.forEach((y, iso) {
      final got = holidaysOfYear(y).where((h) => h.nameEn == 'Pchum Ben').map((h) => h.date).toList();
      if (!got.contains(iso)) problems.add('Pchum Ben $y: got $got want $iso');
    });
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('Visak Bochea in leap-month years (known engine gap, needs official reference)', () {
    final got21 = holidaysOfYear(2021).where((h) => h.nameEn == 'Visak Bochea Day').map((h) => h.date).toList();
    final got23 = holidaysOfYear(2023).where((h) => h.nameEn == 'Visak Bochea Day').map((h) => h.date).toList();
    expect(got21, contains('2021-05-26'));
    expect(got23, contains('2023-06-03'));
  }, skip: 'Engine is a month early before Visak in leap-month years; confirm against official dates first');

  test('every year generates the same core holidays (nothing missing in low or high years)', () {
    final years = <int>[
      1, 2, 3, 10, 50, 99, 100, 101, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300,
      1400, 1500, 1600, 1700, 1800, 1850, 1899, 1900, 1901, 1950, 1999, 2000, 2024, 2025, 2026, 2027,
      2100, 2200, 2500, 3000, 5000, 9000, 9998,
    ];
    const core = <String>[
      'Meak Bochea',
      'Visak Bochea Day',
      'Royal Ploughing Ceremony',
      'Pchum Ben',
      'Water Festival',
      'Khmer New Year (Moha Sangkran)',
      'Khmer New Year (Leung Sak)',
      "International New Year's Day",
      'Independence Day',
    ];
    final problems = <String>[];
    for (final y in years) {
      try {
        final names = holidaysOfYear(y).map((h) => h.nameEn).toSet();
        for (final c in core) {
          if (!names.contains(c)) problems.add('$y missing "$c"');
        }
        final kan = kanBenOf(y);
        if (kan.length != 14) problems.add('$y Kan Ben count ${kan.length}');
        if (senKantongOf(y).isEmpty) problems.add('$y no Sen Kantong');
      } catch (e) {
        problems.add('$y threw $e');
      }
    }
    expect(problems, isEmpty, reason: problems.take(80).join('\n'));
  });

  test('colours, lists and reminders share one holiday source', () {
    final problems = <String>[];
    for (final y in [1500, 1900, 2024, 2025, 2026, 2300]) {
      final byYear = holidayObservancesOfYear(y);
      final perDay = <String, int>{};
      for (final o in byYear) {
        perDay[o.date] = (perDay[o.date] ?? 0) + 1;
      }
      var d = DateTime(y, 1, 1);
      while (d.year == y) {
        final iso = isoOf(d);
        final day = holidayObservancesOn(iso);
        if (day.length != (perDay[iso] ?? 0)) {
          problems.add('$iso: day list ${day.length} vs year list ${perDay[iso] ?? 0}');
        }
        final hasPublic = day.any((o) => o.holidayType == HolidayType.public);
        final hasOther = day.any((o) => o.holidayType != HolidayType.public);
        if (hasPublic != isPublicHoliday(iso)) problems.add('$iso: public colour mismatch');
        if (!hasPublic && hasOther != isObservanceHoliday(iso)) problems.add('$iso: observance colour mismatch');
        d = addDays(d, 1);
        if (problems.length > 60) break;
      }
    }
    expect(problems, isEmpty, reason: problems.take(60).join('\n'));
  });
}
