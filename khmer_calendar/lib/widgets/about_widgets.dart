import 'package:flutter/material.dart';

/// Shared building blocks for the About and Changelog pages (Material 3 cards).

class AboutChip extends StatelessWidget {
  const AboutChip(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: cs.onSecondaryContainer), const SizedBox(width: 5)],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer),
          ),
        ),
      ]),
    );
  }
}

class AboutItem {
  const AboutItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.link = false,
    this.chevron = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool link;
  final bool chevron;
}

/// Stack of tiles: big corners on the first and last tile, small corners in between.
class AboutGroup extends StatelessWidget {
  const AboutGroup({super.key, required this.items});
  final List<AboutItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = dark ? const Color(0xFF8AB4F8) : const Color(0xFF1A73E8);
    const big = Radius.circular(20), small = Radius.circular(4);
    final last = items.length - 1;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
          child: Material(
            color: cs.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: i == 0 ? big : small,
                topRight: i == 0 ? big : small,
                bottomLeft: i == last ? big : small,
                bottomRight: i == last ? big : small,
              ),
            ),
            child: InkWell(
              onTap: items[i].onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72, minWidth: double.infinity),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Icon(items[i].icon, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          items[i].subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: items[i].link ? linkColor : cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                    if (items[i].chevron && items[i].onTap != null) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class QuickAction {
  const QuickAction({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
}

/// Row of big icon buttons joined into one pill (Changelog, GitHub, Update, Issues).
class AboutQuickActions extends StatelessWidget {
  const AboutQuickActions({super.key, required this.items});
  final List<QuickAction> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const big = Radius.circular(28), small = Radius.circular(4);
    final last = items.length - 1;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
              child: Material(
                color: cs.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: i == 0 ? big : small,
                    bottomLeft: i == 0 ? big : small,
                    topRight: i == last ? big : small,
                    bottomRight: i == last ? big : small,
                  ),
                ),
                child: InkWell(
                  onTap: items[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      items[i].iconWidget ??
                          Icon(items[i].icon, size: 28, color: cs.onSurface),
                      const SizedBox(height: 10),
                      Text(
                        items[i].label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
