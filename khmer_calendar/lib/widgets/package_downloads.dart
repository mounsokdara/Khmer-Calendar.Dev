import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../screens/more/device_arch.dart';
import '../screens/more/install_helpers.dart';
import '../theme.dart' show appVersion;
import 'os_logo.dart';
import 'segmented_list.dart';

/// One downloadable file of a release (the file names match the Release workflow).
class Pack {
  const Pack(this.os, this.file, this.titleKm, this.titleEn, this.descKm, this.descEn);
  final String os;
  final String file;
  final String titleKm;
  final String titleEn;
  final String descKm;
  final String descEn;

  String title(Lang l) => l == Lang.km ? titleKm : titleEn;
  String desc(Lang l) => l == Lang.km ? descKm : descEn;
}

const packs = <Pack>[
  Pack('android', 'KhmerCalendar-arm64.apk', 'arm64', 'arm64', 'ទូរស័ព្ទ និងថេប្លេតភាគច្រើន', 'Most phones and tablets'),
  Pack('android', 'KhmerCalendar-arm32.apk', 'arm32', 'arm32', 'ទូរស័ព្ទ ៣២ប៊ីតចាស់ៗ', 'Older 32-bit phones'),
  Pack('android', 'KhmerCalendar-x64.apk', 'x64', 'x64', 'កម្មវិធីក្លែងធ្វើ និង Chromebook Intel', 'Emulators and Intel Chromebooks'),
  Pack('android', 'KhmerCalendar-arm32_64.apk', 'arm32 + arm64', 'arm32 + arm64', 'ទាំងពីរក្នុងឯកសារតែមួយ', 'Both in one file'),
  Pack('android', 'KhmerCalendar-universal.apk', 'សកល (universal)', 'Universal', 'arm, arm64 និង x64 ក្នុងឯកសារតែមួយ (ធំជាងគេ)', 'arm, arm64 and x64 in one file (largest)'),
  Pack('windows', 'KhmerCalendar-windows-x64-setup.exe', 'កម្មវិធីដំឡើង x64', 'Setup wizard x64', 'កុំព្យូទ័រ Intel និង AMD៖ ដំឡើងសម្រាប់អ្នកប្រើនេះ មានផ្លូវកាត់ក្នុង Start menu', 'Intel and AMD PCs: installs for you only, adds a Start menu shortcut'),
  Pack('windows', 'KhmerCalendar-windows-arm64-setup.exe', 'កម្មវិធីដំឡើង arm64', 'Setup wizard arm64', 'កុំព្យូទ័រ ARM៖ ដំឡើងកំណែដើម (native)', 'ARM PCs: installs the native build'),
  Pack('windows', 'KhmerCalendar-windows-universal-setup.exe', 'កម្មវិធីដំឡើង សកល', 'Setup wizard universal', 'x64 និង arm64 ក្នុងមួយ៖ ដំឡើងកំណែដែលត្រូវនឹងកុំព្យូទ័រ', 'x64 and arm64 in one: installs the build that fits your PC'),
  Pack('windows', 'KhmerCalendar-windows-x64.zip', 'ប្រើដោយមិនដំឡើង x64', 'Portable x64', 'កុំព្យូទ័រ Intel និង AMD៖ ពន្លាហើយប្រើ', 'Intel and AMD PCs: unzip and run'),
  Pack('windows', 'KhmerCalendar-windows-arm64.zip', 'ប្រើដោយមិនដំឡើង arm64', 'Portable arm64', 'កុំព្យូទ័រ ARM៖ ពន្លាហើយប្រើ', 'ARM PCs: unzip and run'),
  Pack('windows', 'KhmerCalendar-windows-universal.zip', 'ប្រើដោយមិនដំឡើង សកល', 'Portable universal', 'x64 និង arm64 ក្នុង zip តែមួយ (ចុច KhmerCalendar.cmd)', 'x64 and arm64 in one zip (run KhmerCalendar.cmd)'),
  Pack('macos', 'KhmerCalendar-macos-arm64.dmg', 'Apple Silicon', 'Apple Silicon', 'Mac M1 ឡើងទៅ', 'Macs with M1 or newer'),
  Pack('macos', 'KhmerCalendar-macos-x86_64.dmg', 'Intel', 'Intel', 'Mac ប្រើ Intel', 'Intel Macs'),
  Pack('macos', 'KhmerCalendar-macos-universal.dmg', 'សកល (universal)', 'Universal', 'ទាំងពីរក្នុងឯកសារតែមួយ (ធំជាងគេ)', 'Both in one file (largest)'),
  Pack('linux', 'KhmerCalendar-linux-x64.tar.gz', 'x64', 'x64', 'Intel និង AMD', 'Intel and AMD'),
  Pack('linux', 'KhmerCalendar-linux-arm64.tar.gz', 'arm64', 'arm64', 'ARM ៦៤ប៊ីត (Raspberry Pi, ម៉ាស៊ីនមេ ARM)', 'ARM 64-bit (Raspberry Pi, ARM servers)'),
  Pack('linux', 'KhmerCalendar-linux-universal.tar.gz', 'សកល (universal)', 'Universal', 'x64 និង arm64 ក្នុងឯកសារតែមួយ (ដំណើរការ khmer-calendar.sh)', 'x64 and arm64 in one file (run khmer-calendar.sh)'),
  Pack('project', 'KhmerCalendar-project.zip', 'កូដប្រភព', 'Source code', 'គម្រោងទាំងមូលជា zip', 'The whole project as a zip'),
];

const _osOrder = ['android', 'windows', 'macos', 'linux', 'project'];

String _osName(String os, Lang lang) => switch (os) {
      'android' => 'Android',
      'windows' => 'Windows',
      'macos' => 'macOS',
      'linux' => 'Linux',
      _ => lang == Lang.km ? 'កូដប្រភព' : 'Source code',
    };

/// The package that fits the device the app is running on (null where there is none, e.g. iOS).
/// On the web only the operating system is known, so the arch-neutral file is chosen.
Pack? recommendedPack() {
  final arch = kIsWeb ? null : deviceArch();
  final String? file = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'KhmerCalendar-${arch ?? 'universal'}.apk',
    TargetPlatform.windows => 'KhmerCalendar-windows-${arch == 'arm64' ? 'arm64' : 'x64'}-setup.exe',
    TargetPlatform.macOS => 'KhmerCalendar-macos-${arch == null ? 'universal' : (arch == 'x64' ? 'x86_64' : 'arm64')}.dmg',
    TargetPlatform.linux => 'KhmerCalendar-linux-${arch == 'arm64' ? 'arm64' : 'x64'}.tar.gz',
    _ => null,
  };
  if (file == null) return null;
  for (final p in packs) {
    if (p.file == file) return p;
  }
  return null;
}

/// Download list: a card for this device first, then every package grouped by operating system.
/// [compact] (used inside the setup steps) starts with only the recommended card and a button to show the rest.
class PackageDownloads extends StatefulWidget {
  const PackageDownloads({super.key, required this.lang, this.online = true, this.compact = false});
  final Lang lang;
  final bool online;
  final bool compact;

  @override
  State<PackageDownloads> createState() => _PackageDownloadsState();
}

class _PackageDownloadsState extends State<PackageDownloads> {
  late bool _showAll = !widget.compact;

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String tr(String khmer, String english) => lang == Lang.km ? khmer : english;
    final rec = recommendedPack();
    final oses = [..._osOrder];
    if (rec != null) {
      oses
        ..remove(rec.os)
        ..insert(0, rec.os);
    }
    final showList = _showAll || rec == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rec != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: cs.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('ណែនាំសម្រាប់ឧបករណ៍នេះ', 'Recommended for this device'),
                        style: text.labelLarge?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OsLogo(rec.os, size: 40),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_osName(rec.os, lang)} · ${rec.title(lang)}',
                                  style: text.titleMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                                ),
                                Text(rec.desc(lang), style: TextStyle(color: cs.onPrimaryContainer)),
                                const SizedBox(height: 2),
                                Text(
                                  rec.file,
                                  style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.75)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => openPackDownload(context, lang: lang, file: rec.file),
                        icon: const Icon(Icons.download),
                        label: Text('${tr('ទាញយក', 'Download')} v$appVersion'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (rec != null && !showList) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.expand_more),
              label: Text(tr('បង្ហាញកញ្ចប់ទាំងអស់', 'Show all packages')),
            ),
          ),
        ],
        if (showList)
          for (final os in oses) ...[
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Row(
                    children: [
                      if (os == 'project') const Icon(Icons.folder_zip) else OsLogo(os, size: 24),
                      const SizedBox(width: 10),
                      Text(_osName(os, lang), style: text.titleSmall),
                    ],
                  ),
                ),
              ),
            ),
            SegmentedGroup(
              padding: EdgeInsets.zero,
              children: [
                for (final p in packs.where((p) => p.os == os))
                  SegmentedTile(
                    dim: !widget.online,
                    selected: rec != null && p.file == rec.file,
                    title: p.title(lang),
                    subtitle: '${p.desc(lang)}\n${p.file}',
                    trailing: const Icon(Icons.download),
                    onTap: () => openPackDownload(context, lang: lang, file: p.file),
                  ),
              ],
            ),
          ],
        if (showList) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/mounsokdara/Khmer-Calendar/releases/latest'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(tr('កំណែទាំងអស់នៅលើ GitHub', 'All releases on GitHub')),
            ),
          ),
        ],
      ],
    );
  }
}
