import 'package:flutter/material.dart';

/// Text with a thin contrasting outline so day numbers and labels stay readable on any
/// highlight, selection or custom background. Same parameters as [Text].
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.data, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// Switched from the app root whenever the setting changes; every [StrokeText] listens, so the
  /// change shows immediately without reopening the app.
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  static bool get enabled => enabledNotifier.value;
  static set enabled(bool v) => enabledNotifier.value = v;

  final String data;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabledNotifier,
      builder: (context, on, _) => _build(context, on),
    );
  }

  Widget _build(BuildContext context, bool enabled) {
    final fill = Text(data, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    if (!enabled) return fill;
    final base = style.color ?? Theme.of(context).colorScheme.onSurface;
    final outline = (base.computeLuminance() > 0.5 ? Colors.black : Colors.white).withValues(alpha: 0.55);
    final stroke = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(data, style: stroke, textAlign: textAlign, maxLines: maxLines, overflow: overflow),
        fill,
      ],
    );
  }
}
