import 'dart:ui' show PlatformDispatcher;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'haptics.dart';
import 'home_screen.dart';
import 'i18n.dart';
import 'net.dart';
import 'permissions.dart';
import 'screens/events.dart';
import 'screens/licenses.dart';
import 'screens/more.dart';
import 'screens/more/privacy_policy_page.dart';
import 'screens/calendar.dart';
import 'screens/setup.dart';
import 'screens/shell.dart';
import 'screens/splash.dart';
import 'screens/today.dart';
import 'screens/weather_page.dart';
import 'store.dart';
import 'widgets/stroke_text.dart';
import 'theme.dart';

final store = AppStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  IntlHelper.localeName = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  await Future.wait([NetStatus.start(), Haptics.instance.init()]);
  runApp(KhmerCalendarApp(store: store));
  store.hydrate().then((_) => applyStoredPermissions(store));
}

class KhmerCalendarApp extends StatefulWidget {
  const KhmerCalendarApp({super.key, required this.store});
  final AppStore store;

  @override
  State<KhmerCalendarApp> createState() => _KhmerCalendarAppState();
}

class _KhmerCalendarAppState extends State<KhmerCalendarApp> {
  late final GoRouter router;
  String _visualSig = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    final launchRoute = PlatformDispatcher.instance.defaultRouteName;
    if (launchRoute.startsWith('/') && launchRoute != '/' && launchRoute != '/splash') {
      widget.store.pendingRoute = launchRoute;
    }
    router = GoRouter(
      refreshListenable: widget.store.routerTick,
      initialLocation: '/splash',
      redirect: (ctx, state) {
        if (!widget.store.hydrated) return '/splash';
        if (!widget.store.setupDone && state.uri.path != '/get-started') return '/get-started';
        if (widget.store.setupDone) {
          final pending = widget.store.takePendingRoute();
          if (pending != null) return pending;
        }
        if (widget.store.setupDone && (state.uri.path == '/get-started' || state.uri.path == '/splash' || state.uri.path == '/')) {
          switch (widget.store.lastTab) {
            case TabId.today:
              return '/day';
            case TabId.events:
              return '/events';
            case TabId.weather:
              return '/weather';
            case TabId.more:
              return '/more';
            case TabId.calendar:
              return '/calendar';
          }
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => SplashPage(store: widget.store)),
        GoRoute(path: '/get-started', builder: (_, _) => SetupPage(store: widget.store)),
        ShellRoute(
          builder: (ctx, state, child) => AppShell(store: widget.store, child: child),
          routes: [
            GoRoute(path: '/day', builder: (_, _) => TodayPage(store: widget.store)),
            GoRoute(path: '/calendar', builder: (_, _) => CalendarPage(store: widget.store)),
            GoRoute(path: '/events', builder: (_, _) => EventsPage(store: widget.store)),
            GoRoute(path: '/weather', builder: (_, _) => WeatherPage(store: widget.store)),
            GoRoute(path: '/more', builder: (_, _) => MorePage(store: widget.store)),
          ],
        ),
        GoRoute(path: '/settings', builder: (_, _) => SettingsPage(store: widget.store)),
        GoRoute(path: '/settings/theme', builder: (_, _) => ThemePage(store: widget.store)),
        GoRoute(path: '/settings/notifications', builder: (_, _) => NotificationsPage(store: widget.store)),
        GoRoute(path: '/settings/sounds', builder: (_, _) => SoundsPage(store: widget.store)),
        GoRoute(path: '/settings/privacy', builder: (_, _) => PrivacyPage(store: widget.store)),
        GoRoute(path: '/settings/clear', builder: (_, _) => ClearPage(store: widget.store)),
        GoRoute(path: '/about', builder: (_, _) => AboutPage(store: widget.store)),
        GoRoute(path: '/privacy-policy', builder: (_, _) => PrivacyPolicyPage(store: widget.store)),
        GoRoute(
          path: '/license',
          builder: (_, _) => OssLicensePage(store: widget.store),
          routes: [
            GoRoute(path: 'app', builder: (_, _) => AppMitLicensePage(store: widget.store)),
            GoRoute(
              path: 'pkg/:name',
              builder: (_, state) => PackageLicensePage(
                store: widget.store,
                package: Uri.decodeComponent(state.pathParameters['name'] ?? ''),
              ),
            ),
          ],
        ),
        GoRoute(path: '/tools', builder: (_, _) => ToolsPage(store: widget.store)),
        GoRoute(path: '/tools/datecalculator', builder: (_, _) => DateCalcPage(store: widget.store)),
        GoRoute(path: '/download', builder: (_, _) => DownloadPage(store: widget.store)),
      ],
    );
  }

  void _onStore() {
    final s = widget.store;
    final sig =
        '${s.theme}|${s.colorScheme}|${s.materialYou}|${s.dynamicColor}|${s.extraDark}|${s.accentColor}|${s.highlightColor}|${s.highlightAlpha}|${s.lang}|${s.hydrated}|${s.setupDone}';
    if (sig == _visualSig) return;
    _visualSig = sig;
    setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  ThemeData _theme(Brightness brightness, {required bool extraDark, ColorScheme? dynamicScheme}) {
    final s = widget.store;
    return buildTheme(
      brightness: brightness,
      scheme: s.colorScheme,
      extraDark: extraDark,
      materialYou: s.materialYou,
      dynamicColor: s.dynamicColor,
      accentColor: s.accentColor,
      highlightColor: s.highlightColor,
      highlightAlpha: s.highlightAlpha,
      dynamicScheme: s.dynamicColor ? dynamicScheme : null,
    ).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          maximumSize: const Size(360, 48),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          maximumSize: const Size(360, 48),
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          maximumSize: const Size(360, 48),
          minimumSize: const Size(0, 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = _theme(Brightness.light, extraDark: false, dynamicScheme: lightDynamic);
        final darkTheme = _theme(Brightness.dark, extraDark: s.extraDark, dynamicScheme: darkDynamic);
        syncWidgetTheme(s, lightTheme.colorScheme, darkTheme.colorScheme);
        return MaterialApp.router(
          title: s.lang == Lang.en ? 'Khmer Calendar' : 'ប្រតិទិនខ្មែរ',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _AppScrollBehavior(),
          locale: Locale(s.lang == Lang.en ? 'en' : 'km'),
          supportedLocales: const [Locale('km'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: s.theme == 'light' ? ThemeMode.light : s.theme == 'dark' ? ThemeMode.dark : ThemeMode.system,
          routerConfig: router,
          builder: (context, child) {
            StrokeText.enabled = widget.store.textStroke;
            return AnnotatedRegion<SystemUiOverlayStyle>(
            value: systemBarStyle(Theme.of(context), Theme.of(context).colorScheme.surface),
            child: child ?? const SizedBox.shrink(),
          );
          },
        );
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
