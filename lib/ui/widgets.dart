import 'package:flutter/material.dart';

import 'theme.dart';

class PongButton extends StatelessWidget {
  const PongButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.width = 230,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: PongColors.player,
                foregroundColor: PongColors.background,
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: mono(size: 15, color: PongColors.background)),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: PongColors.foreground,
                side: BorderSide(color: PongColors.muted.withValues(alpha: 0.6)),
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: mono(size: 15)),
            ),
    );
  }
}

/// Full-screen scrim with a centred column, used for pause and end of match.
class DimmedPanel extends StatelessWidget {
  const DimmedPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: PongColors.background.withValues(alpha: 0.88),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of mutually exclusive chips, monospaced to match the rest of the game.
class PongChoice<T> extends StatelessWidget {
  const PongChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: value == selected
                    ? PongColors.player.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: value == selected
                      ? PongColors.player
                      : PongColors.muted.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                labelOf(value),
                style: mono(
                  size: 12,
                  color: value == selected
                      ? PongColors.player
                      : PongColors.muted,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
