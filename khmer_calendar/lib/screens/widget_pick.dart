import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../widgets/wheel_picker.dart';

const _channel = MethodChannel('khmer.permissions');

/// Floating month/year picker opened from the month widget (a transparent, non-launchable
/// Android activity). Shows the app's scroll picker over the home screen, tells the widget which
/// month was chosen, then closes itself.
class WidgetPickPage extends StatefulWidget {
  const WidgetPickPage({
    super.key,
    required this.store,
    required this.widgetId,
    required this.year,
    required this.month,
  });

  final AppStore store;
  final int widgetId;
  final int year;
  final int month;

  @override
  State<WidgetPickPage> createState() => _WidgetPickPageState();
}

class _WidgetPickPageState extends State<WidgetPickPage> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_maybeOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpen());
  }

  @override
  void dispose() {
    widget.store.removeListener(_maybeOpen);
    super.dispose();
  }

  void _maybeOpen() {
    if (_opened || !mounted || !widget.store.hydrated) return;
    _opened = true;
    _open();
  }

  Future<void> _open() async {
    final picked = await pickMonthYearWheel(
      context,
      lang: widget.store.lang,
      year: widget.year,
      month: widget.month,
    );
    if (picked != null) {
      try {
        await _channel.invokeMethod<dynamic>('setWidgetMonth', {
          'id': widget.widgetId,
          'year': picked.year,
          'month': picked.month,
        });
      } catch (_) {}
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.transparent);
}
