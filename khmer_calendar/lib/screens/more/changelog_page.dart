import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../store.dart';
import '../../widgets/overlay_page.dart';
import 'release_notes.dart';

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key, required this.store});
  final AppStore store;

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  ReleaseFeed? _feed;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    final feed = await ReleaseNotes.load(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _feed = feed;
      _loading = false;
    });
  }

  String _date(DateTime? d, bool km) {
    if (d == null) return '';
    final l = d.toLocal();
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const kh = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
    return km ? '${l.day} ${kh[l.month - 1]} ${l.year}' : '${en[l.month - 1]} ${l.day}, ${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: widget.store,
      builder: (context, store) {
        final km = store.lang == Lang.km;
        final cs = Theme.of(context).colorScheme;
        final feed = _feed;
        final releases = feed?.releases ?? const <ReleaseNote>[];
        Widget body;
        if (_loading && feed == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (releases.isEmpty) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  (feed?.failed ?? false)
                      ? (km ? 'មិនអាចទាញយកកំណត់ចេញផ្សាយបានទេ។' : 'Release notes are not available right now.')
                      : (km ? 'មិនទាន់មានកំណែចេញផ្សាយទេ។' : 'No releases published yet.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _open(releasesPageUrl),
                  child: Text(km ? 'បើកនៅ GitHub' : 'Open on GitHub'),
                ),
              ]),
            ),
          );
        } else {
          body = RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (feed != null && (feed.failed || feed.fromCache))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      feed.failed
                          ? (km ? 'គ្មានអ៊ីនធឺណិត - បង្ហាញច្បាប់ចម្លងដែលបានរក្សាទុក។' : 'No connection - showing the saved copy.')
                          : (km ? 'បង្ហាញច្បាប់ចម្លងដែលបានរក្សាទុក។' : 'Showing the saved copy.'),
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                for (final r in releases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReleaseCard(note: r, date: _date(r.publishedAt, km), km: km),
                  ),
              ],
            ),
          );
        }
        return OverlayScaffold(
          title: km ? 'កំណត់ត្រាការផ្លាស់ប្តូរ' : 'Changelog',
          actions: [
            IconButton(
              tooltip: km ? 'ផ្ទុកឡើងវិញ' : 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _load(refresh: true),
            ),
          ],
          body: body,
        );
      },
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.note, required this.date, required this.km});
  final ReleaseNote note;
  final String date;
  final bool km;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lines = plainNotes(note.body).split('\n');
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(note.url),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(note.title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              if (note.prerelease)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    km ? 'មុនចេញផ្សាយ' : 'Pre-release',
                    style: TextStyle(fontSize: 11, color: cs.onTertiaryContainer),
                  ),
                ),
            ]),
            if (date.isNotEmpty) Text(date, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (note.body.isEmpty)
              Text(km ? 'គ្មានកំណត់ចេញផ្សាយ។' : 'No release notes.', style: TextStyle(color: cs.onSurfaceVariant))
            else
              for (final raw in lines) _line(context, raw),
          ]),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String raw) {
    final cs = Theme.of(context).colorScheme;
    final line = raw.trimRight();
    if (line.trim().isEmpty) return const SizedBox(height: 6);
    final heading = RegExp(r'^\s*#{1,6}\s+(.*)$').firstMatch(line);
    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(heading.group(1)!, style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
      );
    }
    final bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      final indent = bullet.group(1)!.length >= 2 ? 16.0 : 0.0;
      return Padding(
        padding: EdgeInsets.only(left: indent, top: 1, bottom: 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('\u2022  '),
          Expanded(child: Text(bullet.group(2)!)),
        ]),
      );
    }
    return Text(line.trim());
  }
}
