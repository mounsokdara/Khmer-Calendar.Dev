import 'dart:async';

import 'package:flutter/material.dart';

import '../../custom_components/slide_snackbar.dart';
import '../../home_screen.dart' show syncWeatherWidget;
import '../../i18n.dart';
import '../../storage_stats.dart';
import '../../store.dart';
import '../../widgets/dialog_actions.dart';
import '../../widgets/overlay_page.dart';
import '../../widgets/segmented_list.dart';

class ClearPage extends StatefulWidget {
  const ClearPage({super.key, required this.store});
  final AppStore store;

  @override
  State<ClearPage> createState() => _ClearPageState();
}

class _ClearPageState extends State<ClearPage> {
  /// Null until the first measurement has finished.
  StorageStats? _stats;
  bool _busy = false;

  AppStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final stats = await loadStorageStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<bool> _ask(Lang lang, String titleKey, {String? detail}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(lang, titleKey)),
        content: detail == null ? null : Text(detail),
        actions: equalDialogActions([
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: dialogBtnStyle(),
            child: dlgLabel(t(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: dialogBtnStyle(),
            child: dlgLabel(t(lang, 'ok')),
          ),
        ]),
      ),
    );
    return ok == true;
  }

  /// Shows a spinner while [job] runs, for at least a moment, so it is visible that something is
  /// being cleared.
  Future<void> _withProgress(Lang lang, String messageKey, Future<void> Function() job) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 20),
                Expanded(child: Text(t(lang, messageKey))),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await Future.wait<void>([job(), Future<void>.delayed(const Duration(milliseconds: 700))]);
    } catch (_) {
      // The page re-measures afterwards, so it shows what is really left.
    } finally {
      navigator.pop();
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    SlideSnackBar.show(context, message: message, behavior: SnackBarBehavior.floating);
  }

  Future<void> _finish(Lang lang, {String? message}) async {
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(message ?? t(lang, 'clearDone'));
  }

  Future<void> _clearCache(Lang lang) async {
    final size = _stats?.cacheBytes ?? 0;
    final detail = t(lang, 'confirmClearCacheSize').replaceAll('{size}', formatBytes(size, lang));
    if (!await _ask(lang, 'confirmClearCache', detail: detail) || !mounted) return;
    setState(() => _busy = true);
    var freed = 0;
    await _withProgress(lang, 'clearingCache', () async {
      freed = await clearAppCache();
    });
    await _finish(
      lang,
      message: freed > 0 ? t(lang, 'clearedSize').replaceAll('{size}', formatBytes(freed, lang)) : t(lang, 'cacheEmpty'),
    );
    // The Android weather widget reads the icons and photos that were just removed: fetch them again.
    unawaited(syncWeatherWidget(_store));
  }

  Future<void> _clearReminders(Lang lang) async {
    final detail = t(lang, 'confirmClearRemindersN').replaceAll('{n}', formatCount(reminderCount(_store), lang));
    if (!await _ask(lang, 'confirmClearReminders', detail: detail) || !mounted) return;
    setState(() => _busy = true);
    await _withProgress(lang, 'clearing', () async {
      _store.clearEventReminders();
      await _store.persist();
    });
    await _finish(lang);
  }

  Future<void> _clearWeather(Lang lang) async {
    final detail = t(lang, 'confirmClearWeatherN').replaceAll('{n}', formatCount(_store.weatherCities.length, lang));
    if (!await _ask(lang, 'confirmClearWeather', detail: detail) || !mounted) return;
    setState(() => _busy = true);
    await _withProgress(lang, 'clearing', () async {
      _store.resetWeatherCities();
      await _store.persist();
    });
    await _finish(lang);
  }

  Future<void> _clearAll(Lang lang) async {
    if (!await _ask(lang, 'confirmClearAll') || !mounted) return;
    setState(() => _busy = true);
    await _withProgress(lang, 'clearing', () async {
      _store.resetAppData();
      await clearAppCache();
      await _store.persist();
    });
    await _finish(lang);
  }

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: _store,
      builder: (context, store) {
        final lang = store.lang;
        final cs = Theme.of(context).colorScheme;
        final stats = _stats;
        final reminders = reminderCount(store);
        final cities = store.weatherCities.length;
        final measuring = stats == null;
        final cacheEmpty = stats != null && stats.cacheBytes == 0;
        final valueStyle = TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);

        return OverlayScaffold(
          title: t(lang, 'clearTitle'),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _StorageSummary(
                lang: lang,
                stats: stats,
                events: store.events.length,
                reminders: reminders,
                cities: cities,
              ),
              const SizedBox(height: 16),
              SegmentedGroup(
                children: [
                  SegmentedTile(
                    leading: const Icon(Icons.cached),
                    title: t(lang, 'clearCache'),
                    subtitle: measuring
                        ? t(lang, 'storageMeasuring')
                        : (cacheEmpty ? t(lang, 'cacheEmpty') : t(lang, 'clearCacheSub')),
                    trailing: measuring || cacheEmpty ? null : Text(formatBytes(stats.cacheBytes, lang), style: valueStyle),
                    dim: measuring || cacheEmpty,
                    onTap: _busy || measuring || cacheEmpty ? null : () => _clearCache(lang),
                  ),
                  SegmentedTile(
                    leading: const Icon(Icons.alarm_off),
                    title: t(lang, 'clearReminders'),
                    subtitle: reminders == 0 ? t(lang, 'remindersEmpty') : t(lang, 'clearRemindersSub'),
                    trailing: reminders == 0 ? null : Text(formatCount(reminders, lang), style: valueStyle),
                    dim: reminders == 0,
                    onTap: _busy || reminders == 0 ? null : () => _clearReminders(lang),
                  ),
                  SegmentedTile(
                    leading: const Icon(Icons.cloud_off),
                    title: t(lang, 'clearWeather'),
                    subtitle: cities == 0 ? t(lang, 'weatherEmpty') : t(lang, 'clearWeatherSub'),
                    trailing: cities == 0 ? null : Text(formatCount(cities, lang), style: valueStyle),
                    dim: cities == 0,
                    onTap: _busy || cities == 0 ? null : () => _clearWeather(lang),
                  ),
                  SegmentedTile(
                    leading: Icon(Icons.delete_forever, color: cs.error),
                    title: t(lang, 'clearAll'),
                    subtitle: t(lang, 'clearAllSub'),
                    danger: true,
                    onTap: _busy ? null : () => _clearAll(lang),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Three numbers at the top: how much the app saved, how many reminders are set, how big the cache is.
class _StorageSummary extends StatelessWidget {
  const _StorageSummary({
    required this.lang,
    required this.stats,
    required this.events,
    required this.reminders,
    required this.cities,
  });

  final Lang lang;
  final StorageStats? stats;
  final int events;
  final int reminders;
  final int cities;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = stats;
    final dataDetail = '${t(lang, 'storageEvents').replaceAll('{n}', formatCount(events, lang))}'
        ' · ${t(lang, 'storageCities').replaceAll('{n}', formatCount(cities, lang))}';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Icons.storage_rounded,
                          color: cs.primary,
                          label: t(lang, 'storageData'),
                          detail: dataDetail,
                          value: _CountUp(value: s?.dataBytes, format: (v) => formatBytes(v, lang)),
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          icon: Icons.alarm_rounded,
                          color: cs.tertiary,
                          label: t(lang, 'storageReminders'),
                          detail: t(lang, 'storageOfEvents').replaceAll('{n}', formatCount(events, lang)),
                          value: _CountUp(value: reminders, format: (v) => formatCount(v, lang)),
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          icon: Icons.cached_rounded,
                          color: cs.secondary,
                          label: t(lang, 'storageCache'),
                          detail: t(lang, 'storageRemovable'),
                          value: _CountUp(value: s?.cacheBytes, format: (v) => formatBytes(v, lang)),
                        ),
                      ),
                    ],
                  ),
                  if (s != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${t(lang, 'storageTotal')}: ${formatBytes(s.totalBytes, lang)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: value),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A number that rolls to its new value, so clearing visibly drains the figure instead of just
/// swapping it.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.format});

  final int? value;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final v = value;
    if (v == null) return Text('—', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: v.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, x, child) => Text(format(x.round()), style: style, maxLines: 1),
    );
  }
}
