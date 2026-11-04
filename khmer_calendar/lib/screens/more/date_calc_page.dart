import 'package:flutter/material.dart';

import '../../calendar/chhankitek.dart';
import '../../calendar/observances.dart';
import '../../dates.dart';
import '../../i18n.dart';
import '../../store.dart';
import '../../widgets/overlay_page.dart';

class DateCalcPage extends StatefulWidget {
  const DateCalcPage({super.key, required this.store});
  final AppStore store;

  @override
  State<DateCalcPage> createState() => _DateCalcPageState();
}

class _DateCalcPageState extends State<DateCalcPage> {
  late String from;
  late String to;
  String shift = '7';

  @override
  void initState() {
    super.initState();
    from = todayIso();
    to = todayIso();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: widget.store,
      builder: (context, store) {
        final lang = store.lang;
        final a = fromIso(from);
        final b = fromIso(to);
        final days = b.difference(a).inDays;
        final years = days.abs() ~/ 365;
        final months = (days.abs() % 365) ~/ 30;
        final rest = days.abs() - years * 365 - months * 30;
        final lunarFrom = lunarOf(a);
        final lunarTo = lunarOf(b);
        final shifted = isoOf(addDays(a, int.tryParse(shift) ?? 0));
        final shiftedLunar = lunarOf(fromIso(shifted));
        final cs = Theme.of(context).colorScheme;

        return OverlayScaffold(
          title: t(lang, 'calcTitle'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t(lang, 'calcSub')),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            child: ListTile(
              title: Text(t(lang, 'calcFrom')),
              subtitle: Text(from),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: a, firstDate: DateTime(calendarStartYear), lastDate: DateTime(calendarEndYear, 12, 31));
                if (p != null) setState(() => from = isoOf(p));
              },
            ),
          ),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(t(lang, 'calcTo')),
              subtitle: Text(to),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final p = await showDatePicker(context: context, initialDate: b, firstDate: DateTime(calendarStartYear), lastDate: DateTime(calendarEndYear, 12, 31));
                if (p != null) setState(() => to = isoOf(p));
              },
            ),
          ),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(lang, 'calcDuration')),
                  Text('$years ${t(lang, 'calcYears')} · $months ${t(lang, 'calcMonths')} · $rest ${t(lang, 'calcDays')}', style: Theme.of(context).textTheme.titleLarge),
                  Text('$days ${t(lang, 'calcTotalDays')}${days < 0 ? ' · ${t(lang, 'calcPast')}' : ''}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: ListTile(
              title: Text(t(lang, 'calcFrom')),
              subtitle: Text(lang == Lang.en ? '${lunarLabel(from, lang)}\n${gregorianLabel(a, lang)}' : '${lunarFrom.lunarDateText}\n${lunarFrom.gregorianDateText}'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: ListTile(
              title: Text(t(lang, 'calcTo')),
              subtitle: Text(lang == Lang.en ? '${lunarLabel(to, lang)}\n${gregorianLabel(b, lang)}' : '${lunarTo.lunarDateText}\n${lunarTo.gregorianDateText}'),
            ),
          ),
          const SizedBox(height: 8),
          Text(t(lang, 'calcAdd')),
          Wrap(
            spacing: 8,
            children: [
              for (final n in ['7', '15', '30'])
                ChoiceChip(label: Text('+$n'), selected: shift == n, onSelected: (_) => setState(() => shift = n)),
            ],
          ),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '+'),
            onChanged: (v) => setState(() => shift = v),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: ListTile(
              title: Text(shifted),
              subtitle: Text(lang == Lang.en ? lunarLabel(shifted, lang) : shiftedLunar.lunarDateText),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}
