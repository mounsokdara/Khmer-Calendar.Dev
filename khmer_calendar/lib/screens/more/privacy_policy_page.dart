import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../store.dart';
import '../../widgets/overlay_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) {
        final km = store.lang == Lang.km;
        final cs = Theme.of(context).colorScheme;
        final sections = km ? _km : _en;
        return OverlayScaffold(
          title: km ? 'គោលការណ៍ឯកជនភាព' : 'Privacy policy',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              for (final s in sections) ...[
                Text(s.$1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.$2, style: TextStyle(height: 1.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}

const _en = <(String, String)>[
  ('No account, no analytics', 'Khmer Calendar has no sign-in, no ads and no analytics or crash-reporting service. Nothing about you is collected or sold.'),
  ('Data stored on your device', 'Your tasks, events, settings and chosen city are stored only on your device. Clearing the app data removes them.'),
  ('Network requests', 'The app contacts the internet only for: weather (Open-Meteo), checking for a newer release (GitHub, not in F-Droid builds) and showing the developer profile on the About page (GitHub). These requests do not include your name, tasks or events.'),
  ('Permissions', 'Location (optional) is used once to find your weather city. Notifications and exact alarms deliver reminders. Boot completed restores reminders after a restart. Vibration gives touch feedback on mobile devices. You can revoke any permission in system settings.'),
  ('Open source', 'The source code is public on GitHub so you can verify all of the above.'),
  ('Contact', 'Questions or requests: open an issue at github.com/mounsokdara/Khmer-Calendar.'),
];

const _km = <(String, String)>[
  ('គ្មានគណនី គ្មានការវិភាគ', 'ប្រតិទិនខ្មែរមិនមានការចូលគណនី ការផ្សាយពាណិជ្ជកម្ម ឬសេវាវិភាគ/រាយការណ៍កំហុសទេ។ គ្មានទិន្នន័យអ្វីអំពីអ្នកត្រូវបានប្រមូល ឬលក់ឡើយ។'),
  ('ទិន្នន័យក្នុងឧបករណ៍', 'កិច្ចការ ព្រឹត្តិការណ៍ ការកំណត់ និងទីក្រុងដែលអ្នកជ្រើស ត្រូវបានរក្សាទុកតែក្នុងឧបករណ៍របស់អ្នកប៉ុណ្ណោះ។ ការសម្អាតទិន្នន័យកម្មវិធីនឹងលុបវា។'),
  ('ការស្នើសុំតាមអ៊ីនធឺណិត', 'កម្មវិធីប្រើអ៊ីនធឺណិតសម្រាប់៖ អាកាសធាតុ (Open-Meteo) ពិនិត្យកំណែថ្មី (GitHub មិនមានក្នុង F-Droid) និងបង្ហាញប្រវត្តិរូបអ្នកអភិវឌ្ឍន៍ក្នុងទំព័រអំពី (GitHub)។ ការស្នើសុំទាំងនេះមិនមានឈ្មោះ កិច្ចការ ឬព្រឹត្តិការណ៍របស់អ្នកទេ។'),
  ('ការអនុញ្ញាត', 'ទីតាំង (ជម្រើស) ប្រើម្តងដើម្បីរកទីក្រុងអាកាសធាតុ។ ការជូនដំណឹង និងម៉ោងរោទ៍ ប្រើសម្រាប់ការរំលឹក។ ការចាប់ផ្តើមឧបករណ៍ឡើងវិញស្តារការរំលឹក។ ការញ័រផ្តល់ប្រតិកម្មពេលប៉ះលើទូរស័ព្ទ។ អ្នកអាចដកការអនុញ្ញាតណាមួយក្នុងការកំណត់ប្រព័ន្ធ។'),
  ('កូដប្រភពបើកចំហ', 'កូដប្រភពមាននៅលើ GitHub ដើម្បីឱ្យអ្នកផ្ទៀងផ្ទាត់។'),
  ('ទំនាក់ទំនង', 'សំណួរ ឬសំណើ៖ បើក issue នៅ github.com/mounsokdara/Khmer-Calendar។'),
];
