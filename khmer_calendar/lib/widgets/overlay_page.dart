import 'package:flutter/material.dart';

import '../custom_components/slide_snackbar.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart';
import '../store.dart';
import 'sheet_kit.dart';

class WatchStore extends StatelessWidget {
  const WatchStore({super.key, required this.store, required this.builder});
  final AppStore store;
  final Widget Function(BuildContext context, AppStore store) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => builder(context, store),
    );
  }
}

class OverlayScaffold extends StatelessWidget {
  const OverlayScaffold({super.key, required this.title, required this.body, this.actions});
  final String title;
  final Widget body;
  final List<Widget>? actions;

  static const _maxContentWidth = 680.0;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/more');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => _back(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, maxLines: 1),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: SlideSnackBarHost(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class LangRadios extends StatelessWidget {
  const LangRadios({super.key, required this.store, required this.uiLang, this.onPicked});
  final AppStore store;
  final Lang uiLang;
  final VoidCallback? onPicked;

  static const _maxWidth = 680.0;

  @override
  Widget build(BuildContext context) {
    final opts = [
      ('auto', t(uiLang, 'langAuto'), t(uiLang, 'langAutoSub')),
      ('km', 'ខ្មែរ', 'Khmer'),
      ('en', 'English', 'English'),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in opts)
              SheetOption(
                title: o.$2,
                subtitle: o.$3,
                selected: store.langPref == o.$1,
                onTap: () {
                  store.setLang(o.$1);
                  onPicked?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
