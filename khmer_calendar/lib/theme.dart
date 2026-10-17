import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ColorSchemeId {
  rose,
  purple,
  slate,
  teal,
  green,
  violet,
  magenta,
  burgundy,
  brown,
  amber,
  forest,
  olive,
  navy,
  coral,
}

class SchemeChip {
  const SchemeChip(this.id, this.label, this.circle, this.hue, this.top, this.bot);
  final ColorSchemeId id;
  final String label;
  final Color circle;
  final double hue;
  final Color top;
  final Color bot;
}

Color hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

double _jsMod(double a, double n) => a - (a / n).truncateToDouble() * n;

double hueFromHex(String hex) {
  final t = hex.replaceFirst('#', '').padRight(6, '0');
  final n = int.parse(t.substring(0, 6), radix: 16);
  final r = ((n >> 16) & 255) / 255.0;
  final g = ((n >> 8) & 255) / 255.0;
  final b = (n & 255) / 255.0;
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  if (max == min) return 0;
  final c = max - min;
  double h;
  if (max == r) {
    h = _jsMod((g - b) / c, 6);
  } else if (max == g) {
    h = (b - r) / c + 2;
  } else {
    h = (r - g) / c + 4;
  }
  h *= 60;
  return h < 0 ? h + 360 : h;
}

String py(double h, double s, double l) {
  final sat = s / 100;
  final lit = l / 100;
  final a = sat * math.min(lit, 1 - lit);
  String f(double n) {
    final k = (n + h / 30) % 12;
    final v = lit - a * math.max(math.min(math.min(k - 3, 9 - k), 1.0), -1.0);
    return (255 * v).round().toRadixString(16).padLeft(2, '0');
  }
  return '#${f(0)}${f(8)}${f(4)}';
}

String hueHex(double hue) {
  final t = ((hue % 360) + 360) % 360;
  String ch(double e) {
    final n = (e + t / 30) % 12;
    final r = 0.54 - 0.414 * math.max(math.min(math.min(n - 3, 9 - n), 1.0), -1.0);
    return (255 * r).round().toRadixString(16).padLeft(2, '0');
  }
  return '#${ch(0)}${ch(8)}${ch(4)}'.toUpperCase();
}

SchemeChip _chip(ColorSchemeId id, String label, String circleHex) {
  final hue = hueFromHex(circleHex);
  return SchemeChip(
    id,
    label,
    hexColor(circleHex),
    hue,
    hexColor(py(hue, 16, 94)),
    hexColor(py((hue + 16) % 360, 34, 80)),
  );
}

final schemes = <SchemeChip>[
  _chip(ColorSchemeId.rose, 'ក្រហម', '#9a3b38'),
  _chip(ColorSchemeId.purple, 'ស្វាយ', '#68509f'),
  _chip(ColorSchemeId.slate, 'ខៀវ', '#38618d'),
  _chip(ColorSchemeId.teal, 'បៃតងខៀវ', '#146781'),
  _chip(ColorSchemeId.green, 'បៃតង', '#036a62'),
  _chip(ColorSchemeId.violet, 'វីយ៉ូឡែត', '#68548e'),
  _chip(ColorSchemeId.magenta, 'ផ្កាឈូក', '#7c4e7e'),
  _chip(ColorSchemeId.burgundy, 'ក្រហមចាស់', '#8c4a61'),
  _chip(ColorSchemeId.brown, 'ត្នោត', '#8e4d33'),
  _chip(ColorSchemeId.amber, 'ទឹកក្រូច', '#84541a'),
  _chip(ColorSchemeId.forest, 'ព្រៃ', '#40693f'),
  _chip(ColorSchemeId.olive, 'អូលីវ', '#586424'),
  _chip(ColorSchemeId.navy, 'ទឹកប៊ិច', '#3d4c7a'),
  _chip(ColorSchemeId.coral, 'ថ្មប៉ប្រះទឹក', '#c45c4a'),
];

SchemeChip schemeOf(ColorSchemeId id) => schemes.firstWhere((s) => s.id == id, orElse: () => schemes.first);

const _roseLight = <String, String>{
  'primary': '#9a3b38',
  'onPrimary': '#ffffff',
  'primaryContainer': '#ffdad6',
  'onPrimaryContainer': '#410003',
  'secondary': '#775652',
  'onSecondary': '#ffffff',
  'secondaryContainer': '#ffdad6',
  'onSecondaryContainer': '#2c1512',
  'tertiary': '#1b7a6e',
  'onTertiary': '#ffffff',
  'tertiaryContainer': '#c5ebe3',
  'onTertiaryContainer': '#00201c',
  'surface': '#fffbff',
  'onSurface': '#2b1b1a',
  'surfaceVariant': '#f5ddda',
  'onSurfaceVariant': '#5d403c',
  'surfaceContainerLowest': '#ffffff',
  'surfaceContainerLow': '#fff1ef',
  'surfaceContainer': '#f8edeb',
  'surfaceContainerHigh': '#f3e7e5',
  'surfaceContainerHighest': '#ede0de',
  'outline': '#926f6b',
  'outlineVariant': '#e7beba',
  'inverseSurface': '#412e2c',
  'onInverseSurface': '#fceeea',
  'inversePrimary': '#ffb3ad',
};

const _roseDark = <String, String>{
  'primary': '#ffb3ad',
  'onPrimary': '#5f1413',
  'primaryContainer': '#7c2a27',
  'onPrimaryContainer': '#ffdad6',
  'secondary': '#e7bdb7',
  'onSecondary': '#442926',
  'secondaryContainer': '#5d3f3b',
  'onSecondaryContainer': '#ffdad6',
  'tertiary': '#a9cfc7',
  'onTertiary': '#003731',
  'tertiaryContainer': '#0b534a',
  'onTertiaryContainer': '#c5ebe3',
  'surface': '#1c1110',
  'onSurface': '#f6ddda',
  'surfaceVariant': '#5d403c',
  'onSurfaceVariant': '#e7beba',
  'surfaceContainerLowest': '#160c0b',
  'surfaceContainerLow': '#251817',
  'surfaceContainer': '#2a1c1b',
  'surfaceContainerHigh': '#352625',
  'surfaceContainerHighest': '#41312f',
  'outline': '#ad8985',
  'outlineVariant': '#5d403c',
  'inverseSurface': '#f6ddda',
  'onInverseSurface': '#412e2c',
  'inversePrimary': '#9a3b38',
};

Map<String, String> _cy(String hex, double hue, bool dark) {
  final i = (hue + 145) % 360;
  if (dark) {
    return {
      'primary': py(hue, 72, 82),
      'onPrimary': py(hue, 40, 18),
      'primaryContainer': py(hue, 32, 28),
      'onPrimaryContainer': py(hue, 78, 90),
      'secondary': py(hue, 28, 80),
      'onSecondary': py(hue, 22, 18),
      'secondaryContainer': py(hue, 18, 26),
      'onSecondaryContainer': py(hue, 50, 90),
      'tertiary': py(i, 42, 78),
      'onTertiary': py(i, 40, 14),
      'tertiaryContainer': py(i, 28, 22),
      'onTertiaryContainer': py(i, 50, 88),
      'surface': py(hue, 14, 10),
      'onSurface': py(hue, 22, 92),
      'surfaceVariant': py(hue, 14, 28),
      'onSurfaceVariant': py(hue, 18, 78),
      'surfaceContainerLowest': py(hue, 16, 7),
      'surfaceContainerLow': py(hue, 12, 13),
      'surfaceContainer': py(hue, 12, 16),
      'surfaceContainerHigh': py(hue, 12, 20),
      'surfaceContainerHighest': py(hue, 12, 24),
      'outline': py(hue, 14, 60),
      'outlineVariant': py(hue, 14, 28),
      'inverseSurface': py(hue, 22, 92),
      'onInverseSurface': py(hue, 18, 22),
      'inversePrimary': hex,
    };
  }
  return {
    'primary': hex,
    'onPrimary': '#ffffff',
    'primaryContainer': py(hue, 82, 90),
    'onPrimaryContainer': py(hue, 42, 16),
    'secondary': py(hue, 22, 40),
    'onSecondary': '#ffffff',
    'secondaryContainer': py(hue, 48, 90),
    'onSecondaryContainer': py(hue, 26, 16),
    'tertiary': py(i, 48, 32),
    'onTertiary': '#ffffff',
    'tertiaryContainer': py(i, 50, 88),
    'onTertiaryContainer': py(i, 40, 12),
    'surface': py(hue, 40, 99),
    'onSurface': py(hue, 18, 14),
    'surfaceVariant': py(hue, 28, 90),
    'onSurfaceVariant': py(hue, 16, 32),
    'surfaceContainerLowest': '#ffffff',
    'surfaceContainerLow': py(hue, 50, 96.5),
    'surfaceContainer': py(hue, 36, 94),
    'surfaceContainerHigh': py(hue, 30, 92),
    'surfaceContainerHighest': py(hue, 24, 90),
    'outline': py(hue, 16, 50),
    'outlineVariant': py(hue, 22, 80),
    'inverseSurface': py(hue, 18, 22),
    'onInverseSurface': py(hue, 30, 94),
    'inversePrimary': py(hue, 70, 80),
  };
}

Map<String, String> _wy(Map<String, String> tokens, double hue) {
  return {
    ...tokens,
    'surface': '#000000',
    'surfaceContainerLowest': '#000000',
    'surfaceContainerLow': py(hue, 10, 5),
    'surfaceContainer': py(hue, 10, 8),
    'surfaceContainerHigh': py(hue, 10, 12),
    'surfaceContainerHighest': py(hue, 10, 16),
  };
}

Map<String, String> schemeTokens(ColorSchemeId id, Brightness brightness, bool extraDark) {
  final scheme = schemeOf(id);
  final dark = brightness == Brightness.dark;
  final hex = '#${scheme.circle.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  var base = id == ColorSchemeId.rose
      ? Map<String, String>.from(dark ? _roseDark : _roseLight)
      : _cy(hex, scheme.hue, dark);
  if (extraDark && dark) base = _wy(base, scheme.hue);
  return base;
}

ColorScheme colorSchemeFromTokens(Map<String, String> tok, Brightness brightness) {
  Color c(String k) => hexColor(tok[k]!);
  return ColorScheme(
    brightness: brightness,
    primary: c('primary'),
    onPrimary: c('onPrimary'),
    primaryContainer: c('primaryContainer'),
    onPrimaryContainer: c('onPrimaryContainer'),
    secondary: c('secondary'),
    onSecondary: c('onSecondary'),
    secondaryContainer: c('secondaryContainer'),
    onSecondaryContainer: c('onSecondaryContainer'),
    tertiary: c('tertiary'),
    onTertiary: c('onTertiary'),
    tertiaryContainer: c('tertiaryContainer'),
    onTertiaryContainer: c('onTertiaryContainer'),
    error: brightness == Brightness.dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
    onError: brightness == Brightness.dark ? const Color(0xFF690005) : const Color(0xFFFFFFFF),
    errorContainer: brightness == Brightness.dark ? const Color(0xFF93000A) : const Color(0xFFFFDAD6),
    onErrorContainer: brightness == Brightness.dark ? const Color(0xFFFFDAD6) : const Color(0xFF410002),
    surface: c('surface'),
    onSurface: c('onSurface'),
    surfaceContainerLowest: c('surfaceContainerLowest'),
    surfaceContainerLow: c('surfaceContainerLow'),
    surfaceContainer: c('surfaceContainer'),
    surfaceContainerHigh: c('surfaceContainerHigh'),
    surfaceContainerHighest: c('surfaceContainerHighest'),
    onSurfaceVariant: c('onSurfaceVariant'),
    outline: c('outline'),
    outlineVariant: c('outlineVariant'),
    inverseSurface: c('inverseSurface'),
    onInverseSurface: c('onInverseSurface'),
    inversePrimary: c('inversePrimary'),
    surfaceTint: c('primary'),
  );
}

@immutable
class CalColors extends ThemeExtension<CalColors> {
  const CalColors({required this.accent, required this.highlight, required this.highlightAlpha});
  final Color accent;
  final Color highlight;
  final double highlightAlpha;

  @override
  CalColors copyWith({Color? accent, Color? highlight, double? highlightAlpha}) {
    return CalColors(
      accent: accent ?? this.accent,
      highlight: highlight ?? this.highlight,
      highlightAlpha: highlightAlpha ?? this.highlightAlpha,
    );
  }

  @override
  CalColors lerp(ThemeExtension<CalColors>? other, double t) {
    if (other is! CalColors) return this;
    return CalColors(
      accent: Color.lerp(accent, other.accent, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightAlpha: lerpDouble(highlightAlpha, other.highlightAlpha, t)!,
    );
  }
}

ThemeData buildTheme({
  required Brightness brightness,
  required ColorSchemeId scheme,
  required bool extraDark,
  required bool materialYou,
  required bool dynamicColor,
  required String accentColor,
  required String highlightColor,
  required double highlightAlpha,
  ColorScheme? dynamicScheme,
}) {
  final ColorScheme color;
  final CalColors cal;
  if (dynamicColor && dynamicScheme != null) {
    color = dynamicScheme;
    cal = CalColors(
      accent: color.primary,
      highlight: color.primary,
      highlightAlpha: 0,
    );
  } else {
    final schemeId = materialYou ? scheme : ColorSchemeId.rose;
    final tokens = schemeTokens(schemeId, brightness, extraDark);
    color = colorSchemeFromTokens(tokens, brightness);
    cal = CalColors(
      accent: materialYou ? color.primary : hexColor(accentColor),
      highlight: materialYou ? color.primary : hexColor(highlightColor),
      highlightAlpha: materialYou ? 0 : highlightAlpha,
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: color,
    brightness: brightness,
    fontFamily: 'KantumruyPro',
    visualDensity: VisualDensity.standard,
    extensions: [cal],
    scaffoldBackgroundColor: color.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: color.surface,
      foregroundColor: color.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: color.surfaceContainer,
      indicatorColor: color.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final on = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'KantumruyPro',
          fontSize: 12,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: color.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: color.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
  );
}

const silColor = Color(0xFFD4920F);
const religiousColor = Color(0xFF1E88E5);
const religiousColorOnDark = Color(0xFF90CAF9);
const publicHolidayFill = Color(0xFFC62828);
const otherHolidayFill = religiousColor;

const wideBreak = 840.0;
const mediumBreak = 720.0;
const xlBreak = 1180.0;

// Keep in sync with `version:` in pubspec.yaml (test/version_sync_test.dart enforces it).
const appVersion = '1.0.4';
const appBuildNumber = 5;
const appAuthor = 'Moun Sokdara';
const appSourceUrl = 'https://github.com/mounsokdara/Khmer-Calendar';
const appWebsiteUrl = 'https://khmercalendar.pages.dev';

const mitLicenseText = '''MIT License

Copyright (c) 2026 Moun Sokdara

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

Color todayFill(BuildContext context) {
  final cal = Theme.of(context).extension<CalColors>();
  final cs = Theme.of(context).colorScheme;
  if (cal != null && cal.highlightAlpha > 0) {
    return cal.highlight.withValues(alpha: cal.highlightAlpha);
  }
  return cs.primaryContainer;
}

Color todayOnFill(BuildContext context) {
  final cal = Theme.of(context).extension<CalColors>();
  final cs = Theme.of(context).colorScheme;
  if (cal != null && cal.highlightAlpha > 0) {
    return cal.highlight.computeLuminance() < 0.45 ? Colors.white : const Color(0xFF1A1A1A);
  }
  return cs.onPrimaryContainer;
}

/// Today's highlight keeps its own fill colour; the date number keeps its red (public holiday /
/// Sunday) or blue (other observance) colour instead of switching to the highlight text colour.
({Color fill, Color onFill}) todayColors(BuildContext context, String tone) {
  final fill = todayFill(context);
  if (tone == 'sunday' || tone == 'holiday') {
    return (fill: fill, onFill: dayToneColor(context, tone));
  }
  return (fill: fill, onFill: todayOnFill(context));
}

Color dayToneColor(BuildContext context, String tone) {
  final cs = Theme.of(context).colorScheme;
  switch (tone) {
    case 'sunday':
      return publicHolidayFill;
    case 'holiday':
      return Theme.of(context).brightness == Brightness.dark ? religiousColorOnDark : religiousColor;
    case 'sil':
      return silColor;
    case 'event':
      return cs.primary;
    case 'muted':
      return cs.onSurface.withValues(alpha: 0.38);
    default:
      return cs.onSurface;
  }
}

SystemUiOverlayStyle systemBarStyle(ThemeData theme, Color navColor) {
  final dark = theme.brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: navColor,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}
