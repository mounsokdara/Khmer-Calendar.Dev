import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../custom_components/slide_snackbar.dart';
import '../i18n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/overlay_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;

  static const tabs = [
    (TabId.today, '/day', Icons.today, 'navToday'),
    (TabId.calendar, '/calendar', Icons.calendar_month, 'navCalendar'),
    (TabId.events, '/events', Icons.event_note, 'navEvents'),
    (TabId.weather, '/weather', Icons.wb_cloudy, 'navWeather'),
    (TabId.more, '/more', Icons.menu, 'navMore'),
  ];

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) => _ShellBody(store: store, child: child),
    );
  }
}

class _ShellBody extends StatefulWidget {
  const _ShellBody({required this.store, required this.child});
  final AppStore store;
  final Widget child;

  @override
  State<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends State<_ShellBody> {
  // The snackbar host and the page inside it sit in a different spot of the tree
  // for the wide (rail) and narrow (bottom bar) layouts. A GlobalKey lets Flutter
  // move the same state across a rotate/resize instead of recreating it, which
  // used to wipe the visible snackbar (and reset the page) every time the window
  // crossed the breakpoint.
  final _hostKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final child = widget.child;
    final host = SlideSnackBarHost(key: _hostKey, child: child);
    final loc = GoRouterState.of(context).uri.path;
    var idx = AppShell.tabs.indexWhere((t) => loc == t.$2 || loc.startsWith('${t.$2}/'));
    if (idx < 0) idx = 1;
    final wide = MediaQuery.sizeOf(context).width >= wideBreak;

    void go(int i) {
      store.setLastTab(AppShell.tabs[i].$1);
      context.go(AppShell.tabs[i].$2);
    }

    if (wide) {
      // Titles stay under the icons; the rail scrolls if a very short window can't fit all five.
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: idx,
                        onDestinationSelected: go,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final tab in AppShell.tabs)
                            NavigationRailDestination(
                              icon: Icon(tab.$3),
                              selectedIcon: Icon(tab.$3),
                              label: Text(t(store.lang, tab.$4)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: host),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarStyle(theme, theme.colorScheme.surfaceContainer),
      child: Scaffold(
      body: SafeArea(
        child: host,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: go,
        destinations: [
          for (final tab in AppShell.tabs)
            NavigationDestination(
              icon: Icon(tab.$3),
              selectedIcon: Icon(tab.$3),
              label: t(store.lang, tab.$4),
            ),
        ],
      ),
    ));
  }
}
