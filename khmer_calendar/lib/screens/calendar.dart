import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../calendar/chhankitek.dart';
import '../calendar/observances.dart';
import '../dates.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../store.dart';
import '../widgets/stroke_text.dart';
import '../theme.dart';
import '../widgets/carousel_slider.dart';
import '../widgets/holiday_info.dart';
import '../widgets/obs_row.dart';
import '../widgets/overlay_page.dart';
import '../widgets/pinch_zoom.dart';
import '../widgets/sil_mark.dart';
import '../widgets/task_sheet.dart';
import '../widgets/wheel_picker.dart';
import '../widgets/zoom_switcher.dart';
import 'calendar_views.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store});
  final AppStore store;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _yearsJump = YearsJump();
  late final ValueNotifier<int> _topYear = ValueNotifier<int>(fromIso(widget.store.cursor).year);
  final _bodyKey = GlobalKey();
  String _returnView = 'month';
  String _lastView = '';
  bool _zoomIn = true;
  Alignment _focus = Alignment.center;
  final _zoom = ZoomController();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _yearsJump.dispose();
    _topYear.dispose();
    super.dispose();
  }

  /// Converts a global point into an alignment inside the calendar body, so the zoom
  /// transition can grow from where the user pinched or tapped.
  Alignment _alignFor(Offset? global) {
    final box = _bodyKey.currentContext?.findRenderObject();
    if (global == null || box is! RenderBox || !box.hasSize || box.size.isEmpty) return Alignment.center;
    final p = box.globalToLocal(global);
    final s = box.size;
    return Alignment(
      (p.dx / s.width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
      (p.dy / s.height * 2 - 1).clamp(-1.0, 1.0).toDouble(),
    );
  }

  void _setView(String v, {Offset? focal}) {
    if (v == store.calView) return;
    _focus = _alignFor(focal);
    if (v == 'years') {
      _returnView = store.calView == 'monthFull' ? 'monthFull' : 'month';
      _topYear.value = fromIso(store.cursor).year;
    }
    Haptics.instance.tick();
    store.setCalView(v);
  }

  void _pickMonth(DateTime m, Offset focal) {
    _focus = _alignFor(focal);
    final now = DateTime.now();
    final cur = fromIso(store.cursor);
    final day = (m.year == now.year && m.month == now.month) ? now.day : cur.day.clamp(1, daysInMonth(m));
    store.setCursor(isoOf(DateTime(m.year, m.month, day)));
    Haptics.instance.tick();
    store.setCalView(_returnView);
  }

  void _openObs(Observance item) {
    store.goToDate(item.date);
    if (item.kind == Kind.event && item.eventId != null) {
      final ev = store.events.where((e) => e.id == item.eventId).firstOrNull;
      if (ev != null) showTaskSheet(context, store: store, editing: ev);
      return;
    }
    showHolidayInfo(context, store, item);
  }

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: widget.store,
      builder: (context, store) {
        final lang = store.lang;
        final cursor = fromIso(store.cursor);
        final today = todayIso();
        final view = store.calView;

        // Direction of the view change, for the zoom transition.
        var zoomIn = _zoomIn;
        final focus = _focus;
        if (view != _lastView) {
          if (_lastView.isNotEmpty) zoomIn = calViewIds.indexOf(view) > calViewIds.indexOf(_lastView);
          _zoomIn = zoomIn;
          _lastView = view;
          _focus = Alignment.center; // consumed by this transition
        }

        Widget monthBody(String v) {
          final selected = store.selected;
          final items = monthObservances(cursor, store.events).where((i) => i.kind != Kind.sil).toList();
          final holidays = items.where((i) => i.kind != Kind.event).toList();
          final tasks = items.where((i) => i.kind == Kind.event).toList();
          final wide = MediaQuery.sizeOf(context).width >= wideBreak && v == 'month';
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _monthBlock(cursor, fill: true, full: false)),
                VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width >= xlBreak ? 400 : 360,
                  child: SingleChildScrollView(child: _sideList(lang, holidays, tasks, selected)),
                ),
              ],
            );
          }
          if (v == 'monthFull') return _monthBlock(cursor, fill: true, full: true);
          return ListView(
            children: [
              _monthBlock(cursor, fill: false, full: false),
              _sideList(lang, holidays, tasks, selected),
            ],
          );
        }

        Widget bodyFor(String v) => switch (v) {
              'years' => YearsGrid(
                  store: store,
                  initialYear: cursor.year,
                  jump: _yearsJump,
                  onTopYear: (y) => _topYear.value = y,
                  onPickMonth: _pickMonth,
                ),
              'week' => WeekPager(store: store, onOpenObs: _openObs),
              _ => monthBody(v),
            };

        final viewIndex = calViewIds.indexOf(view);
        ({String key, Widget child})? peek(int steps) {
          final j = viewIndex + steps;
          if (j < 0 || j >= calViewIds.length) return null;
          return (key: calViewIds[j], child: bodyFor(calViewIds[j]));
        }

        return PinchZoom(
          onStart: _zoom.start,
          onUpdate: _zoom.update,
          onEnd: _zoom.end,
          child: Column(
            children: [
              _header(lang, cursor, today, view),
              Expanded(
                child: ZoomSwitcher(
                  key: _bodyKey,
                  viewKey: view,
                  zoomIn: zoomIn,
                  focus: focus,
                  controller: _zoom,
                  peek: peek,
                  levelsOut: viewIndex,
                  levelsIn: calViewIds.length - 1 - viewIndex,
                  onCommit: _setView,
                  onLimit: Haptics.instance.thud,
                  child: bodyFor(view),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Lang lang, DateTime cursor, String today, String view) {
    final isYears = view == 'years';
    final now = fromIso(today);
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return ValueListenableBuilder<int>(
      valueListenable: _topYear,
      builder: (context, topYear, _) {
        final ws = store.weekStartsOn;
        final showToday = isYears
            ? topYear != now.year
            : view == 'week'
                ? weekIndexOf(cursor, ws) != weekIndexOf(now, ws)
                : !sameMonth(cursor, now);
        return SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isYears
                      ? TextButton(
                          onPressed: () async {
                            final y = await showYearWheel(
                              context,
                              lang: lang,
                              year: topYear,
                              title: lang == Lang.km ? 'ជ្រើសរើសឆ្នាំ' : 'Select year',
                            );
                            if (y == null || !mounted) return;
                            _topYear.value = y;
                            _yearsJump.to(y);
                          },
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(lang == Lang.en ? '$topYear' : khmerNum(topYear), style: titleStyle),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        )
                      : TextButton(
                          onPressed: () => showMonthWheel(context, store: store),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  formatMonthTitle(cursor, lang),
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showToday)
                    IconButton(
                      tooltip: t(lang, 'today'),
                      onPressed: () {
                        if (isYears) {
                          store.goToDate(today);
                          _yearsJump.to(now.year);
                        } else {
                          store.goToDate(today);
                        }
                      },
                      icon: const Icon(Icons.today),
                    ),
                  // Follows the pinch live: shows the level the view is nearest to, not only the
                  // one that was committed when the fingers lift.
                  ValueListenableBuilder<int?>(
                    valueListenable: _zoom.liveStep,
                    builder: (context, step, _) {
                      final i = calViewIds.indexOf(view);
                      final live = step == null || i < 0
                          ? view
                          : calViewIds[(i + step).clamp(0, calViewIds.length - 1).toInt()];
                      return _viewMenu(lang, live);
                    },
                  ),
                  IconButton(
                    tooltip: t(lang, 'addTask'),
                    onPressed: () => showTaskSheet(context, store: store, date: store.selected),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _viewMenu(Lang lang, String view) {
    const options = [
      ('years', Icons.apps, 'viewYears'),
      ('month', Icons.calendar_month, 'viewMonth'),
      ('monthFull', Icons.fullscreen, 'viewMonthFull'),
      ('week', Icons.view_week, 'viewWeek'),
    ];
    return PopupMenuButton<String>(
      tooltip: t(lang, 'viewGrids'),
      icon: const Icon(Icons.grid_view),
      initialValue: view,
      onSelected: _setView,
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.$1,
            child: Row(
              children: [
                Icon(o.$2, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(t(lang, o.$3))),
                if (view == o.$1) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lunarLine(DateTime cursor, Lang lang) {
    final shown = cursor.day.clamp(1, daysInMonth(cursor));
    final d = DateTime(cursor.year, cursor.month, shown);
    final lunar = lunarOf(d);
    final cs = Theme.of(context).colorScheme;
    final lunarText = lang == Lang.en ? lunarLabel(isoOf(d), lang) : lunar.lunarDateText;
    final gregText = lang == Lang.en ? gregorianLabel(d, lang) : lunar.gregorianDateText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(lunarText, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.35)),
          ),
          const SizedBox(width: 12),
          Text(gregText, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _weekdays(Lang lang) {
    final heads = weekdaysStarting(lang, store.weekStartsOn);
    final sunAt = sundayIndex(store.weekStartsOn);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < heads.length; i++)
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    heads[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == sunAt ? const Color(0xFFC62828) : cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slide(DateTime cursor, {required bool fill, required bool full}) {
    return CarouselSlider(
      index: monthIndexOf(cursor),
      itemCount: monthCount(),
      itemBuilder: (context, i) {
        final month = monthFromIndex(i);
        return _MonthGrid(
          month: month,
          store: store,
          interactive: true,
          expanded: full,
        );
      },
      onIndexChanged: (i) {
        final next = monthFromIndex(i);
        final day = cursor.day.clamp(1, daysInMonth(next));
        store.setCursor(isoOf(DateTime(next.year, next.month, day)));
      },
    );
  }

  Widget _monthBlock(DateTime cursor, {required bool fill, required bool full}) {
    final lang = store.lang;
    final track = fill
        ? Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: ClipRect(clipBehavior: Clip.hardEdge, child: _slide(cursor, fill: true, full: full)),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: LayoutBuilder(
              builder: (ctx, box) {
                final w = box.maxWidth;
                if (w <= 0) return const SizedBox.shrink();
                final cell = w / 7;
                final rowH = (cell / 0.88).clamp(44.0, 72.0);
                return SizedBox(
                  width: w,
                  height: rowH * 6,
                  child: ClipRect(clipBehavior: Clip.hardEdge, child: _slide(cursor, fill: false, full: full)),
                );
              },
            ),
          );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!full) _lunarLine(cursor, lang),
        _weekdays(lang),
        track,
      ],
    );
    return body;
  }

  Widget _sideList(Lang lang, List<Observance> holidays, List<Observance> tasks, String selected) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(child: Text(t(lang, 'events'), style: Theme.of(context).textTheme.titleMedium)),
              CountChip(
                count: holidays.length,
                onTap: () {
                  store.setLastTab(TabId.events);
                  store.setLastEventsPane('holidays');
                  context.go('/events');
                },
              ),
            ],
          ),
        ),
        if (holidays.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Text(t(lang, 'noHolidaysMonth'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          )
        else
          for (final item in holidays)
            ObsRow(
              item: item,
              lang: lang,
              active: item.date == selected,
              onTap: () => _openObs(item),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(child: Text(t(lang, 'tasks'), style: Theme.of(context).textTheme.titleMedium)),
              CountChip(
                count: tasks.length,
                onTap: () {
                  store.setLastTab(TabId.events);
                  store.setLastEventsPane('tasks');
                  context.go('/events');
                },
              ),
            ],
          ),
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Text(t(lang, 'noTasksMonth'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          )
        else
          for (final item in tasks)
            ObsRow(
              item: item,
              lang: lang,
              active: item.date == selected,
              onTap: () => _openObs(item),
            ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.store,
    required this.interactive,
    required this.expanded,
  });
  final DateTime month;
  final AppStore store;
  final bool interactive;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final gridDays = monthGrid(month, store.weekStartsOn);
    final today = todayIso();
    // Event chips are only drawn in the expanded layout, so don't build the
    // month's observance list at all otherwise.
    final chips = (interactive && expanded)
        ? monthObservances(month, store.events).where((i) => i.kind != Kind.sil).toList()
        : const <Observance>[];
    final selectedIso = store.selected;

    Widget cellAt(int i) {
      final d = gridDays[i];
      final iso = isoOf(d);
      return _DayCell(
        day: d,
        inMonth: sameMonth(d, month),
        selected: iso == selectedIso,
        isToday: iso == today,
        store: store,
        interactive: interactive,
        expanded: expanded,
        chips: expanded ? chips.where((c) => c.date == iso).take(3).toList() : const [],
      );
    }

    return Column(
      children: [
        for (var r = 0; r < 6; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: cellAt(r * 7 + c)),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.isToday,
    required this.store,
    required this.interactive,
    required this.expanded,
    required this.chips,
  });
  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final AppStore store;
  final bool interactive;
  final bool expanded;
  final List<Observance> chips;

  @override
  Widget build(BuildContext context) {
    final iso = isoOf(day);
    final tone = dayTone(iso, inMonth);
    final mark = hasDayMark(iso, store.events);
    final lunar = lunarOf(day);
    final cs = Theme.of(context).colorScheme;
    final color = dayToneColor(context, tone);
    final todayStyle = isToday ? todayColors(context, tone) : null;
    final fill = todayStyle?.fill ?? Colors.transparent;
    final onFill = todayStyle?.onFill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !interactive
            ? null
            : () {
                store.goToDate(iso);
                store.setLastTab(TabId.today);
                context.go('/day');
              },
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: selected && !isToday ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (lunar.isSilDay && inMonth)
                  const Positioned(
                    top: 3,
                    right: 3,
                    child: SilMark(size: 13),
                  ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          StrokeText(
                            lunar.moonDayKhmer,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onFill?.withValues(alpha: 0.78) ?? cs.onSurfaceVariant,
                              fontSize: 10,
                              height: 1.1,
                            ),
                          ),
                          StrokeText(
                            '${day.day}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onFill ?? color,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              height: 1.25,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (!expanded)
                            StrokeText(
                              lunar.khmerMonth,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onFill?.withValues(alpha: 0.78) ?? cs.onSurfaceVariant,
                                fontSize: 8,
                                height: 1.2,
                              ),
                            )
                          else
                            for (final c in chips)
                              Container(
                                width: 64,
                                margin: const EdgeInsets.only(top: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                color: dayToneColor(context, colorKind(c)).withValues(alpha: 0.18),
                                child: Text(
                                  obsTitle(c, store.lang),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 8, color: dayToneColor(context, colorKind(c))),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!expanded && mark)
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                      ),
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
