import 'package:flutter/material.dart';

import '../calendar/chhankitek.dart';
import '../calendar/observances.dart';
import '../dates.dart';
import '../i18n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/holiday_info.dart';
import '../widgets/obs_row.dart';
import '../widgets/overlay_page.dart';
import '../widgets/segmented_list.dart';
import '../widgets/sil_mark.dart';
import '../widgets/swipe_delete.dart';
import '../widgets/task_sheet.dart';
import '../widgets/wheel_picker.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) => _EventsBody(store: store),
    );
  }
}

class _EventFilter {
  const _EventFilter(this.id, this.labelKey, this.icon);
  final String id;
  final String labelKey;
  final IconData? icon;
}

const _eventFilters = [
  _EventFilter('all', 'filterAll', Icons.apps_rounded),
  _EventFilter('holiday', 'filterHoliday', Icons.flag_rounded),
  _EventFilter('other', 'filterOtherHoliday', Icons.celebration_rounded),
  _EventFilter('task', 'filterTask', Icons.task_alt_rounded),
  _EventFilter('sil', 'silDay', null),
];

String _filterOf(String stored) {
  if (stored == 'tasks') return 'task';
  if (stored == 'holidays') return 'all';
  return _eventFilters.any((f) => f.id == stored) ? stored : 'all';
}

class _EventsBody extends StatefulWidget {
  const _EventsBody({required this.store});
  final AppStore store;

  @override
  State<_EventsBody> createState() => _EventsBodyState();
}

class _EventsBodyState extends State<_EventsBody> {
  static const _centerKey = Key('events-center');

  AppStore get store => widget.store;
  late int _anchor = fromIso(widget.store.cursor).year;
  late final ValueNotifier<int> _visible = ValueNotifier<int>(_anchor);
  final _marks = <int, _YearMarkState>{};
  String _lastFilter = '';
  String _cacheFilter = '';
  List<CalendarEvent>? _cacheEvents;
  final _cache = <int, Map<String, List<Observance>>>{};

  @override
  void dispose() {
    _visible.dispose();
    super.dispose();
  }

  void _syncYear(BuildContext scrollContext) {
    final box = scrollContext.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    int? above;
    var aboveY = -double.infinity;
    int? below;
    var belowY = double.infinity;
    for (final e in _marks.entries) {
      final rb = e.value.context.findRenderObject();
      if (rb is! RenderBox || !rb.attached || !rb.hasSize) continue;
      final y = rb.localToGlobal(Offset.zero).dy;
      if (y <= top + 1) {
        if (y > aboveY) {
          aboveY = y;
          above = e.key;
        }
      } else if (y < belowY) {
        belowY = y;
        below = e.key;
      }
    }
    final year = above ?? (below == null ? null : (below > calendarStartYear ? below - 1 : below));
    if (year != null && year != _visible.value) _visible.value = year;
  }

  Map<String, List<Observance>> _yearGroups(String filter, int year) {
    if (_cacheFilter != filter || !identical(_cacheEvents, store.events)) {
      _cache.clear();
      _cacheFilter = filter;
      _cacheEvents = store.events;
    }
    return _cache[year] ??= () {
      final groups = <String, List<Observance>>{};
      for (final o in yearObservances(year, store.events)) {
        final keep = switch (filter) {
          'holiday' => o.kind == Kind.holiday && o.holidayType == HolidayType.public,
          'other' => o.kind == Kind.holiday && o.holidayType != HolidayType.public,
          'sil' => o.kind == Kind.sil,
          _ => true,
        };
        if (keep) groups.putIfAbsent(o.date.substring(0, 7), () => []).add(o);
      }
      return groups;
    }();
  }

  void _openObs(BuildContext context, Observance item) {
    store.goToDate(item.date);
    if (item.kind == Kind.event && item.eventId != null) {
      final ev = store.events.where((e) => e.id == item.eventId).firstOrNull;
      if (ev != null) showTaskSheet(context, store: store, editing: ev);
      return;
    }
    showHolidayInfo(context, store, item);
  }

  Widget _filterBar(BuildContext context, String filter) {
    final lang = store.lang;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _eventFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _eventFilters[i];
          return ChoiceChip(
            showCheckmark: false,
            avatar: f.icon == null ? const SilMark(size: 18) : Icon(f.icon, size: 18),
            label: Text(t(lang, f.labelKey)),
            selected: filter == f.id,
            onSelected: (_) => store.setLastEventsPane(f.id),
          );
        },
      ),
    );
  }

  Widget _yearBlock(BuildContext context, int year, String filter, bool wide, bool xl) {
    final lang = store.lang;
    final cs = Theme.of(context).colorScheme;
    final groups = _yearGroups(filter, year);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _YearMark(
          year: year,
          registry: _marks,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Text('$year', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Text(t(lang, 'noItemsYear'), style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else if (xl)
          _holidayGrid(context, groups, 3)
        else if (wide)
          _holidayGrid(context, groups, 2)
        else
          for (final e in groups.entries) _holidayGroup(context, e.key, e.value),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = store.lang;
    final filter = _filterOf(store.lastEventsPane);
    final isTask = filter == 'task';
    if (_lastFilter != filter) {
      _lastFilter = filter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _visible.value = _anchor;
      });
    }
    final today = todayIso();
    final current = store.events.where((e) => e.done != true && (e.date.isEmpty || e.date.compareTo(today) >= 0)).toList();
    final overdue = store.events.where((e) => e.done != true && e.date.isNotEmpty && e.date.compareTo(today) < 0).toList();
    final done = store.events.where((e) => e.done == true).toList();
    final wide = MediaQuery.sizeOf(context).width >= mediumBreak;
    final xl = MediaQuery.sizeOf(context).width >= xlBreak;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(t(lang, 'events'), style: Theme.of(context).textTheme.headlineSmall)),
              if (!isTask)
                ValueListenableBuilder<int>(
                  valueListenable: _visible,
                  builder: (_, year, _) => TextButton.icon(
                    onPressed: () async {
                      final pick = await showYearWheel(context, lang: lang, year: year);
                      if (pick == null || !mounted) return;
                      final cur = fromIso(store.cursor);
                      setState(() => _anchor = pick);
                      _visible.value = pick;
                      store.setCursor(isoOf(DateTime(pick, cur.month, 1)));
                    },
                    icon: const Icon(Icons.expand_more),
                    label: Text('$year'),
                  ),
                ),
              if (isTask || filter == 'all')
                IconButton(
                  tooltip: t(lang, 'addTask'),
                  onPressed: () => showTaskSheet(context, store: store),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        _filterBar(context, filter),
        const SizedBox(height: 4),
        Expanded(
          child: !isTask
              ? NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    final ctx = n.context;
                    if (ctx != null && n.depth == 0 && (n is ScrollUpdateNotification || n is ScrollEndNotification)) {
                      _syncYear(ctx);
                    }
                    return false;
                  },
                  child: CustomScrollView(
                  key: ValueKey('$filter-$_anchor'),
                  center: _centerKey,
                  slivers: [
                    SliverList.builder(
                      itemCount: _anchor - calendarStartYear,
                      itemBuilder: (c, i) => _yearBlock(c, _anchor - 1 - i, filter, wide, xl),
                    ),
                    SliverList.builder(
                      key: _centerKey,
                      itemCount: calendarEndYear - _anchor + 1,
                      itemBuilder: (c, i) => _yearBlock(c, _anchor + i, filter, wide, xl),
                    ),
                  ],
                ))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _taskGroup(context, t(lang, 'overdue'), overdue, true),
                    _taskGroup(context, t(lang, 'currentTasks'), current, false),
                    _taskGroup(context, t(lang, 'completed'), done, false),
                    if (store.events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(t(lang, 'noTasks')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _holidayGrid(BuildContext context, Map<String, List<Observance>> groups, int cols) {
    final entries = groups.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          for (var r = 0; r < (entries.length / cols).ceil(); r++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++)
                  Expanded(
                    child: r * cols + c < entries.length
                        ? _holidayGroup(context, entries[r * cols + c].key, entries[r * cols + c].value)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _holidayGroup(BuildContext context, String key, List<Observance> list) {
    final lang = store.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
          child: Text(
            formatMonthTitle(fromIso('$key-01'), lang),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        for (final item in list)
          ObsRow(
            item: item,
            lang: lang,
            showWeekday: true,
            padDay: true,
            onTap: () => _openObs(context, item),
          ),
      ],
    );
  }

  Widget _taskGroup(BuildContext context, String title, List<CalendarEvent> list, bool overdue) {
    if (list.isEmpty) return const SizedBox.shrink();
    final lang = store.lang;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title, color: overdue ? cs.error : cs.primary),
        for (final e in list)
          swipeToDelete(
            context: context,
            key: e.id,
            confirm: true,
            lang: lang,
            onDelete: () => store.deleteEvent(e.id),
            child: ListTile(
              leading: Checkbox(value: e.done ?? false, onChanged: (_) => store.toggleEventDone(e.id)),
              title: Text(e.title, style: TextStyle(decoration: e.done == true ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold)),
              subtitle: Text(eventWhenLabel(e.date, e.startTime, e.allDay, lang)),
              onTap: () => showTaskSheet(context, store: store, editing: e),
            ),
          ),
      ],
    );
  }
}

class _YearMark extends StatefulWidget {
  const _YearMark({required this.year, required this.registry, required this.child});
  final int year;
  final Map<int, _YearMarkState> registry;
  final Widget child;

  @override
  State<_YearMark> createState() => _YearMarkState();
}

class _YearMarkState extends State<_YearMark> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.year] = this;
  }

  @override
  void didUpdateWidget(_YearMark old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) {
      if (identical(old.registry[old.year], this)) old.registry.remove(old.year);
      widget.registry[widget.year] = this;
    }
  }

  @override
  void dispose() {
    if (identical(widget.registry[widget.year], this)) widget.registry.remove(widget.year);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
