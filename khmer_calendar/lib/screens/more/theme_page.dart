import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../store.dart';
import '../../widgets/overlay_page.dart';
import '../../widgets/scheme_chips.dart';
import '../../widgets/segmented_list.dart';
import '../../widgets/sheet_kit.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return WatchStore(
      store: store,
      builder: (context, store) {
        final lang = store.lang;
        return OverlayScaffold(
          title: t(lang, 'themePageTitle'),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 8),
              PageIntro(text: t(lang, 'themeIntro'), icon: Icons.palette_outlined),
              SectionLabel(t(lang, 'themeModeLabel')),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(t(lang, 'themeModeSub'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: box.maxWidth),
                        child: SegmentedButton<String>(
                          showSelectedIcon: box.maxWidth > 380,
                          segments: [
                            ButtonSegment(value: 'light', label: Text(t(lang, 'modeLight'))),
                            ButtonSegment(value: 'dark', label: Text(t(lang, 'modeDark'))),
                            ButtonSegment(value: 'system', label: Text(t(lang, 'modeSystem'))),
                          ],
                          selected: {store.theme},
                          onSelectionChanged: (s) => store.setTheme(s.first),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SectionLabel(t(lang, 'themeColorsLabel')),
              SegmentedGroup(
                filled: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                children: [
                  SegmentedSwitch(
                    icon: Icons.format_color_text,
                    title: t(lang, 'textStroke'),
                    subtitle: t(lang, 'textStrokeSub'),
                    value: store.textStroke,
                    compact: true,
                    onChanged: store.setTextStroke,
                  ),
                  SegmentedSwitch(
                    icon: Icons.wallpaper,
                    title: t(lang, 'dynamicColor'),
                    subtitle: t(lang, 'dynamicColorSub'),
                    value: store.dynamicColor,
                    compact: true,
                    onChanged: store.setDynamicColor,
                  ),
                ],
              ),
              IgnorePointer(
                ignoring: store.dynamicColor,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: store.dynamicColor ? 0.38 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedGroup(
                        filled: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          SegmentedSwitch(
                            icon: Icons.palette,
                            title: t(lang, 'materialYou'),
                            subtitle: t(lang, 'materialYouSub'),
                            value: store.materialYou,
                            compact: true,
                            onChanged: store.dynamicColor ? null : store.setMaterialYou,
                          ),
                        ],
                      ),
                      SchemeChipScroller(store: store),
                      SegmentedGroup(
                        filled: false,
                        children: [
                          SegmentedSwitch(
                            icon: Icons.contrast,
                            title: t(lang, 'extraDark'),
                            subtitle: t(lang, 'extraDarkSub'),
                            value: store.extraDark,
                            compact: true,
                            onChanged: store.dynamicColor ? null : store.setExtraDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SegmentedGroup(
                        filled: false,
                        children: [
                          ColorRow(
                            compact: true,
                            title: t(lang, 'accent'),
                            subtitle: t(lang, 'accentSub'),
                            value: store.accentColor,
                            icon: Icons.brush,
                            disabled: store.materialYou && !store.dynamicColor,
                            onPick: () => showColorPicker(
                              context,
                              lang: lang,
                              title: t(lang, 'accent'),
                              value: store.accentColor,
                              onSave: store.setAccentColor,
                            ),
                          ),
                          ColorRow(
                            compact: true,
                            title: t(lang, 'highlight'),
                            subtitle: t(lang, 'highlightSub'),
                            value: store.highlightColor,
                            icon: Icons.water_drop_outlined,
                            disabled: store.materialYou && !store.dynamicColor,
                            onPick: () => showColorPicker(
                              context,
                              lang: lang,
                              title: t(lang, 'highlight'),
                              value: store.highlightColor,
                              onSave: store.setHighlightColor,
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t(lang, 'highlightAlpha'), style: Theme.of(context).textTheme.titleSmall),
                                Text(t(lang, 'highlightAlphaSub'), style: Theme.of(context).textTheme.bodySmall),
                                Slider(
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label: '${(store.highlightAlpha * 100).round()}%',
                                  value: (store.highlightAlpha * 100).clamp(0, 100),
                                  onChanged: (store.materialYou || store.dynamicColor)
                                      ? null
                                      : (n) => store.setHighlightAlpha(n / 100),
                                ),
                              ],
                            ),
                          ),
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
