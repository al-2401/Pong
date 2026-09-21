import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pong/engine/ai_controller.dart';
import 'package:pong/engine/difficulty.dart';
import 'package:pong/engine/engine.dart';
import 'package:pong/engine/game_rules.dart';
import 'package:pong/engine/game_state.dart';
import 'package:pong/engine/match_runner.dart';

void main() {
  const dt = GameEngine.fixedStep;
  const perfect = AiProfile(reactionDelay: 0, aimError: 0);

  group('foldIntoRange', () {
    test('leaves a value that is already inside alone', () {
      expect(AiPaddleController.foldIntoRange(0.4, 0.0, 1.0), closeTo(0.4, 1e-12));
    });

    test('mirrors a value that overshoots the far edge', () {
      expect(AiPaddleController.foldIntoRange(1.3, 0.0, 1.0), closeTo(0.7, 1e-12));
    });

    test('mirrors a value that undershoots the near edge', () {
      expect(AiPaddleController.foldIntoRange(-0.3, 0.0, 1.0), closeTo(0.3, 1e-12));
    });

    test('handles several reflections', () {
      expect(AiPaddleController.foldIntoRange(3.2, 0.0, 1.0), closeTo(0.8, 1e-12));
      expect(AiPaddleController.foldIntoRange(-2.4, 0.0, 1.0), closeTo(0.4, 1e-12));
    });

    test('works on an offset range', () {
      expect(AiPaddleController.foldIntoRange(1.1, 0.1, 0.9), closeTo(0.7, 1e-12));
    });
  });

  test('the AI predicts where the ball lands, wall bounces included', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = GameEngine(rules: rules, random: math.Random(5));
    final state = engine.state;
    state.phase = MatchPhase.rally;
    // Shrink the opponent paddle to a sliver parked in a corner so the ball
    // flies all the way to the back line untouched.
    state.top.width = 0.001;
    state.top.x = 0.05;
    state.ball
      ..x = 0.5
      ..y = 1.5
      ..vx = rules.baseBallSpeed * 0.45
      ..vy = -rules.baseBallSpeed * 0.9;

    final ai = AiPaddleController(side: FieldSide.top, profile: perfect);
    final predicted = ai.update(state, dt);

    final face = rules.paddleThickness + rules.ballRadius;
    double? landing;
    for (var i = 0; i < 4000 && landing == null; i++) {
      engine.step(dt, 0.5, 0.05);
      if (state.ball.y <= face) landing = state.ball.x;
    }

    expect(landing, isNotNull);
    expect(predicted, closeTo(landing!, 0.02));
  });

  test('a flawless AI on both ends never concedes a point', () {
    const rules = GameRules(
      fieldLength: 2.0,
      ballCrossTime: 1.4,
      ballAccelPerHit: 1.0,
    );
    final engine = GameEngine(rules: rules, random: math.Random(11));
    final runner = MatchRunner(
      engine: engine,
      bottom: AiPaddleController(side: FieldSide.bottom, profile: perfect),
      top: AiPaddleController(side: FieldSide.top, profile: perfect),
    );

    for (var t = 0.0; t < 25.0; t += 1 / 60) {
      runner.advance(1 / 60);
    }

    expect(engine.state.bottomScore, 0);
    expect(engine.state.topScore, 0);
    expect(engine.state.rallyHits, greaterThan(5));
  });

  test('reaction delay holds the AI on its previous target', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = GameEngine(rules: rules, random: math.Random(5));
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..x = 0.5
      ..y = 1.5
      ..vx = rules.baseBallSpeed * 0.45
      ..vy = -rules.baseBallSpeed * 0.9;

    final ai = AiPaddleController(
      side: FieldSide.top,
      profile: const AiProfile(reactionDelay: 0.3, aimError: 0),
    );

    expect(ai.update(state, dt), closeTo(0.5, 1e-9));

    var target = 0.5;
    for (var t = 0.0; t < 0.29; t += dt) {
      target = ai.update(state, dt);
    }
    expect(target, closeTo(0.5, 1e-9), reason: 'should still be reacting');

    for (var t = 0.0; t < 0.05; t += dt) {
      target = ai.update(state, dt);
    }
    expect((target - 0.5).abs(), greaterThan(0.05));
  });

  test('a short-sighted AI ignores the ball until it crosses midfield', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = GameEngine(rules: rules, random: math.Random(5));
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..x = 0.5
      ..y = 1.8
      ..vx = rules.baseBallSpeed * 0.45
      ..vy = -rules.baseBallSpeed * 0.9;

    final ai = AiPaddleController(
      side: FieldSide.top,
      profile: const AiProfile(reactionDelay: 0, aimError: 0, trackEarly: false),
    );

    expect(ai.update(state, dt), closeTo(0.5, 1e-9));

    state.ball.y = 0.9; // now past the middle
    expect((ai.update(state, dt) - 0.5).abs(), greaterThan(0.05));
  });

  test('a sharper profile beats a blunter one over a match', () {
    // Same rules on both ends, so the only difference is the opponent model.
    final rules = DifficultyPreset.of(Difficulty.normal).rulesFor(
      fieldLength: 2.0,
      paddleInertia: 0.35,
      pointsToWin: 7,
    );
    final engine = GameEngine(rules: rules, random: math.Random(19));
    final runner = MatchRunner(
      engine: engine,
      bottom: AiPaddleController(
        side: FieldSide.bottom,
        profile: DifficultyPreset.of(Difficulty.rookie).ai,
        random: math.Random(2),
      ),
      top: AiPaddleController(
        side: FieldSide.top,
        profile: DifficultyPreset.of(Difficulty.insane).ai,
        random: math.Random(3),
      ),
    );

    for (var t = 0.0; t < 300.0; t += 1 / 60) {
      runner.advance(1 / 60);
      if (engine.state.phase == MatchPhase.matchOver) break;
    }

    expect(engine.state.matchWinner, FieldSide.top);
  });

  test('difficulty presets get sharper as they go up', () {
    const order = [
      Difficulty.rookie,
      Difficulty.normal,
      Difficulty.hard,
      Difficulty.insane,
    ];
    for (var i = 1; i < order.length; i++) {
      final easier = DifficultyPreset.of(order[i - 1]);
      final harder = DifficultyPreset.of(order[i]);
      expect(harder.ai.reactionDelay, lessThan(easier.ai.reactionDelay));
      expect(harder.ai.aimError, lessThan(easier.ai.aimError));
      expect(harder.template.ballCrossTime, lessThan(easier.template.ballCrossTime));
      expect(harder.template.paddleWidth, lessThanOrEqualTo(easier.template.paddleWidth));
    }
  });

  test('a preset keeps the screen shape and the player inertia', () {
    final rules = DifficultyPreset.of(Difficulty.hard).rulesFor(
      fieldLength: 2.17,
      paddleInertia: 0.8,
      pointsToWin: 7,
    );
    expect(rules.fieldLength, 2.17);
    expect(rules.paddleInertia, 0.8);
    expect(rules.pointsToWin, 7);
    expect(rules.ballAccelPerHit,
        DifficultyPreset.of(Difficulty.hard).template.ballAccelPerHit);
  });
}
