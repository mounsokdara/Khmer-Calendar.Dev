import 'package:flutter/material.dart';

import '../custom_components/scroll_picker.dart';
import '../dates.dart';
import '../i18n.dart';
import '../store.dart';

/// Years the home-screen month widget has marks/holiday data for.
const widgetYearMin = 1900;
const widgetYearMax = 2100;

/// The month + year scroll picker dialog. Returns the first day of the chosen month, or null if cancelled.
///
/// [minYear]/[maxYear] bound the year column (defaults to the full calendar range).
Future<DateTime?> pickMonthYearWheel(
  BuildContext context, {
  required Lang lang,
  required int year,
  required int month,
  int minYear = calendarStartYear,
  int maxYear = calendarEndYear,
}) async {
  final lo = minYear;
  final hi = maxYear < lo ? lo : maxYear;
  final months = monthsOf(lang);
  final years = [for (var y = lo; y <= hi; y++) '$y'];
  final yIndex = year.clamp(lo, hi) - lo;
  final picked = await showScrollPickerDialog(
    context,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(t(lang, 'wheelTitleMonthYear'), maxLines: 1),
    ),
    initialIndices: [(month - 1).clamp(0, 11), yIndex],
    columnsBuilder: (_) => [
      ScrollPickerColumnSpec(
        labels: months,
        matcher: (q, _) => monthIndexFromQuery(q),
        maxTypedLength: 24,
      ),
      ScrollPickerColumnSpec(
        labels: years,
        matcher: ScrollPickerMatchers.number,
        keyboardType: TextInputType.number,
      ),
    ],
    confirmLabel: t(lang, 'change'),
  );
  if (picked == null) return null;
  return DateTime(lo + picked[1], picked[0] + 1, 1);
}

Future<void> showMonthWheel(BuildContext context, {required AppStore store}) async {
  final cursor = fromIso(store.cursor);
  final picked = await pickMonthYearWheel(context, lang: store.lang, year: cursor.year, month: cursor.month);
  if (picked == null) return;
  store.setCursor(isoOf(picked));
}

Future<int?> showYearWheel(BuildContext context, {required Lang lang, required int year, String? title}) async {
  final years = [for (var y = calendarStartYear; y <= calendarEndYear; y++) '$y'];
  final picked = await showScrollPickerDialog(
    context,
    title: Text(title ?? t(lang, 'wheelTitleEventYear')),
    initialIndices: [year.clamp(calendarStartYear, calendarEndYear) - calendarStartYear],
    columnsBuilder: (_) => [
      ScrollPickerColumnSpec(
        labels: years,
        matcher: ScrollPickerMatchers.number,
        keyboardType: TextInputType.number,
      ),
    ],
    confirmLabel: t(lang, 'change'),
    cancelLabel: t(lang, 'cancel'),
    width: 280,
  );
  if (picked == null) return null;
  return calendarStartYear + picked[0];
}
