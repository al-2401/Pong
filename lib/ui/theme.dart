import 'package:flutter/material.dart';

/// A deliberately thin palette: the whole game is two paddles, a ball and a
/// few numbers, and it reads best when it stays close to the black-and-white
/// original. Colour is used only to tell the two ends of the field apart.
class PongColors {
  const PongColors._();

  static const Color background = Color(0xFF07080A);
  static const Color surface = Color(0xFF101318);
  static const Color foreground = Color(0xFFE9F1EC);
  static const Color muted = Color(0xFF6F7A80);
  static const Color player = Color(0xFF6BE8A8);
  static const Color opponent = Color(0xFFF2B45C);
  static const Color ball = Color(0xFFF4F8F6);
}

const List<String> kMonoFallback = <String>[
  'monospace',
  'Menlo',
  'Courier New',
  'Roboto Mono',
];

TextStyle mono({
  required double size,
  Color color = PongColors.foreground,
  FontWeight weight = FontWeight.w600,
  double letterSpacing = 2,
}) {
  return TextStyle(
    fontFamilyFallback: kMonoFallback,
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1.2,
  );
}

ThemeData buildPongTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PongColors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: PongColors.surface,
      primary: PongColors.player,
      secondary: PongColors.opponent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: PongColors.player,
      thumbColor: PongColors.player,
      inactiveTrackColor: PongColors.muted.withValues(alpha: 0.4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PongColors.player
            : PongColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PongColors.player.withValues(alpha: 0.35)
            : PongColors.surface,
      ),
    ),
  );
}
