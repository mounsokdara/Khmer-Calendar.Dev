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

String _describe(UpdateBuild b) {
  final parts = <String>[
    'v${b.versionName}',
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

/// "Check for updates": finds the release tag that matches version.txt, downloads the package for this
/// device inside the app and opens the system installer / desktop updater. No browser required.
Future<void> runInAppUpdateCheck(BuildContext context, Lang lang) async {
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

  UpdateBuild? build;
  Object? error;
  try {
    build = await fetchUpdateBuild();
  } catch (e) {
    error = e;
  }
  if (context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;

  final title = _s(lang, 'កំណែថ្មី', 'Updates');
  if (error != null) {
    final detail = error is UpdateException ? error.message : error.toString();
    await _message(
      context,
      lang,
      title,
      _s(lang, 'មិនអាចពិនិត្យកំណែថ្មីបានទេ។\n\n$detail', 'Unable to check for updates.\n\n$detail'),
    );
    return;
  }
  if (build == null) {
    await _message(
      context,
      lang,
      title,
      _s(
        lang,
        'មិនទាន់មានកំណែសម្រាប់ឧបករណ៍របស់អ្នកទេ។ ប្រហែលកំពុងបង្កើត សូមព្យាយាមម្តងទៀតបន្តិចទៀត។',
        'No build for your device yet. It may still be publishing, try again in a few minutes.',
      ),
    );
    return;
  }

  final found = build;
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(found.isNewer ? _s(lang, 'មានកំណែថ្មី', 'Update available') : title),
      content: Text(
        found.isNewer
            ? _describe(found)
            : '${_s(lang, 'អ្នកកំពុងប្រើកំណែថ្មីបំផុត។', 'You are on the latest version.')}\n\n${_describe(found)}',
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

Widget _browserButton(Lang lang, String versionName) => TextButton(
      onPressed: () => launchUrl(Uri.parse(updateReleasePageUrl(versionName)), mode: LaunchMode.externalApplication),
      child: Text(_s(lang, 'បើកក្នុងកម្មវិធីរុករក', 'Open in browser')),
    );

Future<void> _downloadAndInstall(BuildContext context, Lang lang, UpdateBuild build) async {
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
    path = await downloadUpdateBuild(
      build,
      (got, total) => progress.value = total > 0 ? got / total : null,
      isCancelled: () => cancelled,
    );
  } on UpdateCancelled {
    progress.dispose();
    return;
  } catch (e) {
    error = e;
  }
  progress.dispose();

  if (cancelled) return;
  if (context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;

  if (error != null || path == null) {
    final detail = error is UpdateException ? error.message : (error?.toString() ?? '');
    await _message(
      context,
      lang,
      _s(lang, 'កំណែថ្មី', 'Updates'),
      _s(
        lang,
        'ការទាញយកមិនបានសម្រេច។${detail.isEmpty ? '' : '\n\n$detail'}',
        'The download did not finish.${detail.isEmpty ? '' : '\n\n$detail'}',
      ),
      extra: [_browserButton(lang, build.versionName)],
    );
    return;
  }
  await _install(context, lang, path, build);
}

Future<void> _install(BuildContext context, Lang lang, String path, UpdateBuild build) async {
  // Another copy of the app keeps the files locked and would make the update fail. Say so first.
  if (updateRestartsApp) {
    final others = await otherAppInstances();
    if (!context.mounted) return;
    if (others.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (d) => AlertDialog(
          title: Text(_s(lang, 'មានកម្មវិធីកំពុងដំណើរការ', 'Another copy is running')),
          content: Text(_s(
            lang,
            'មានប្រតិទិនខ្មែរមួយទៀតកំពុងបើក (${others.join(', ')})។ វាអាចរារាំងការធ្វើបច្ចុប្បន្នភាព។ សូមបិទវាសិន រួចចុច «ព្យាយាមម្តងទៀត»។',
            'Another copy of Khmer Calendar is running (${others.join(', ')}). It can block the update. Close it, then tap Retry.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(_s(lang, 'បោះបង់', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(_s(lang, 'ព្យាយាមម្តងទៀត', 'Retry'))),
          ],
        ),
      );
      if (go == true && context.mounted) await _install(context, lang, path, build);
      return;
    }
  }

  final result = await installUpdateBuild(path, build);
  if (!context.mounted) return;

  if (result == UpdateInstallResult.started) {
    if (updateRestartsApp) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
              const SizedBox(width: 16),
              Flexible(
                child: Text(_s(lang, 'កំពុងធ្វើបច្ចុប្បន្នភាព កម្មវិធីនឹងចាប់ផ្តើមឡើងវិញ…', 'Updating, the app will restart…')),
              ),
            ],
          ),
        ),
      );
      await finishUpdateInstall();
    }
    return;
  }

  if (result == UpdateInstallResult.notWritable) {
    await _message(
      context,
      lang,
      _s(lang, 'កំណែថ្មី', 'Updates'),
      _s(
        lang,
        'មិនអាចសរសេរក្នុងថតកម្មវិធីបានទេ (ឧទាហរណ៍ Program Files)។ សូមផ្លាស់ទីកម្មវិធីទៅថតផ្សេង ឬធ្វើបច្ចុប្បន្នភាពដោយដៃ។',
        'The app folder is read-only (for example Program Files). Move the app to a folder you can write to, or update manually.',
      ),
      extra: [_browserButton(lang, build.versionName)],
    );
    return;
  }

  if (result == UpdateInstallResult.needsPermission) {
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
    _s(lang, 'កំណែថ្មី', 'Updates'),
    _s(lang, 'មិនអាចបើកកម្មវិធីដំឡើងបានទេ។', 'Could not open the installer.'),
    extra: [_browserButton(lang, build.versionName)],
  );
}

/// Called once after start. If the desktop updater could not finish (for example because another
/// program was using the app files), tell the user what happened and what to do.
Future<void> showPendingUpdateFailure(BuildContext context, Lang lang) async {
  final failure = await takeUpdateFailure();
  if (failure == null || !context.mounted) return;

  final String body;
  if (failure.isLocked) {
    final who = failure.processes.isEmpty
        ? ''
        : _s(lang, '\n\nកម្មវិធីដែលត្រូវបិទ៖ ${failure.processes.join(', ')}',
            '\n\nPlease close: ${failure.processes.join(', ')}');
    final files = failure.files.isEmpty ? '' : '\n\n${failure.files.take(3).join('\n')}';
    body = _s(
      lang,
      'ការធ្វើបច្ចុប្បន្នភាពមិនបានសម្រេចទេ ព្រោះមានកម្មវិធីផ្សេងកំពុងប្រើឯកសាររបស់កម្មវិធីនេះ។ សូមបិទកម្មវិធីទាំងនោះ រួចព្យាយាមម្តងទៀត។$who$files',
      'The update failed because another program is using this app\'s files. Close it (including any other copy of Khmer Calendar), then try again.$who$files',
    );
  } else {
    body = _s(
      lang,
      'ការធ្វើបច្ចុប្បន្នភាពមិនបានសម្រេចទេ។ កំណែបច្ចុប្បន្នរបស់អ្នកនៅដដែល។ សូមព្យាយាមម្តងទៀត។${failure.detail.isEmpty ? '' : '\n\n${failure.detail}'}',
      'The update did not finish. Your current version is unchanged. Please try again.${failure.detail.isEmpty ? '' : '\n\n${failure.detail}'}',
    );
  }

  final retry = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(_s(lang, 'ធ្វើបច្ចុប្បន្នភាពមិនបាន', 'Update failed')),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(_s(lang, 'បិទ', 'Close'))),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(_s(lang, 'ព្យាយាមម្តងទៀត', 'Try again'))),
      ],
    ),
  );
  if (retry == true && context.mounted) await runInAppUpdateCheck(context, lang);
}
