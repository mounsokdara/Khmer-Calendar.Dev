import 'package:flutter/material.dart';

import '../calendar/observances.dart';
import '../dates.dart';
import '../i18n.dart';
import '../theme.dart';


class ObsRow extends StatelessWidget {
  const ObsRow({
    super.key,
    required this.item,
    required this.lang,
    required this.onTap,
    this.active = false,
    this.showWeekday = false,
    this.padDay = false,
  });

  final Observance item;
  final Lang lang;
  final VoidCallback onTap;
  final bool active;
  final bool showWeekday;
  final bool padDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = fromIso(item.date);
    final tone = colorKind(item);
    final num = padDay ? d.day.toString().padLeft(2, '0') : '${d.day}';
    return Material(
      color: active ? cs.surfaceContainerLow : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  num,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dayToneColor(context, tone),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (showWeekday) ...[
                SizedBox(
                  width: 72,
                  child: Text(
                    weekdaysFull(lang)[d.weekday % 7],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  obsTitle(item, lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count', style: const TextStyle(fontSize: 15)),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
