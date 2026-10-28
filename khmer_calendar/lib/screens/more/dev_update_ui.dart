import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../net.dart';
import 'dev_update.dart';

String _s(Lang lang, String km, String en) => lang == Lang.km ? km : en;

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

String _when(DateTime utc) {
  final d = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String _describe(DevBuild b) {
  final parts = <String>[
    if (b.sha.isNotEmpty) '#${b.sha}',
    _when(b.builtAt),
    if (b.size > 0) _mb(b.size),
    b.package,
  ];
  return parts.join('  ·  ');
}

Future<void> _message(BuildContext context, Lang lang, String title, String body, {List<Widget> extra = const []}) {
  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        ...extra,
        TextButton(onPressed: () => Navigator.pop(d), child: Text(_s(lang, 'យល់ព្រម', 'OK'))),
      ],
    ),
  );
}

/// "Check for updates" for dev builds: finds the newest APK of the `dev-latest` pre-release, downloads it inside
/// the app and opens the system installer. No browser, no GitHub page.
Future<void> runDevUpdateCheck(BuildContext context, Lang lang) async {
  if (NetStatus.isOffline) {
    await _message(context, lang, _s(lang, 'ពិនិត្យកំណែថ្មី', 'Check for updates'), t(lang, 'downloadOffline'));
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          const SizedBox(width: 16),
          Text(_s(lang, 'កំពុងពិនិត្យកំណែថ្មី…', 'Checking for updates…')),
        ],
      ),
    ),
  );

  DevBuild? build;
  Object? error;
  try {
    build = await fetchDevBuild();
  } catch (e) {
    error = e;
  }
  if (context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;

  final title = _s(lang, 'កំណែសាកល្បង', 'Dev build');
  if (error != null) {
    await _message(context, lang, title, _s(lang, 'មិនអាចពិនិត្យកំណែថ្មីបានទេ។', 'Unable to check for updates.'),
        extra: [_browserButton(lang)]);
    return;
  }
  if (build == null) {
    await _message(
      context,
      lang,
      title,
      _s(lang, 'មិនទាន់មានកំណែសាកល្បងសម្រាប់ឧបករណ៍របស់អ្នកទេ។ ប្រហែលកំពុងបង្កើត សូមព្យាយាមម្តងទៀតបន្តិចទៀត។',
          'No dev build for your device yet. It may still be building, try again in a few minutes.'),
    );
    return;
  }

  final found = build;
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(found.isNewer ? _s(lang, 'មានកំណែសាកល្បងថ្មី', 'Dev build available') : title),
      content: Text(
        found.isNewer
            ? _describe(found)
            : '${_s(lang, 'អ្នកកំពុងប្រើកំណែសាកល្បងថ្មីបំផុត។', 'You are on the latest dev build.')}\n\n${_describe(found)}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(_s(lang, 'បិទ', 'Close'))),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(found.isNewer ? _s(lang, 'ទាញយក និងដំឡើង', 'Download & install') : _s(lang, 'ដំឡើងម្តងទៀត', 'Reinstall')),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await _downloadAndInstall(context, lang, found);
}

Widget _browserButton(Lang lang) => TextButton(
      onPressed: () => launchUrl(Uri.parse(devReleasePageUrl), mode: LaunchMode.externalApplication),
      child: Text(_s(lang, 'បើកក្នុងកម្មវិធីរុករក', 'Open in browser')),
    );

Future<void> _downloadAndInstall(BuildContext context, Lang lang, DevBuild build) async {
  final progress = ValueNotifier<double?>(null);
  var cancelled = false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      title: Text(_s(lang, 'កំពុងទាញយក…', 'Downloading…')),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: v),
            const SizedBox(height: 10),
            Text(v == null ? build.assetName : '${(v * 100).round()}%  ·  ${build.assetName}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            Navigator.pop(d);
          },
          child: Text(_s(lang, 'បោះបង់', 'Cancel')),
        ),
      ],
    ),
  );

  String? path;
  Object? error;
  try {
    path = await downloadDevBuild(
      build,
      (got, total) => progress.value = total > 0 ? got / total : null,
      isCancelled: () => cancelled,
    );
  } on DevUpdateCancelled {
    progress.dispose();
    return; // the dialog was already closed by Cancel
  } catch (e) {
    error = e;
  }
  progress.dispose();

  if (cancelled) return;
  if (context.mounted) Navigator.of(context).pop(); // close the progress dialog
  if (!context.mounted) return;

  if (error != null || path == null) {
    await _message(
      context,
      lang,
      _s(lang, 'កំណែសាកល្បង', 'Dev build'),
      _s(lang, 'ការទាញយកមិនបានសម្រេច។ សូមព្យាយាមម្តងទៀត។', 'The download did not finish. Please try again.'),
      extra: [_browserButton(lang)],
    );
    return;
  }
  await _install(context, lang, path, build);
}

Future<void> _install(BuildContext context, Lang lang, String path, DevBuild build) async {
  final result = await installDevBuild(path, build);
  if (!context.mounted) return;

  if (result == DevInstallResult.started) {
    // Desktop: the updater is waiting for this app to quit; it swaps the files and starts the new version.
    if (devUpdateRestartsApp) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
              const SizedBox(width: 16),
              Flexible(child: Text(_s(lang, 'កំពុងធ្វើបច្ចុប្បន្នភាព កម្មវិធីនឹងចាប់ផ្តើមឡើងវិញ…', 'Updating, the app will restart…'))),
            ],
          ),
        ),
      );
      await finishDevInstall();
    }
    return;
  }

  if (result == DevInstallResult.notWritable) {
    await _message(
      context,
      lang,
      _s(lang, 'កំណែសាកល្បង', 'Dev build'),
      _s(lang, 'មិនអាចសរសេរក្នុងថតកម្មវិធីបានទេ (ឧទាហរណ៍ Program Files)។ សូមផ្លាស់ទីកម្មវិធីទៅថតផ្សេង ឬធ្វើបច្ចុប្បន្នភាពដោយដៃ។',
          'The app folder is read-only (for example Program Files). Move the app to a folder you can write to, or update manually.'),
      extra: [_browserButton(lang)],
    );
    return;
  }

  if (result == DevInstallResult.needsPermission) {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: Text(_s(lang, 'ត្រូវការការអនុញ្ញាត', 'Permission needed')),
        content: Text(_s(
          lang,
          'សូមបើក «អនុញ្ញាតពីប្រភពនេះ» សម្រាប់ប្រតិទិនខ្មែរ រួចត្រឡប់មកវិញ ហើយចុច «ព្យាយាមម្តងទៀត»។ ឯកសារបានទាញយករួចហើយ។',
          'Turn on "Allow from this source" for Khmer Calendar, come back and tap Retry. The file is already downloaded.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(_s(lang, 'បោះបង់', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(_s(lang, 'ព្យាយាមម្តងទៀត', 'Retry'))),
        ],
      ),
    );
    if (retry == true && context.mounted) await _install(context, lang, path, build);
    return;
  }

  await _message(
    context,
    lang,
    _s(lang, 'កំណែសាកល្បង', 'Dev build'),
    _s(lang, 'មិនអាចបើកកម្មវិធីដំឡើងបានទេ។', 'Could not open the installer.'),
    extra: [_browserButton(lang)],
  );
}
