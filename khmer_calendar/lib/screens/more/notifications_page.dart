import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../permissions.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/overlay_page.dart';
import '../../widgets/segmented_list.dart';
import '../../widgets/sheet_kit.dart';
import '../../widgets/sil_mark.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) {
        final lang = store.lang;

        Future<void> toggle(bool v, void Function(bool) set) async {
          if (v && !store.notifyOn) {
            final ok = await requestNotifications(store);
            if (!ok && context.mounted) {
              await promptIfDenied(store, context: context, kind: 'notify', allowed: notificationsAllowed);
            }
            if (!store.notifyOn) return;
          }
          set(v);
        }

        return OverlayScaffold(
          title: t(lang, 'notifyPageTitle'),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              PageIntro(text: t(lang, 'notifyIntro'), icon: Icons.notifications_active_outlined),
              if (!store.notifyOn)
                InfoBanner(text: t(lang, 'notifyOffBanner'), icon: Icons.notifications_off_outlined, warning: true),
              SegmentedGroup(
                children: [
                  SegmentedSwitch(
                    icon: Icons.wb_sunny_outlined,
                    title: t(lang, 'remindDaily'),
                    subtitle: t(lang, 'remindDailySub'),
                    value: store.notifyDaily,
                    onChanged: (v) => toggle(v, store.setNotifyDaily),
                  ),
                  SegmentedSwitch(
                    icon: Icons.flag_outlined,
                    title: t(lang, 'remindPublic'),
                    subtitle: t(lang, 'remindPublicSub'),
                    value: store.notifyPublic,
                    onChanged: (v) => toggle(v, store.setNotifyPublic),
                  ),
                  SegmentedSwitch(
                    icon: Icons.event_outlined,
                    iconColor: religiousColor,
                    title: t(lang, 'remindOthers'),
                    subtitle: t(lang, 'remindOthersSub'),
                    value: store.notifyOthers,
                    onChanged: (v) => toggle(v, store.setNotifyOthers),
                  ),
                  SegmentedSwitch(
                    leading: const SilMark(size: 24),
                    title: t(lang, 'remindSil'),
                    subtitle: t(lang, 'remindSilSub'),
                    value: store.notifySil,
                    onChanged: (v) => toggle(v, store.setNotifySil),
                  ),
                  SegmentedSwitch(
                    icon: Icons.task_alt,
                    title: t(lang, 'remindTasks'),
                    subtitle: t(lang, 'remindTasksSub'),
                    value: store.notifyTasks,
                    onChanged: (v) => toggle(v, store.setNotifyTasks),
                  ),
                  SegmentedSwitch(
                    icon: Icons.event_available_outlined,
                    title: t(lang, 'remindTomorrow'),
                    subtitle: t(lang, 'remindTomorrowSub'),
                    value: store.notifyTomorrow,
                    onChanged: (v) => toggle(v, store.setNotifyTomorrow),
                  ),
                  if (store.notifyTomorrow)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                      child: Column(
                        children: [
                          for (final o in <(String, bool, void Function(bool))>[
                            ('tomorrowOptTasks', store.tomorrowTasks, store.setTomorrowTasks),
                            ('tomorrowOptHolidays', store.tomorrowHolidays, store.setTomorrowHolidays),
                            ('tomorrowOptLunar', store.tomorrowLunar, store.setTomorrowLunar),
                          ])
                            CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(t(lang, o.$1)),
                              value: o.$2,
                              onChanged: (v) => o.$3(v ?? false),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
