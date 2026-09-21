import 'package:flutter/material.dart';

import '../engine/difficulty.dart';
import 'game_screen.dart';
import 'labels.dart';
import 'pong_scope.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PongScope.of(context);

    return Scaffold(
      backgroundColor: PongColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([scope.preferences, scope.records]),
          builder: (context, _) {
            final difficulty = scope.preferences.difficulty;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('PONG', style: mono(size: 54, letterSpacing: 14)),
                    const SizedBox(height: 6),
                    Text(
                      'ЛУЧШАЯ СЕРИЯ ${scope.records.bestRally}',
                      style: mono(
                        size: 12,
                        color: PongColors.muted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 44),
                    PongChoice<Difficulty>(
                      values: Difficulty.values,
                      selected: difficulty,
                      labelOf: (value) => value.title,
                      onChanged: (value) => scope.preferences.difficulty = value,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 280,
                      child: Text(
                        difficulty.description,
                        textAlign: TextAlign.center,
                        style: mono(
                          size: 11,
                          color: PongColors.muted,
                          weight: FontWeight.w400,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    PongButton(
                      label: 'ИГРАТЬ',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GameScreen(difficulty: difficulty),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PongButton(
                      label: 'НАСТРОЙКИ',
                      filled: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'МАТЧЕЙ ${scope.records.matchesPlayed}'
                      '  ·  ПОБЕД ${scope.records.totalWins}'
                      '  ·  УДАРОВ ${scope.records.totalHits}',
                      textAlign: TextAlign.center,
                      style: mono(
                        size: 10,
                        color: PongColors.muted.withValues(alpha: 0.7),
                        weight: FontWeight.w400,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
