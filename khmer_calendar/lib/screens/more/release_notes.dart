import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart' show appSourceUrl;

/// Releases of the public repo, shown in About > Changelog.
/// Dev and public builds read the same list, so the code is identical in both repos.
const _releasesApi = 'https://api.github.com/repos/mounsokdara/Khmer-Calendar/releases?per_page=30';
const releasesPageUrl = '$appSourceUrl/releases';

class ReleaseNote {
  const ReleaseNote({
    required this.tag,
    required this.title,
    required this.body,
    required this.url,
    this.publishedAt,
    this.prerelease = false,
  });

  final String tag;
  final String title;
  final String body;
  final String url;
  final DateTime? publishedAt;
  final bool prerelease;

  factory ReleaseNote.fromJson(Map<String, dynamic> j) {
    final tag = (j['tag_name'] as String?) ?? '';
    final name = (j['name'] as String?)?.trim() ?? '';
    return ReleaseNote(
      tag: tag,
      title: name.isEmpty ? tag : name,
      body: ((j['body'] as String?) ?? '').replaceAll('\r', '').trim(),
      url: (j['html_url'] as String?) ?? releasesPageUrl,
      publishedAt: DateTime.tryParse((j['published_at'] as String?) ?? ''),
      prerelease: (j['prerelease'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'tag_name': tag,
        'name': title,
        'body': body,
        'html_url': url,
        'published_at': publishedAt?.toUtc().toIso8601String(),
        'prerelease': prerelease,
      };
}

class ReleaseFeed {
  const ReleaseFeed({required this.releases, required this.fromCache, this.failed = false, this.savedAt});
  final List<ReleaseNote> releases;
  final bool fromCache;
  final bool failed;
  final DateTime? savedAt;
}

class ReleaseNotes {
  ReleaseNotes._();

  static const _key = 'release_notes_cache_v1';
  static const _freshFor = Duration(hours: 1);

  static Future<ReleaseFeed?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list = [
        for (final e in j['releases'] as List<dynamic>) ReleaseNote.fromJson(e as Map<String, dynamic>),
      ];
      return ReleaseFeed(
        releases: list,
        fromCache: true,
        savedAt: DateTime.tryParse((j['fetchedAt'] as String?) ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _save(List<ReleaseNote> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'releases': [for (final r in list) r.toJson()],
        }),
      );
    } catch (_) {}
  }

  static Future<ReleaseFeed> load({bool refresh = false}) async {
    final saved = await _readSaved();
    if (!refresh && saved != null && saved.savedAt != null) {
      if (DateTime.now().toUtc().difference(saved.savedAt!) < _freshFor) return saved;
    }
    try {
      final res = await http
          .get(Uri.parse(_releasesApi), headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw StateError('GitHub answered ${res.statusCode}');
      final list = <ReleaseNote>[
        for (final e in jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>)
          if ((e as Map<String, dynamic>)['draft'] != true) ReleaseNote.fromJson(e),
      ];
      await _save(list);
      return ReleaseFeed(releases: list, fromCache: false, savedAt: DateTime.now().toUtc());
    } catch (_) {
      if (saved != null) return ReleaseFeed(releases: saved.releases, fromCache: true, failed: true, savedAt: saved.savedAt);
      return const ReleaseFeed(releases: [], fromCache: false, failed: true);
    }
  }
}

/// Release bodies are Markdown; drop link syntax and emphasis marks so they read as plain text.
String plainNotes(String md) {
  var s = md;
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!);
  s = s.replaceAll(RegExp(r'(\*\*|__|`)'), '');
  return s;
}
