import 'package:flutter/material.dart';

import '../settings/preferences.dart';
import 'labels.dart';
import 'pong_scope.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PongScope.of(context);
    final preferences = scope.preferences;

    return Scaffold(
      backgroundColor: PongColors.background,
      appBar: AppBar(
        backgroundColor: PongColors.background,
        foregroundColor: PongColors.foreground,
        title: Text('НАСТРОЙКИ', style: mono(size: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: preferences,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _Section(
                  title: 'ИНЕРТНОСТЬ РАКЕТКИ',
                  hint: 'Насколько тяжело ракетка разгоняется и тормозит. '
                      'Тяжёлой сложнее управлять, но её движение сильнее '
                      'подкручивает мяч.',
                  child: Column(
                    children: [
                      Slider(
                        value: preferences.paddleInertia,
                        onChanged: (value) => preferences.paddleInertia = value,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ЛЁГКАЯ', style: _caption),
                          Text(
                            preferences.paddleInertia.toStringAsFixed(2),
                            style: mono(size: 12, color: PongColors.player),
                          ),
                          Text('ТЯЖЁЛАЯ', style: _caption),
                        ],
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'ОРИЕНТАЦИЯ',
                  hint: 'Поле всегда вытянуто вдоль длинной стороны экрана, '
                      'поэтому поворот ничего не меняет в игре. Выбранная '
                      'ориентация фиксируется на время матча.',
                  child: PongChoice<FieldOrientation>(
                    values: FieldOrientation.values,
                    selected: preferences.orientation,
                    labelOf: (value) => value.title,
                    onChanged: (value) => preferences.orientation = value,
                  ),
                ),
                _Toggle(
                  title: 'СПИДОМЕТР',
                  hint: 'Полоса у левой стены показывает, насколько разогнался мяч',
                  value: preferences.speedMeter,
                  onChanged: (value) => preferences.speedMeter = value,
                ),
                _Toggle(
                  title: 'ЗВУК',
                  value: preferences.sound,
                  onChanged: (value) {
                    preferences.sound = value;
                    scope.sound.enabled = value;
                  },
                ),
                _Toggle(
                  title: 'ВИБРАЦИЯ',
                  value: preferences.haptics,
                  onChanged: (value) => preferences.haptics = value,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

TextStyle get _caption => mono(
      size: 10,
      color: PongColors.muted,
      weight: FontWeight.w400,
      letterSpacing: 1.4,
    );

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: mono(size: 13, letterSpacing: 2.4)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: mono(
                size: 11,
                color: PongColors.muted,
                weight: FontWeight.w400,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: mono(size: 13, letterSpacing: 2.4)),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: mono(
                      size: 11,
                      color: PongColors.muted,
                      weight: FontWeight.w400,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
