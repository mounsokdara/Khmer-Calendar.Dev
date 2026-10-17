import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../calendar/chhankitek.dart';
import '../calendar/observances.dart';
import '../dates.dart';
import '../i18n.dart';
import '../notify/kinds.dart' show silPhaseLabel;
import '../store.dart';
import '../theme.dart';
import '../widgets/sil_mark.dart';

// ---------------------------------------------------------------------------
// Years: vertical scrolling grid of mini months (like the iPhone calendar).
// ---------------------------------------------------------------------------

/// Lets the page ask the years grid to scroll to a given year.
class YearsJump extends ChangeNotifier {
  int year = 0;

  void to(int y) {
    year = y;
    notifyListeners();
  }
}

class YearsGrid extends StatefulWidget {
  const YearsGrid({
    super.key,
    required this.store,
    required this.initialYear,
    required this.jump,
    required this.onTopYear,
    required this.onPickMonth,
  });

  final AppStore store;
  final int initialYear;
  final YearsJump jump;
  final ValueChanged<int> onTopYear;
  final void Function(DateTime month, Offset globalCenter) onPickMonth;

  @override
  State<YearsGrid> createState() => _YearsGridState();
}

class _YearsGridState extends State<YearsGrid> {
  static const _pad = 12.0;
  static const _gap = 8.0;
  static const _vGap = 12.0;
  static const _yearTitleH = 46.0;
  static const _monthTitleH = 20.0;

  ScrollController? _c;
  double _extent = 0;
  int _lastTop = -1;

  static int get _yearCount => calendarEndYear - calendarStartYear + 1;

  @override
  void initState() {
    super.initState();
    widget.jump.addListener(_onJump);
  }

  @override
  void dispose() {
    widget.jump.removeListener(_onJump);
    _c?.dispose();
    super.dispose();
  }

  int _colsFor(double w) => w >= 700 ? 4 : 3;

  double _cellW(double w, int cols) => (w - 2 * _pad - (cols - 1) * _gap) / cols;

  double _rowH(double cellW) => (cellW / 7).clamp(11.0, 26.0);

  double _extentFor(double w) {
    final cols = _colsFor(w);
    final rows = 12 ~/ cols;
    final monthH = _monthTitleH + 3 + 6 * _rowH(_cellW(w, cols));
    return _yearTitleH + rows * (monthH + _vGap) + 8;
  }

  int _yearAtOffset(double offset) {
    if (_extent <= 0) return widget.initialYear;
    final i = ((offset + _extent * 0.35) / _extent).floor().clamp(0, _yearCount - 1);
    return calendarStartYear + i;
  }

  void _onScroll() {
    final c = _c;
    if (c == null || !c.hasClients) return;
    final y = _yearAtOffset(c.offset);
    if (y == _lastTop) return;
    _lastTop = y;
    widget.onTopYear(y);
  }

  double _offsetOf(int year) => ((year - calendarStartYear).clamp(0, _yearCount - 1)) * _extent;

  void _onJump() {
    final c = _c;
    if (c == null || !c.hasClients) return;
    final target = _offsetOf(widget.jump.year).clamp(0.0, c.position.maxScrollExtent);
    c.animateTo(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        if (w <= 0) return const SizedBox.shrink();
        final ext = _extentFor(w);
        if (_c == null) {
          _extent = ext;
          _c = ScrollController(initialScrollOffset: _offsetOf(widget.initialYear))..addListener(_onScroll);
        } else if ((ext - _extent).abs() > 0.5) {
          final keep = _yearAtOffset(_c!.hasClients ? _c!.offset : 0);
          _extent = ext;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final c = _c;
            if (!mounted || c == null || !c.hasClients) return;
            c.jumpTo(_offsetOf(keep).clamp(0.0, c.position.maxScrollExtent));
          });
        }
        final cols = _colsFor(w);
        final cellW = _cellW(w, cols);
        final store = widget.store;
        final lang = store.lang;
        final today = DateTime.now();
        return ListView.builder(
          controller: _c,
          itemExtent: ext,
          itemCount: _yearCount,
          itemBuilder: (context, i) {
            final year = calendarStartYear + i;
            return _YearBlock(
              year: year,
              cols: cols,
              cellW: cellW,
              rowH: _rowH(cellW),
              lang: lang,
              weekStartsOn: store.weekStartsOn,
              today: today,
              onPickMonth: widget.onPickMonth,
            );
          },
        );
      },
    );
  }
}

class _YearBlock extends StatelessWidget {
  const _YearBlock({
    required this.year,
    required this.cols,
    required this.cellW,
    required this.rowH,
    required this.lang,
    required this.weekStartsOn,
    required this.today,
    required this.onPickMonth,
  });

  final int year;
  final int cols;
  final double cellW;
  final double rowH;
  final Lang lang;
  final int weekStartsOn;
  final DateTime today;
  final void Function(DateTime month, Offset globalCenter) onPickMonth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final red = dayToneColor(context, 'sunday');
    final isThisYear = today.year == year;
    final rows = 12 ~/ cols;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _YearsGridState._pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _YearsGridState._yearTitleH,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 2, top: 6),
                child: Text(
                  lang == Lang.en ? '$year' : khmerNum(year),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isThisYear ? red : cs.onSurface,
                      ),
                ),
              ),
            ),
          ),
          for (var r = 0; r < rows; r++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: _YearsGridState._gap),
                  SizedBox(
                    width: cellW,
                    child: _MiniMonth(
                      month: DateTime(year, r * cols + c + 1, 1),
                      rowH: rowH,
                      lang: lang,
                      weekStartsOn: weekStartsOn,
                      today: today,
                      onTap: onPickMonth,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: _YearsGridState._vGap),
          ],
        ],
      ),
    );
  }
}

final _monthMarkCache = <int, ({Set<int> publicDays, Set<int> holidayDays})>{};

({Set<int> publicDays, Set<int> holidayDays}) _monthHolidayMarks(DateTime month) {
  return _monthMarkCache[month.year * 12 + month.month - 1] ??= () {
    final pub = <int>{};
    final hol = <int>{};
    for (var d = 1; d <= daysInMonth(month); d++) {
      final iso = isoOf(DateTime(month.year, month.month, d));
      if (isPublicHoliday(iso)) {
        pub.add(d);
      } else if (isObservanceHoliday(iso)) {
        hol.add(d);
      }
    }
    return (publicDays: pub, holidayDays: hol);
  }();
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.month,
    required this.rowH,
    required this.lang,
    required this.weekStartsOn,
    required this.today,
    required this.onTap,
  });

  final DateTime month;
  final double rowH;
  final Lang lang;
  final int weekStartsOn;
  final DateTime today;
  final void Function(DateTime month, Offset globalCenter) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final red = dayToneColor(context, 'sunday');
    final isThisMonth = today.year == month.year && today.month == month.month;
    final firstOffset = (((DateTime(month.year, month.month, 1).weekday % 7) - weekStartsOn) + 7) % 7;
    final dayCount = daysInMonth(month);
    final marks = _monthHolidayMarks(month);
    final publicDays = marks.publicDays;
    final holidayDays = marks.holidayDays;
    final holidayColor = dayToneColor(context, 'holiday');
    final todayTone = isThisMonth
        ? (publicDays.contains(today.day) ? 'sunday' : holidayDays.contains(today.day) ? 'holiday' : 'default')
        : 'default';
    final todayStyle = todayColors(context, todayTone);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        final box = context.findRenderObject();
        final center = box is RenderBox && box.hasSize
            ? box.localToGlobal(box.size.center(Offset.zero))
            : Offset.zero;
        onTap(month, center);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _YearsGridState._monthTitleH,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  monthsOf(lang)[month.month - 1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isThisMonth ? red : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // One painter per month instead of ~42 Containers/Texts: far fewer widgets to build,
          // lay out and paint while scrolling the years grid.
          RepaintBoundary(
            child: CustomPaint(
              size: Size(double.infinity, rowH * 6),
              painter: _MiniGridPainter(
                firstOffset: firstOffset,
                days: dayCount,
                publicDays: publicDays,
                holidayDays: holidayDays,
                holidayColor: holidayColor,
                rowH: rowH,
                fontSize: (rowH * 0.62).clamp(8.0, 13.0),
                sunAt: sundayIndex(weekStartsOn),
                todayDay: isThisMonth ? today.day : -1,
                normal: cs.onSurface,
                red: red,
                fill: todayStyle.fill,
                onFill: todayStyle.onFill,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  const _MiniGridPainter({
    required this.firstOffset,
    required this.days,
    required this.publicDays,
    required this.holidayDays,
    required this.holidayColor,
    required this.rowH,
    required this.fontSize,
    required this.sunAt,
    required this.todayDay,
    required this.normal,
    required this.red,
    required this.fill,
    required this.onFill,
  });

  final int firstOffset;
  final int days;
  final Set<int> publicDays;
  final Set<int> holidayDays;
  final Color holidayColor;
  final double rowH;
  final double fontSize;
  final int sunAt;
  final int todayDay;
  final Color normal;
  final Color red;
  final Color fill;
  final Color onFill;

  // Day numbers repeat in every month, so each (number, colour, size, weight) is laid out once.
  static final _cache = <(int, int, double, bool), TextPainter>{};

  static TextPainter _label(int n, Color color, double size, bool bold) {
    if (_cache.length > 600) _cache.clear();
    return _cache[(n, color.toARGB32(), size, bold)] ??= TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(
          fontSize: size,
          height: 1.0,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colW = size.width / 7;
    final circle = Paint()..color = fill;
    for (var d = 1; d <= days; d++) {
      final idx = firstOffset + d - 1;
      final c = idx % 7;
      final center = Offset((c + 0.5) * colW, (idx ~/ 7 + 0.5) * rowH);
      final isToday = d == todayDay;
      if (isToday) canvas.drawCircle(center, rowH / 2, circle);
      final color = isToday
          ? onFill
          : publicDays.contains(d) || c == sunAt
              ? red
              : holidayDays.contains(d)
                  ? holidayColor
                  : normal;
      final tp = _label(d, color, fontSize, isToday);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter o) =>
      o.firstOffset != firstOffset ||
      o.days != days ||
      !setEquals(o.publicDays, publicDays) ||
      !setEquals(o.holidayDays, holidayDays) ||
      o.holidayColor != holidayColor ||
      o.rowH != rowH ||
      o.fontSize != fontSize ||
      o.sunAt != sunAt ||
      o.todayDay != todayDay ||
      o.normal != normal ||
      o.red != red ||
      o.fill != fill ||
      o.onFill != onFill;
}

// ---------------------------------------------------------------------------
// Weeks: one vertical scroll of weeks, one row per day with its holidays and tasks.
// ---------------------------------------------------------------------------

DateTime weekStartOf(DateTime d, int weekStartsOn) {
  final off = ((d.weekday % 7) - weekStartsOn + 7) % 7;
  return addDays(DateTime(d.year, d.month, d.day), -off);
}

DateTime _weekEpoch(int ws) => weekStartOf(DateTime(calendarStartYear, 1, 1), ws);

int weekIndexOf(DateTime d, int ws) {
  final e = _weekEpoch(ws);
  final a = DateTime.utc(e.year, e.month, e.day);
  final b = DateTime.utc(d.year, d.month, d.day);
  return b.difference(a).inDays ~/ 7;
}

DateTime weekFromIndex(int i, int ws) => addDays(_weekEpoch(ws), i * 7);

int weekCount(int ws) {
  final e = _weekEpoch(ws);
  final a = DateTime.utc(e.year, e.month, e.day);
  final b = DateTime.utc(calendarEndYear, 12, 31);
  return b.difference(a).inDays ~/ 7 + 1;
}

/// Weeks: one continuous vertical scroll. Every week block has a fixed height so the
/// scroll offset <-> week index maths stays O(1) over the whole calendar range.
const double _weekHeadH = 36;
const double _weekDayH = 112;
const double _weekBlockH = _weekHeadH + 7 * _weekDayH;

class WeekPager extends StatefulWidget {
  const WeekPager({super.key, required this.store, required this.onOpenObs});

  final AppStore store;
  final ValueChanged<Observance> onOpenObs;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  late ScrollController _c;
  late int _ws;
  late int _reported; // week index the store cursor currently points at because of us

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _ws = store.weekStartsOn;
    _reported = _cursorWeek();
    _c = ScrollController(initialScrollOffset: _reported * _weekBlockH)..addListener(_onScroll);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _cursorWeek() => weekIndexOf(fromIso(store.cursor), _ws).clamp(0, weekCount(_ws) - 1);

  void _onScroll() {
    if (!_c.hasClients) return;
    final top = ((_c.offset + _weekBlockH * 0.3) / _weekBlockH).floor().clamp(0, weekCount(_ws) - 1);
    if (top == _reported) return;
    _reported = top;
    final cur = fromIso(store.cursor);
    final dayOffset = ((cur.weekday % 7) - _ws + 7) % 7;
    store.setCursor(isoOf(addDays(weekFromIndex(top, _ws), dayOffset)));
  }

  void _jumpTo(int week) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_c.hasClients) return;
      _c.jumpTo((week * _weekBlockH).clamp(0.0, _c.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    // The week start setting changed: the index space moved, so re-anchor on the cursor.
    if (_ws != store.weekStartsOn) {
      _ws = store.weekStartsOn;
      _reported = _cursorWeek();
      _jumpTo(_reported);
    } else {
      // The cursor moved for another reason (Today button, date picker): follow it.
      final want = _cursorWeek();
      if (want != _reported) {
        _reported = want;
        _jumpTo(want);
      }
    }
    final ws = _ws;
    return ListView.builder(
      controller: _c,
      itemExtent: _weekBlockH,
      itemCount: weekCount(ws),
      itemBuilder: (context, i) => _WeekPage(
        start: weekFromIndex(i, ws),
        store: store,
        onOpenObs: widget.onOpenObs,
      ),
    );
  }
}

String _weekRange(DateTime a, DateTime b, Lang lang) {
  final m = monthsOf(lang);
  String n(int v) => lang == Lang.en ? '$v' : khmerNum(v);
  if (a.year != b.year) return '${n(a.day)} ${m[a.month - 1]} ${n(a.year)} – ${n(b.day)} ${m[b.month - 1]} ${n(b.year)}';
  if (a.month != b.month) return '${n(a.day)} ${m[a.month - 1]} – ${n(b.day)} ${m[b.month - 1]} ${n(b.year)}';
  return '${n(a.day)} – ${n(b.day)} ${m[a.month - 1]} ${n(b.year)}';
}

/// Observances for the 7 days from [start], taken from the per-month cache instead of
/// recomputing a range every time a week page rebuilds while swiping.
List<Observance> _weekObservances(DateTime start, List<CalendarEvent> events) {
  final end = addDays(start, 6);
  final lo = isoOf(start);
  final hi = isoOf(end);
  final out = <Observance>[];
  void take(DateTime month) {
    for (final o in monthObservances(month, events)) {
      if (o.kind == Kind.sil) continue;
      if (o.date.compareTo(lo) >= 0 && o.date.compareTo(hi) <= 0) out.add(o);
    }
  }

  take(start);
  if (!sameMonth(start, end)) take(end);
  return out;
}

class _WeekPage extends StatelessWidget {
  const _WeekPage({required this.start, required this.store, required this.onOpenObs});

  final DateTime start;
  final AppStore store;
  final ValueChanged<Observance> onOpenObs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = store.lang;
    final heads = weekdaysStarting(lang, store.weekStartsOn);
    var items = <Observance>[];
    try {
      items = _weekObservances(start, store.events);
    } catch (_) {}
    final byDay = <String, List<Observance>>{};
    for (final o in items) {
      byDay.putIfAbsent(o.date, () => []).add(o);
    }
    final isThisWeek = weekStartOf(DateTime.now(), store.weekStartsOn) == start;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Column(
        children: [
          SizedBox(
            height: _weekHeadH,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 8),
                child: Text(
                  _weekRange(start, addDays(start, 6), lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isThisWeek ? dayToneColor(context, 'sunday') : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < 7; i++)
            SizedBox(
              height: _weekDayH,
              child: _WeekDayRow(
                day: addDays(start, i),
                weekdayLabel: heads[i],
                items: byDay[isoOf(addDays(start, i))] ?? const [],
                minHeight: _weekDayH - 6,
                store: store,
                onOpenObs: onOpenObs,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.day,
    required this.weekdayLabel,
    required this.items,
    required this.minHeight,
    required this.store,
    required this.onOpenObs,
  });

  final DateTime day;
  final String weekdayLabel;
  final List<Observance> items;
  final double minHeight;
  final AppStore store;
  final ValueChanged<Observance> onOpenObs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = store.lang;
    final iso = isoOf(day);
    final isToday = iso == todayIso();
    final selected = iso == store.selected;
    final lunar = lunarOf(day);
    final toneId = dayTone(iso, true);
    final tone = dayToneColor(context, toneId);
    final todayStyle = isToday ? todayColors(context, toneId) : null;
    final lunarText = lang == Lang.en
        ? '${silPhaseLabel(lunar, lang)} · ${monthEn[lunar.khmerMonth] ?? lunar.khmerMonth}'
        : '${silPhaseLabel(lunar, lang)} ខែ${lunar.khmerMonth}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            store.goToDate(iso);
            store.setLastTab(TabId.today);
            context.go('/day');
          },
          child: Container(
            height: minHeight,
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected && !isToday ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekdayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: todayStyle != null ? BoxDecoration(color: todayStyle.fill, shape: BoxShape.circle) : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: todayStyle?.onFill ?? tone,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lunarText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ),
                          if (lunar.isSilDay) const SilMark(size: 14),
                        ],
                      ),
                      for (final o in items.length <= 2 ? items : items.take(1))
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: SizedBox(
                            height: 26,
                            child: _ObsChip(item: o, lang: lang, onTap: () => onOpenObs(o)),
                          ),
                        ),
                      if (items.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: SizedBox(
                            height: 26,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang == Lang.en ? '+${items.length - 1} more' : '+${khmerNum(items.length - 1)} ផ្សេងទៀត',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObsChip extends StatelessWidget {
  const _ObsChip({required this.item, required this.lang, required this.onTap});

  final Observance item;
  final Lang lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = dayToneColor(context, colorKind(item));
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  obsTitle(item, lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
