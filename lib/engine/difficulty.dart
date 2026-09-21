import 'ai_controller.dart';
import 'game_rules.dart';

enum Difficulty { rookie, normal, hard, insane }

/// A difficulty level is a pair: the physical rules of the match and the
/// opponent's profile. Bundling them means "harder" changes the game, not just
/// the opponent — the ball starts faster, accelerates harder and, at the top
/// levels, the paddles shrink as a rally drags on.
class DifficultyPreset {
  const DifficultyPreset({required this.ai, required this.template});

  final AiProfile ai;

  /// [GameRules.fieldLength] here is only a placeholder; the real one comes
  /// from the screen (single player) or from the host (networked match).
  final GameRules template;

  GameRules rulesFor({
    required double fieldLength,
    required double paddleInertia,
    int? pointsToWin,
  }) {
    return template.copyWith(
      fieldLength: fieldLength,
      paddleInertia: paddleInertia,
      pointsToWin: pointsToWin,
    );
  }

  static const Map<Difficulty, DifficultyPreset> presets = {
    Difficulty.rookie: DifficultyPreset(
      ai: AiProfile(reactionDelay: 0.42, aimError: 0.28, trackEarly: false),
      template: GameRules(
        fieldLength: 1.8,
        ballCrossTime: 1.7,
        ballAccelPerHit: 1.0,
        ballMaxSpeedFactor: 1.0,
        paddleWidth: 0.28,
      ),
    ),
    Difficulty.normal: DifficultyPreset(
      ai: AiProfile(reactionDelay: 0.26, aimError: 0.14, aimBias: 0.15),
      template: GameRules(
        fieldLength: 1.8,
        ballCrossTime: 1.3,
        ballAccelPerHit: 1.025,
        ballMaxSpeedFactor: 1.9,
        paddleWidth: 0.22,
      ),
    ),
    Difficulty.hard: DifficultyPreset(
      ai: AiProfile(reactionDelay: 0.16, aimError: 0.07, aimBias: 0.35),
      template: GameRules(
        fieldLength: 1.8,
        ballCrossTime: 1.05,
        ballAccelPerHit: 1.04,
        ballMaxSpeedFactor: 2.4,
        paddleWidth: 0.19,
        paddleShrinkPerHit: 0.99,
        paddleMinWidth: 0.115,
      ),
    ),
    Difficulty.insane: DifficultyPreset(
      ai: AiProfile(reactionDelay: 0.09, aimError: 0.03, aimBias: 0.55),
      template: GameRules(
        fieldLength: 1.8,
        ballCrossTime: 0.85,
        ballAccelPerHit: 1.055,
        ballMaxSpeedFactor: 3.0,
        paddleWidth: 0.165,
        paddleShrinkPerHit: 0.978,
        paddleMinWidth: 0.095,
      ),
    ),
  };

  static DifficultyPreset of(Difficulty difficulty) => presets[difficulty]!;
}
