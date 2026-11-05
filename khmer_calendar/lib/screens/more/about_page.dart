import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../web_refresh.dart';
import '../../widgets/overlay_page.dart';
import '../../widgets/about_widgets.dart';
import 'dev_update.dart' show inAppUpdateSupported;
import 'dev_update_ui.dart';
import 'update_checker.dart';

const _githubProfile = 'https://github.com/mounsokdara';
const _supportUrl = 'https://github.com/sponsors/mounsokdara';

class _GithubProfile {
  const _GithubProfile({required this.name, required this.bio, required this.avatar});
  final String name;
  final String bio;
  final String avatar;
}

_GithubProfile? _profileCache;

Future<_GithubProfile?> _loadProfile() async {
  if (_profileCache != null) return _profileCache;
  try {
    final r = await http.get(Uri.parse('https://api.github.com/users/mounsokdara')).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return _profileCache = _GithubProfile(
      name: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : (j['login'] as String? ?? appAuthor),
      bio: (j['bio'] as String?) ?? '',
      avatar: (j['avatar_url'] as String?) ?? 'https://github.com/mounsokdara.png',
    );
  } catch (_) {
    return null;
  }
}

Widget _githubIcon({required Color color, double size = 28}) {
  return SvgPicture.asset(
    'assets/icons/github.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.km});
  final bool km;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/icons/icon-512.png', width: 64, height: 64, filterQuality: FilterQuality.medium),
        ),
        const SizedBox(height: 16),
        Text(km ? 'ប្រតិទិនខ្មែរ' : 'Khmer Calendar', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          km ? 'ប្រតិទិនចន្ទគតិខ្មែរ សម្រាប់ទូរស័ព្ទ និងកុំព្យូទ័រ' : 'Khmer lunar calendar for phone and desktop.',
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.km, required this.onOpen});
  final bool km;
  final VoidCallback onOpen;

  static const _avatarSize = 112.0;

  Widget _avatar(ColorScheme cs, String? url, String letter) {
    Widget fallback() => Container(
          width: _avatarSize,
          height: _avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Text(letter, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: cs.onPrimary)),
        );
    if (url == null) return fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: _avatarSize,
        height: _avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
        loadingBuilder: (_, child, p) => p == null ? child : fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: SizedBox(
          width: double.infinity,
          child: FutureBuilder<_GithubProfile?>(
            future: _loadProfile(),
            builder: (context, snap) {
              final p = snap.data;
              final name = p?.name ?? appAuthor;
              return Column(children: [
                _avatar(cs, p?.avatar, name.isEmpty ? '?' : name[0].toUpperCase()),
                const SizedBox(height: 16),
                Text(name, textAlign: TextAlign.center, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  km ? 'អ្នកអភិវឌ្ឍន៍ចម្បង' : 'Lead Developer',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(Uri.parse(_supportUrl), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: Text(km ? 'គាំទ្រការងាររបស់ខ្ញុំ' : 'Support my work'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: km ? 'ទំព័រ GitHub' : 'GitHub profile',
                    iconSize: 28,
                    onPressed: onOpen,
                    icon: _githubIcon(color: cs.onSurface),
                  ),
                ]),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) {
        final lang = store.lang;
        final km = lang == Lang.km;
        final isFdroid = const bool.fromEnvironment('FDROID');
        final cs = Theme.of(context).colorScheme;
        void open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return OverlayScaffold(
          title: t(lang, 'aboutTitle'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Hero(km: km),
                      const SizedBox(height: 12),
                      AboutQuickActions(items: [
                        QuickAction(
                          icon: Icons.history,
                          label: km ? 'កំណត់ត្រាការផ្លាស់ប្តូរ' : 'Changelog',
                          onTap: () => context.push('/changelog'),
                        ),
                        QuickAction(
                          iconWidget: _githubIcon(color: cs.onSurface),
                          label: 'GitHub',
                          onTap: () => open(appSourceUrl),
                        ),
                        // F-Droid builds (--dart-define=FDROID=true) update through F-Droid, not GitHub.
                        if (!isFdroid)
                          QuickAction(
                            icon: Icons.system_update_outlined,
                            label: km ? 'ពិនិត្យកំណែថ្មី' : 'Check For Update',
                            onTap: () => _checkForUpdate(context, lang),
                          ),
                        QuickAction(
                          icon: Icons.bug_report_outlined,
                          label: km ? 'បញ្ហា' : 'Issues',
                          onTap: () => open('$appSourceUrl/issues'),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          km ? 'អ្នកបង្កើត' : 'Author',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _AuthorCard(km: km, onOpen: () => open(_githubProfile)),
                      const SizedBox(height: 12),
                      AboutGroup(items: [
                        AboutItem(
                          icon: Icons.info_outline,
                          title: km ? 'កំណែ' : 'Version',
                          subtitle: 'v$appVersion ($appBuildNumber)',
                          chevron: false,
                        ),
                        AboutItem(
                          icon: Icons.language,
                          title: t(lang, 'website'),
                          subtitle: appWebsiteUrl,
                          link: true,
                          onTap: () => open(appWebsiteUrl),
                        ),
                        AboutItem(
                          icon: Icons.description_outlined,
                          title: t(lang, 'openSourceLicense'),
                          subtitle: t(lang, 'mitLicense'),
                          onTap: () => context.push('/license'),
                        ),
                        AboutItem(
                          icon: Icons.privacy_tip_outlined,
                          title: km ? 'គោលការណ៍ឯកជនភាព' : 'Privacy policy',
                          subtitle: km ? 'ទិន្នន័យអ្វីដែលកម្មវិធីប្រើ' : 'What data the app uses',
                          onTap: () => context.push('/privacy-policy'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _checkForUpdate(BuildContext context, Lang lang) async {
  if (!context.mounted) return;
  // Android / desktop: download + install the package for the version.txt tag inside the app, no browser.
  if (inAppUpdateSupported) return runInAppUpdateCheck(context, lang);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          const SizedBox(width: 16),
          Text(lang == Lang.km ? 'កំពុងពិនិត្យកំណែថ្មី…' : 'Checking for updates…'),
        ],
      ),
    ),
  );

  UpdateInfo? update;
  String? error;
  try {
    update = kIsWeb ? await checkForWebUpdate() : await checkForAppUpdate();
  } on services.PlatformException {
    error = lang == Lang.km ? 'មិនអាចពិនិត្យកំណែថ្មីបានទេ។' : 'Unable to check for updates.';
  } catch (_) {
    error = lang == Lang.km ? 'មិនអាចពិនិត្យកំណែថ្មីបានទេ។' : 'Unable to check for updates.';
  }

  if (context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;

  if (error != null) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(lang == Lang.km ? 'ពិនិត្យកំណែថ្មី' : 'Check for updates'),
        content: Text(error!),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(lang == Lang.km ? 'យល់ព្រម' : 'OK'))],
      ),
    );
    return;
  }

  if (update == null) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(lang == Lang.km ? 'កំណែថ្មី' : 'Updates'),
        content: Text(lang == Lang.km ? 'កម្មវិធីរបស់អ្នកជាកំណែថ្មីបំផុត។' : 'You are using the latest version.'),
        actions: [
          if (kIsWeb)
            TextButton(
              onPressed: () => cleanAndReloadWeb(),
              child: Text(lang == Lang.km ? 'សម្អាត និងទាញយកថ្មី' : 'Clean & reload'),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: Text(lang == Lang.km ? 'យល់ព្រម' : 'OK')),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(lang == Lang.km ? 'មានកំណែថ្មី' : 'Update available'),
      content: Text(
        kIsWeb
            ? (lang == Lang.km
                ? 'មានកំណែ ${update!.version}។ ការធ្វើបច្ចុប្បន្នភាពនឹងសម្អាតឯកសារដែលបានរក្សាទុក ហើយទាញយកថ្មីម្តងទៀត។ ការកំណត់របស់អ្នកនៅដដែល។'
                : 'Version ${update!.version} is available. Updating clears cached files and downloads the latest assets and scripts again. Your settings are kept.')
            : lang == Lang.km
                ? 'មានកំណែ ${update!.version}។ កំណែបច្ចុប្បន្នគឺ $currentAppVersion។'
                : 'Version ${update!.version} is available. You are using $currentAppVersion.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(lang == Lang.km ? 'បិទ' : 'Close')),
        FilledButton(
          onPressed: () async {
            if (kIsWeb) {
              await cleanAndReloadWeb();
              return;
            }
            await openLatestRelease(update!.url);
            if (d.mounted) Navigator.pop(d);
          },
          child: Text(
            kIsWeb
                ? (lang == Lang.km ? 'ធ្វើបច្ចុប្បន្នភាព' : 'Update now')
                : (lang == Lang.km ? 'មើលកំណែថ្មី' : 'View update'),
          ),
        ),
      ],
    ),
  );
}
