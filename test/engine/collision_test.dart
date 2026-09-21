import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pong/engine/engine.dart';
import 'package:pong/engine/game_rules.dart';
import 'package:pong/engine/game_state.dart';

void main() {
  const dt = GameEngine.fixedStep;

  GameEngine liveEngine(GameRules rules, {int seed = 1}) {
    final engine = GameEngine(rules: rules, random: math.Random(seed));
    engine.state.phase = MatchPhase.rally;
    return engine;
  }

  test('a very fast ball does not tunnel through a paddle', () {
    // 0.05 s to cross the field is far faster than the game ever gets; at this
    // speed the ball covers several paddle thicknesses per tick.
    const rules = GameRules(fieldLength: 2.0, ballCrossTime: 0.05);
    final engine = liveEngine(rules);
    final state = engine.state;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = rules.baseBallSpeed;

    for (var i = 0; i < 60; i++) {
      engine.step(dt, 0.5, 0.5);
    }

    expect(state.bottomScore + state.topScore, 0,
        reason: 'the ball went through a paddle instead of bouncing');
    expect(state.rallyHits, greaterThan(1));
  });

  test('a centred hit sends the ball straight back', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = liveEngine(rules);
    final state = engine.state;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = rules.baseBallSpeed;

    while (state.rallyHits == 0) {
      engine.step(dt, 0.5, 0.5);
    }

    expect(state.ball.vx.abs(), lessThan(1e-9));
    expect(state.ball.vy, lessThan(0));
  });

  test('hitting with the edge of the paddle deflects the ball sideways', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = liveEngine(rules);
    final state = engine.state;
    // Paddle parked to the left of the ball, so contact is near its right end.
    state.bottom.x = 0.5 - state.bottom.halfWidth;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = rules.baseBallSpeed;

    final target = state.bottom.x;
    while (state.rallyHits == 0) {
      engine.step(dt, target, 0.5);
    }

    expect(state.ball.vx, greaterThan(0.1));
    expect(state.ball.vy, lessThan(0));
  });

  test('side walls reflect the ball and preserve its speed', () {
    const rules = GameRules(fieldLength: 2.0);
    final engine = liveEngine(rules);
    final state = engine.state;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = rules.baseBallSpeed
      ..vy = 0;
    final speed = state.ball.speed;

    for (var i = 0; i < 2000; i++) {
      engine.step(dt, 0.5, 0.5);
      expect(state.ball.x, greaterThanOrEqualTo(rules.ballRadius - 1e-9));
      expect(state.ball.x, lessThanOrEqualTo(1 - rules.ballRadius + 1e-9));
      expect(state.ball.speed, closeTo(speed, 1e-9));
    }
  });

  test('the ball accelerates on every hit and stops at the cap', () {
    const rules = GameRules(
      fieldLength: 2.0,
      ballCrossTime: 1.0,
      ballAccelPerHit: 1.2,
      ballMaxSpeedFactor: 1.8,
    );
    final engine = liveEngine(rules);
    final state = engine.state;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = rules.baseBallSpeed;

    var previous = state.ball.speed;
    var hits = 0;
    for (var i = 0; i < 4000 && hits < 2; i++) {
      engine.step(dt, 0.5, 0.5);
      if (state.rallyHits > hits) {
        hits = state.rallyHits;
        expect(state.ball.speed, greaterThan(previous));
        previous = state.ball.speed;
      }
    }
    expect(hits, 2);

    for (var i = 0; i < 4000; i++) {
      engine.step(dt, 0.5, 0.5);
      expect(state.ball.speed, lessThanOrEqualTo(rules.maxBallSpeed + 1e-9));
    }
    expect(state.ball.speed, closeTo(rules.maxBallSpeed, 1e-9));
  });

  test('a moving paddle puts spin on the ball', () {
    // maxBounceAngle is switched off, so the only thing that can bend the
    // ball here is the paddle's own movement.
    const rules = GameRules(
      fieldLength: 2.0,
      paddleInertia: 0.0,
      maxBounceAngle: 0.0,
    );

    double returnVxWithTarget(double startX, double target) {
      final engine = liveEngine(rules);
      final state = engine.state;
      state.bottom.x = startX;
      state.ball
        ..x = 0.5
        ..y = rules.fieldLength - 0.10
        ..vx = 0
        ..vy = rules.baseBallSpeed;
      while (state.rallyHits == 0) {
        engine.step(dt, target, 0.5);
      }
      return state.ball.vx;
    }

    expect(returnVxWithTarget(0.5, 0.5), closeTo(0, 1e-9));
    expect(returnVxWithTarget(0.44, 1.0), greaterThan(0.1));
    expect(returnVxWithTarget(0.56, 0.0), lessThan(-0.1));
  });

  test('the ball stays inside the field for a long AI-free rally', () {
    const rules = GameRules(fieldLength: 2.2, ballCrossTime: 0.6);
    final engine = liveEngine(rules);
    final state = engine.state;
    state.ball
      ..x = 0.42
      ..y = rules.fieldLength / 2
      ..vx = rules.baseBallSpeed * 0.4
      ..vy = rules.baseBallSpeed * 0.9;

    for (var i = 0; i < 6000; i++) {
      engine.step(dt, state.ball.x, state.ball.x);
      expect(state.ball.x.isFinite, isTrue);
      expect(state.ball.y.isFinite, isTrue);
      expect(state.ball.x, greaterThanOrEqualTo(rules.ballRadius - 1e-9));
      expect(state.ball.x, lessThanOrEqualTo(1 - rules.ballRadius + 1e-9));
    }
  });
}
