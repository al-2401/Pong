import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pong/engine/engine.dart';
import 'package:pong/engine/game_rules.dart';
import 'package:pong/engine/game_state.dart';
import 'package:pong/engine/paddle_motion.dart';

void main() {
  const dt = GameEngine.fixedStep;

  double travelIn(double seconds, GameRules rules, {double target = 1.0}) {
    final paddle = PaddleState(x: 0.5, width: rules.paddleWidth);
    for (var t = 0.0; t < seconds; t += dt) {
      PaddleMotion.apply(paddle, target, dt, rules);
    }
    return paddle.x;
  }

  test('a light paddle covers more ground than a heavy one', () {
    const light = GameRules(fieldLength: 1.8, paddleInertia: 0.0);
    const heavy = GameRules(fieldLength: 1.8, paddleInertia: 1.0);
    expect(travelIn(0.12, light), greaterThan(travelIn(0.12, heavy)));
  });

  test('a light paddle reaches the speed cap, a heavy one runs out of field', () {
    double topSpeedReached(GameRules rules) {
      final paddle = PaddleState(x: 0.5, width: rules.paddleWidth);
      var peak = 0.0;
      for (var t = 0.0; t < 3.0; t += dt) {
        PaddleMotion.apply(paddle, t % 1.0 < 0.5 ? 1.0 : 0.0, dt, rules);
        peak = math.max(peak, paddle.velocity.abs());
      }
      return peak;
    }

    const light = GameRules(fieldLength: 1.8, paddleInertia: 0.0);
    const heavy = GameRules(fieldLength: 1.8, paddleInertia: 1.0);

    expect(topSpeedReached(light), closeTo(light.maxPaddleSpeed, 1e-6));

    // A heavy paddle cannot get up to the cap and still stop inside the field.
    // It must stay well clear of feeling sluggish all the same.
    final heavyPeak = topSpeedReached(heavy);
    expect(heavyPeak, lessThan(heavy.maxPaddleSpeed));
    expect(heavyPeak, greaterThan(heavy.maxPaddleSpeed * 0.6));
  });

  test('the paddle never leaves the field', () {
    const rules = GameRules(fieldLength: 1.8, paddleInertia: 0.8);
    final paddle = PaddleState(x: 0.5, width: rules.paddleWidth);
    for (var i = 0; i < 2000; i++) {
      final target = i % 200 < 100 ? -5.0 : 5.0;
      PaddleMotion.apply(paddle, target, dt, rules);
      expect(paddle.x, greaterThanOrEqualTo(paddle.halfWidth - 1e-9));
      expect(paddle.x, lessThanOrEqualTo(1 - paddle.halfWidth + 1e-9));
    }
  });

  test('the paddle never exceeds the rules top speed', () {
    const rules = GameRules(fieldLength: 1.8, paddleInertia: 0.0);
    final paddle = PaddleState(x: 0.5, width: rules.paddleWidth);
    for (var i = 0; i < 500; i++) {
      PaddleMotion.apply(paddle, i.isEven ? 0.0 : 1.0, dt, rules);
      expect(paddle.velocity.abs(), lessThanOrEqualTo(rules.maxPaddleSpeed + 1e-9));
    }
  });

  test('the paddle settles on the edge and stops', () {
    const rules = GameRules(fieldLength: 1.8, paddleInertia: 0.3);
    final paddle = PaddleState(x: 0.5, width: rules.paddleWidth);
    for (var i = 0; i < 500; i++) {
      PaddleMotion.apply(paddle, 0.0, dt, rules);
    }
    expect(paddle.x, closeTo(paddle.halfWidth, 1e-6));
    expect(paddle.velocity.abs(), lessThan(1e-6));
  });

  test('a paddle carrying speed into the edge is stopped dead', () {
    const rules = GameRules(fieldLength: 1.8, paddleInertia: 0.3);
    final paddle = PaddleState(x: 0.86, width: rules.paddleWidth)
      ..velocity = 10.0;

    PaddleMotion.apply(paddle, 1.0, dt, rules);

    expect(paddle.x, closeTo(1 - paddle.halfWidth, 1e-12));
    expect(paddle.velocity, 0);
  });
}
