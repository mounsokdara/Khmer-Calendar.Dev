import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../home_screen.dart';
import '../i18n.dart';
import '../custom_components/slide_snackbar.dart';
import '../location.dart';
import '../reminders.dart';
import '../net.dart';
import '../permissions.dart';
import '../store.dart';
import '../widgets/segmented_list.dart';
import '../widgets/overlay_page.dart';
import '../widgets/package_downloads.dart';
import 'more.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.store});
  final AppStore store;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  static const _maxWidth = 560.0;
  static const _buttonWidth = 560.0;

  String step = 'language';
  bool notify = false;
  bool bg = false;
  bool auto = false;
  bool gps = false;
  bool busy = false;
  String asking = '';

  @override
  void initState() {
    super.initState();
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

  Future<void> _askNotify(bool v) async {
    final store = widget.store;
    if (!v) {
      setState(() => notify = false);
      store.setNotifyOn(false);
      await cancelAllReminders();
      await syncHomeWidget(store);
      return;
    }
    await requestNotifications(store);
    if (!mounted) return;
    if (!store.notifyOn) {
      if (await promptIfDenied(store, context: context, kind: 'notify', allowed: notificationsAllowed)) {
        if (!mounted) return;
        await requestNotifications(store);
      }
    }
    if (!mounted) return;
    setState(() => notify = store.notifyOn);
    showPermSnack(context, store.lang, 'notify', store.notifyOn);
  }

  Future<void> _askBg(bool v) async {
    final store = widget.store;
    if (!v) {
      setState(() => bg = false);
      await stopBackground(store);
      return;
    }
    if (kIsWeb) {
      setState(() => bg = false);
      if (mounted) {
        SlideSnackBar.show(context, message: t(store.lang, 'webBgBlock'), behavior: SnackBarBehavior.floating);
      }
      return;
    }
    await requestBackground(store, context: context);
    if (!mounted) return;
    if (!store.backgroundOn) {
      if (await promptIfDenied(store, context: context, kind: 'background', allowed: backgroundAllowed)) {
        if (!mounted) return;
        await requestBackground(store, context: context);
      }
    }
    if (!mounted) return;
    setState(() => bg = store.backgroundOn);
    showPermSnack(context, store.lang, 'background', store.backgroundOn);
  }

  Future<void> _askAuto(bool v) async {
    final store = widget.store;
    if (!v) {
      setState(() => auto = false);
      await stopAutoLaunch(store);
      return;
    }
    if (kIsWeb) {
      setState(() => auto = false);
      if (mounted) {
        SlideSnackBar.show(context, message: t(store.lang, 'webBgBlock'), behavior: SnackBarBehavior.floating);
      }
      return;
    }
    await requestAutoLaunch(store, context: context);
    if (!mounted) return;
    if (!store.autoLaunchOn && defaultTargetPlatform != TargetPlatform.android) {
      if (await promptIfDenied(store, context: context, kind: 'auto', allowed: autoLaunchAllowed)) {
        if (!mounted) return;
        await requestAutoLaunch(store, context: context);
      }
    }
    if (!mounted) return;
    setState(() => auto = store.autoLaunchOn);
    showPermSnack(context, store.lang, 'auto', store.autoLaunchOn);
  }

  Future<void> _askGps(bool v) async {
    final store = widget.store;
    if (!v) {
      setState(() => gps = false);
      store.setLocationOn(false);
      return;
    }
    final r = await requestLocationPerm(store);
    if (!mounted) return;
    if (!store.locationOn) {
      await promptIfDenied(store, context: context, kind: 'location', allowed: locationAllowed);
    }
    if (!mounted) return;
    setState(() => gps = store.locationOn);
    showGpsSnack(context, store.lang, store.locationOn ? r : GpsResult.denied);
  }

  Future<void> _continue() async {
    if (busy) return;
    final store = widget.store;
    setState(() {
      busy = true;
      asking = 'askingNotify';
    });
    final allOk = await requestAllPermissions(
      store,
      context: context,
      onStep: (key) {
        if (!mounted) return;
        setState(() {
          asking = key;
          notify = store.notifyOn;
          bg = store.backgroundOn;
          auto = store.autoLaunchOn;
          gps = store.locationOn;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      notify = store.notifyOn;
      bg = store.backgroundOn;
      auto = store.autoLaunchOn;
      gps = store.locationOn;
      busy = false;
      asking = '';
    });
    if (!allOk) return;
    store.setSetupDone(true);
    if (!mounted) return;
    context.go('/calendar');
  }

  Future<void> _skip() async {
    if (busy) return;
    final store = widget.store;
    setState(() => busy = true);
    await keepOnlyGranted(store);
    if (!mounted) return;
    store.setSetupDone(true);
    context.go('/calendar');
  }

  Widget _actionButton({required Widget child, required VoidCallback? onPressed, bool outlined = false}) {
    final button = outlined
        ? OutlinedButton(onPressed: onPressed, child: child)
        : FilledButton(onPressed: onPressed, child: child);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _buttonWidth),
        child: SizedBox(width: double.infinity, child: button),
      ),
    );
  }

  Widget _content(BuildContext context, Lang ui) {
    final store = widget.store;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t(ui, 'appName'), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (step == 'language') ...[
            Text(t(ui, 'languageTitle'), style: theme.textTheme.headlineSmall),
            Text(t(ui, 'welcome')),
            const SizedBox(height: 8),
            LangRadios(store: store, uiLang: ui),
            const Spacer(),
            _actionButton(
              onPressed: () => setState(() => step = kIsWeb ? 'install' : 'permissions'),
              child: Text(t(ui, 'setupNext')),
            ),
          ] else if (step == 'install') ...[
            Text(t(ui, 'setupInstallTitle'), style: theme.textTheme.headlineSmall),
            Text(t(ui, 'nativeAppSub')),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: NetStatus.online,
                builder: (context, online, _) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (kIsWeb)
                        SegmentedGroup(
                          padding: EdgeInsets.zero,
                          children: [
                            SegmentedTile(
                              leading: const Icon(Icons.install_mobile),
                              title: t(ui, 'exportBrowser'),
                              subtitle: t(ui, 'exportBrowserSub'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => openBrowserInstall(context, store: store, lang: ui),
                            ),
                          ],
                        ),
                      if (kIsWeb) const SizedBox(height: 10),
                      PackageDownloads(lang: ui, online: online, compact: true),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _actionButton(
              onPressed: () => setState(() => step = 'permissions'),
              child: Text(t(ui, 'setupNext')),
            ),
            const SizedBox(height: 6),
            _actionButton(
              onPressed: () => setState(() => step = 'permissions'),
              outlined: true,
              child: Text(t(ui, 'setupSkip')),
            ),
          ] else ...[
            Text(t(ui, 'setupPermTitle'), style: theme.textTheme.headlineSmall),
            Text(t(ui, 'setupPermSub')),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(t(ui, 'setupAllowNotify')),
                    subtitle: Text(t(ui, 'permNotifySub')),
                    value: notify,
                    onChanged: busy ? null : _askNotify,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: const Icon(Icons.sync),
                    title: Text(t(ui, 'setupAllowBackground')),
                    subtitle: Text(t(ui, 'permBackgroundSub')),
                    value: bg,
                    onChanged: busy ? null : _askBg,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: const Icon(Icons.rocket_launch_outlined),
                    title: Text(t(ui, 'setupAllowAutoLaunch')),
                    subtitle: Text(t(ui, 'autoLaunchSub')),
                    value: auto,
                    onChanged: busy ? null : _askAuto,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: const Icon(Icons.location_on_outlined),
                    title: Text(t(ui, 'setupAllowGps')),
                    subtitle: Text(t(ui, 'permLocationSub')),
                    value: gps,
                    onChanged: busy ? null : _askGps,
                  ),
                ],
              ),
            ),
            if (busy) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 8),
              Text(t(ui, asking.isEmpty ? 'loading' : asking), textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],
            _actionButton(
              onPressed: busy ? null : _continue,
              child: Text(t(ui, 'setupContinue')),
            ),
            const SizedBox(height: 6),
            _actionButton(
              onPressed: busy ? null : _skip,
              outlined: true,
              child: Text(t(ui, 'setupSkip')),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.store.lang;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Center(child: _content(context, ui)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
