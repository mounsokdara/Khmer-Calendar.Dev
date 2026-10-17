import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../calendar/chhankitek.dart';
import '../calendar/observances.dart';
import '../dates.dart';
import '../i18n.dart';
import '../store.dart';
import '../widgets/stroke_text.dart';
import '../theme.dart';
import '../widgets/carousel_slider.dart';
import '../widgets/holiday_info.dart';
import '../widgets/obs_row.dart';
import '../widgets/overlay_page.dart';
import '../widgets/sil_mark.dart';
import '../widgets/task_sheet.dart';
import '../widgets/wheel_picker.dart';

class MonthsPage extends StatefulWidget {
  const MonthsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<MonthsPage> createState() => _MonthsPageState();
}

class _MonthsPageState extends State<MonthsPage> {
  bool _expanded = false;

  AppStore get store => widget.store;

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
        final selected = store.selected;
        final items = monthObservances(cursor, store.events).where((i) => i.kind != Kind.sil).toList();
        final holidays = items.where((i) => i.kind != Kind.event).toList();
        final tasks = items.where((i) => i.kind == Kind.event).toList();
        final today = todayIso();
        final wide = MediaQuery.sizeOf(context).width >= wideBreak && !_expanded;

        return Column(
          children: [
            _header(lang, cursor, today),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _monthBlock(cursor, fill: true)),
                        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width >= xlBreak ? 400 : 360,
                          child: SingleChildScrollView(child: _sideList(lang, holidays, tasks, selected)),
                        ),
                      ],
                    )
                  : _expanded
                      ? _monthBlock(cursor, fill: true)
                      : ListView(
                          children: [
                            _monthBlock(cursor, fill: false),
                            _sideList(lang, holidays, tasks, selected),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(Lang lang, DateTime cursor, String today) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
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
                        style: Theme.of(context).textTheme.titleLarge,
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
              if (!sameMonth(cursor, fromIso(today)))
                IconButton(
                  tooltip: t(lang, 'today'),
                  onPressed: () => store.goToDate(today),
                  icon: const Icon(Icons.today),
                ),
              IconButton(
                tooltip: _expanded ? t(lang, 'collapse') : t(lang, 'expand'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.close_fullscreen : Icons.open_in_full),
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

  Widget _slide(DateTime cursor, {required bool fill}) {
    return CarouselSlider(
      index: monthIndexOf(cursor),
      itemCount: monthCount(),
      itemBuilder: (context, i) {
        final month = monthFromIndex(i);
        return _MonthGrid(
          month: month,
          store: store,
          interactive: true,
          expanded: _expanded,
        );
      },
      onIndexChanged: (i) {
        final next = monthFromIndex(i);
        final day = cursor.day.clamp(1, daysInMonth(next));
        store.setCursor(isoOf(DateTime(next.year, next.month, day)));
      },
    );
  }

  Widget _monthBlock(DateTime cursor, {required bool fill}) {
    final lang = store.lang;
    final track = fill
        ? Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: ClipRect(clipBehavior: Clip.hardEdge, child: _slide(cursor, fill: true)),
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
                  child: ClipRect(clipBehavior: Clip.hardEdge, child: _slide(cursor, fill: false)),
                );
              },
            ),
          );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_expanded) _lunarLine(cursor, lang),
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
    final chips = interactive ? monthObservances(month, store.events).where((i) => i.kind != Kind.sil).toList() : const <Observance>[];

    Widget cellAt(int i) {
      final d = gridDays[i];
      return _DayCell(
        day: d,
        inMonth: sameMonth(d, month),
        selected: isoOf(d) == store.selected,
        isToday: isoOf(d) == today,
        store: store,
        interactive: interactive,
        expanded: expanded,
        chips: expanded ? chips.where((c) => c.date == isoOf(d)).take(3).toList() : const [],
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
