import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/overlay_page.dart';
import '../../widgets/segmented_list.dart';
import 'update_checker.dart';

const _githubProfile = 'https://github.com/mounsokdara';

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

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.km, required this.onOpen});
  final bool km;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<_GithubProfile?>(
      future: _loadProfile(),
      builder: (context, snap) {
        final p = snap.data;
        final name = p?.name ?? appAuthor;
        final letter = Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.onPrimary)),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: p == null
                        ? letter
                        : Image.network(p.avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => letter),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('@mounsokdara', style: TextStyle(color: cs.onSurfaceVariant)),
                      if (p != null && p.bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(p.bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Label(km ? 'អ្នកអភិវឌ្ឍន៍ចម្បង' : 'Main developer', icon: Icons.code),
                          _Label(km ? 'អ្នកអភិវឌ្ឍន៍ឯករាជ្យ' : 'Solo open source dev', icon: Icons.volunteer_activism_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('GitHub'),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, this.subtitle, required this.child});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 22, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: cs.onSecondaryContainer), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.external = true});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(external ? Icons.open_in_new : Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
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
        final cs = Theme.of(context).colorScheme;
        const gap = SizedBox(height: 16);
        final isFdroid = const bool.fromEnvironment('FDROID');
        void open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return OverlayScaffold(
          title: t(lang, 'aboutTitle'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset('assets/icons/icon-512.png', width: 72, height: 72),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t(lang, 'appName'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  Text(km ? 'ប្រតិទិនចន្ទគតិខ្មែរ' : 'Khmer lunar calendar', style: TextStyle(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _Label('v$appVersion ($appBuildNumber)', icon: Icons.tag),
                                      _Label(km ? 'ប្រភពបើកចំហ' : 'Open source', icon: Icons.code),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      gap,
                      _Section(
                        icon: Icons.person_outline,
                        title: t(lang, 'createdBy'),
                        child: _AuthorCard(km: km, onOpen: () => open(_githubProfile)),
                      ),
                      gap,
                      _Section(
                        icon: Icons.apps,
                        title: km ? 'កម្មវិធីនេះ' : 'This app',
                        subtitle: km ? 'កូដ គេហទំព័រ និងកំណែ' : 'Source, website and updates',
                        child: SegmentedGroup(
                          padding: EdgeInsets.zero,
                          filled: false,
                          children: [
                            _LinkRow(icon: Icons.code, title: t(lang, 'sourceCode'), subtitle: appSourceUrl, onTap: () => open(appSourceUrl)),
                            _LinkRow(icon: Icons.language, title: t(lang, 'website'), subtitle: appWebsiteUrl, onTap: () => open(appWebsiteUrl)),
                            // F-Droid builds (--dart-define=FDROID=true) update through F-Droid, not GitHub.
                            if (!isFdroid)
                              _LinkRow(
                                icon: Icons.system_update_outlined,
                                title: km ? 'ពិនិត្យកំណែថ្មី' : 'Check for updates',
                                subtitle: km ? 'ពិនិត្យកំណែថ្មីពី GitHub' : 'Check GitHub for a newer release',
                                external: false,
                                onTap: () => _checkForUpdate(context, lang),
                              ),
                          ],
                        ),
                      ),
                      gap,
                      _Section(
                        icon: Icons.gavel_outlined,
                        title: km ? 'ច្បាប់' : 'Legal',
                        subtitle: km ? 'អាជ្ញាបណ្ណ និងឯកជនភាព' : 'Licenses and privacy',
                        child: SegmentedGroup(
                          padding: EdgeInsets.zero,
                          filled: false,
                          children: [
                            _LinkRow(
                              icon: Icons.description_outlined,
                              title: t(lang, 'openSourceLicense'),
                              subtitle: t(lang, 'mitLicense'),
                              external: false,
                              onTap: () => context.push('/license'),
                            ),
                            _LinkRow(
                              icon: Icons.privacy_tip_outlined,
                              title: km ? 'គោលការណ៍ឯកជនភាព' : 'Privacy policy',
                              subtitle: km ? 'ទិន្នន័យអ្វីដែលកម្មវិធីប្រើ' : 'What data the app uses',
                              external: false,
                              onTap: () => context.push('/privacy-policy'),
                            ),
                          ],
                        ),
                      ),
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
    update = await checkForAppUpdate();
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
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(lang == Lang.km ? 'យល់ព្រម' : 'OK'))],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(lang == Lang.km ? 'មានកំណែថ្មី' : 'Update available'),
      content: Text(
        lang == Lang.km
            ? 'មានកំណែ ${update!.version}។ កំណែបច្ចុប្បន្នគឺ $currentAppVersion។'
            : 'Version ${update!.version} is available. You are using $currentAppVersion.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(lang == Lang.km ? 'បិទ' : 'Close')),
        FilledButton(
          onPressed: () async {
            await openLatestRelease(update!.url);
            if (d.mounted) Navigator.pop(d);
          },
          child: Text(lang == Lang.km ? 'មើលកំណែថ្មី' : 'View update'),
        ),
      ],
    ),
  );
}
