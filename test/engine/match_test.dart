import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pong/engine/engine.dart';
import 'package:pong/engine/game_rules.dart';
import 'package:pong/engine/game_state.dart';

void main() {
  const dt = GameEngine.fixedStep;
  const rules = GameRules(fieldLength: 2.0, pointsToWin: 3);

  GameEngine freshEngine() => GameEngine(rules: rules, random: math.Random(7));

  void run(GameEngine engine, double seconds) {
    for (var t = 0.0; t < seconds; t += dt) {
      engine.step(dt, engine.state.bottom.x, engine.state.top.x);
    }
  }

  test('a match opens with a countdown and a parked ball', () {
    final engine = freshEngine();
    expect(engine.state.phase, MatchPhase.serving);
    expect(engine.state.countdown, rules.serveCountdown);
    expect(engine.state.ball.speed, 0);
  });

  test('the ball is launched once the countdown runs out', () {
    final engine = freshEngine();
    run(engine, rules.serveCountdown + 0.05);
    expect(engine.state.phase, MatchPhase.rally);
    expect(engine.state.ball.speed, closeTo(rules.baseBallSpeed, 1e-9));
  });

  test('the serve travels away from the server', () {
    final engine = freshEngine();
    engine.state.server = FieldSide.bottom;
    run(engine, rules.serveCountdown + 0.05);
    expect(engine.state.ball.vy, lessThan(0), reason: 'should fly to the top');

    final other = freshEngine();
    other.state.server = FieldSide.top;
    run(other, rules.serveCountdown + 0.05);
    expect(other.state.ball.vy, greaterThan(0));
  });

  test('a ball past the near paddle scores for the far side', () {
    final engine = freshEngine();
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength + 0.2
      ..vx = 0
      ..vy = 1.0;

    engine.step(dt, 0.5, 0.5);

    expect(state.topScore, 1);
    expect(state.bottomScore, 0);
    expect(state.phase, MatchPhase.pointScored);
  });

  test('the loser of a point serves the next one', () {
    final engine = freshEngine();
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..y = -0.2
      ..vy = -1.0;

    engine.step(dt, 0.5, 0.5);

    expect(state.bottomScore, 1);
    expect(state.server, FieldSide.top);
  });

  test('a point is followed by a pause and then a fresh countdown', () {
    final engine = freshEngine();
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..y = -0.2
      ..vy = -1.0;
    engine.step(dt, 0.5, 0.5);
    expect(state.phase, MatchPhase.pointScored);

    run(engine, rules.pointPause + 0.05);
    expect(state.phase, MatchPhase.serving);
    expect(state.countdown, closeTo(rules.serveCountdown, 0.05));
    expect(state.rallyHits, 0);
  });

  test('the match ends at pointsToWin', () {
    final engine = freshEngine();
    final state = engine.state;
    state.bottomScore = rules.pointsToWin - 1;
    state.phase = MatchPhase.rally;
    state.ball
      ..y = -0.2
      ..vy = -1.0;

    final events = engine.step(dt, 0.5, 0.5);

    expect(state.phase, MatchPhase.matchOver);
    expect(state.matchWinner, FieldSide.bottom);
    expect(
      events.any((e) => e.type == GameEventType.matchOver),
      isTrue,
    );
  });

  test('a finished match stops simulating', () {
    final engine = freshEngine();
    final state = engine.state;
    state.phase = MatchPhase.matchOver;
    state.ball
      ..x = 0.5
      ..y = 1.0
      ..vx = 1.0
      ..vy = 1.0;

    run(engine, 1.0);

    expect(state.ball.y, 1.0);
  });

  test('the longest rally of the match is remembered', () {
    final engine = freshEngine();
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = rules.baseBallSpeed;

    run(engine, 6.0);
    expect(state.longestRally, greaterThan(2));
  });

  test('paddle shrinking is capped and resets on the next serve', () {
    const shrinking = GameRules(
      fieldLength: 2.0,
      ballCrossTime: 0.3,
      paddleShrinkPerHit: 0.9,
      paddleMinWidth: 0.12,
    );
    final engine = GameEngine(rules: shrinking, random: math.Random(3));
    final state = engine.state;
    state.phase = MatchPhase.rally;
    state.ball
      ..x = 0.5
      ..y = shrinking.fieldLength / 2
      ..vx = 0
      ..vy = shrinking.baseBallSpeed;

    for (var t = 0.0; t < 5.0; t += dt) {
      engine.step(dt, 0.5, 0.5);
      expect(state.bottom.width, greaterThanOrEqualTo(shrinking.paddleMinWidth - 1e-9));
    }
    expect(state.bottom.width, lessThan(shrinking.paddleWidth));

    engine.beginServe();
    expect(state.bottom.width, shrinking.paddleWidth);
    expect(state.top.width, shrinking.paddleWidth);
  });

  test('rules survive a JSON round trip', () {
    const original = GameRules(
      fieldLength: 2.17,
      paddleInertia: 0.62,
      ballAccelPerHit: 1.041,
      pointsToWin: 7,
    );
    final copy = GameRules.fromJson(original.toJson());
    expect(copy.fieldLength, original.fieldLength);
    expect(copy.paddleInertia, original.paddleInertia);
    expect(copy.ballAccelPerHit, original.ballAccelPerHit);
    expect(copy.pointsToWin, original.pointsToWin);
    expect(copy.toJson(), original.toJson());
  });
}
