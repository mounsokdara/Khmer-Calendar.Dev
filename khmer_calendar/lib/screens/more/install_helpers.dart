import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../net.dart';
import '../../store.dart';
import '../../web_install.dart';
import '../../custom_components/slide_snackbar.dart';
import '../../widgets/dialog_actions.dart';

const _release = 'https://github.com/mounsokdara/Khmer-Calendar/releases/latest/download';

Future<void> openPackDownload(BuildContext context, {required Lang lang, required String file}) async {
  if (NetStatus.isOffline) {
    SlideSnackBar.show(context, message: t(lang, 'downloadOffline'), behavior: SnackBarBehavior.floating);
    return;
  }
  await launchUrl(Uri.parse('$_release/$file'), mode: LaunchMode.externalApplication);
}

Future<void> openBrowserInstall(BuildContext context, {required AppStore store, required Lang lang}) async {
  if (browserIsStandalone()) {
    store.setInstalled(true);
    if (context.mounted) {
      SlideSnackBar.show(context, message: t(lang, 'exportInstalled'), behavior: SnackBarBehavior.floating);
    }
    return;
  }
  final ok = await promptBrowserInstall();
  if (ok) {
    store.setInstalled(true);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      title: Text(t(lang, 'shortcutTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(lang, 'shortcutAsk')),
          const SizedBox(height: 12),
          Text(t(lang, 'shortcutAndroid')),
          const SizedBox(height: 8),
          Text(t(lang, 'shortcutIos')),
          const SizedBox(height: 8),
          Text(t(lang, 'shortcutDesktop')),
        ],
      ),
      actions: equalDialogActions([
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx),
          style: dialogBtnStyle(),
          child: dlgLabel(t(lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            store.setInstalled(true);
            Navigator.pop(ctx);
          },
          style: dialogBtnStyle(),
          child: dlgLabel(t(lang, 'shortcutAdd')),
        ),
      ]),
    ),
  );
}
