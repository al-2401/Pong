import 'dart:math' as math;

import 'game_rules.dart';
import 'game_state.dart';
import 'paddle_motion.dart';

enum _ContactKind { wall, bottomPaddle, topPaddle }

/// The whole game, in plain Dart. It knows nothing about Flutter, pixels or
/// screen orientation, which is what makes it testable headlessly and reusable
/// for a networked match later on.
class GameEngine {
  GameEngine({
    required this.rules,
    math.Random? random,
    FieldSide firstServer = FieldSide.bottom,
  })  : _random = random ?? math.Random(),
        state = GameState(rules) {
    resetMatch(firstServer: firstServer);
  }

  /// Simulation step. Fixed on purpose: the physics must not depend on whether
  /// the phone renders at 60 or 120 Hz.
  static const double fixedStep = 1 / 120;

  /// Widest deviation from the field axis a serve can start with.
  static const double serveSpread = 0.6109; // 35 degrees

  final GameRules rules;
  final GameState state;
  final math.Random _random;

  void resetMatch({FieldSide firstServer = FieldSide.bottom}) {
    state.bottomScore = 0;
    state.topScore = 0;
    state.longestRally = 0;
    state.matchWinner = null;
    state.lastPointWinner = null;
    state.server = firstServer;
    state.bottom.x = 0.5;
    state.bottom.velocity = 0;
    state.top.x = 0.5;
    state.top.velocity = 0;
    beginServe();
  }

  void beginServe() {
    state.phase = MatchPhase.serving;
    state.countdown = rules.serveCountdown;
    state.rallyHits = 0;
    state.bottom.width = rules.paddleWidth;
    state.top.width = rules.paddleWidth;
    _parkBall();
  }

  /// Advances the simulation by exactly [dt] seconds and returns whatever
  /// happened during that step, so the UI can react with sound and haptics
  /// without polling the state for changes.
  List<GameEvent> step(double dt, double bottomTargetX, double topTargetX) {
    final events = <GameEvent>[];

    // Paddles keep moving during the countdown, so players can get set.
    PaddleMotion.apply(state.bottom, bottomTargetX, dt, rules);
    PaddleMotion.apply(state.top, topTargetX, dt, rules);

    switch (state.phase) {
      case MatchPhase.serving:
        state.countdown -= dt;
        if (state.countdown <= 0) {
          state.countdown = 0;
          _launchBall();
          state.phase = MatchPhase.rally;
        }
      case MatchPhase.rally:
        _moveBall(dt, events);
      case MatchPhase.pointScored:
        state.countdown -= dt;
        if (state.countdown <= 0) beginServe();
      case MatchPhase.matchOver:
        break;
    }

    return events;
  }

  void _parkBall() {
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = 0
      ..vy = 0;
  }

  void _launchBall() {
    final angle = (_random.nextDouble() * 2 - 1) * serveSpread;
    // The loser of the last point serves, so the ball travels away from them.
    final dirSign = state.server == FieldSide.bottom ? -1.0 : 1.0;
    final speed = rules.baseBallSpeed;
    state.ball
      ..x = 0.5
      ..y = rules.fieldLength / 2
      ..vx = speed * math.sin(angle)
      ..vy = dirSign * speed * math.cos(angle);
  }

  /// Swept integration: instead of moving the ball and asking "is it inside
  /// something?", we solve for the first moment it touches anything within the
  /// step. Without this a fast ball simply teleports through a paddle.
  void _moveBall(double dt, List<GameEvent> events) {
    final ball = state.ball;
    final r = rules.ballRadius;
    final length = rules.fieldLength;

    var remaining = dt;
    var guard = 0;
    while (remaining > 1e-9 && guard++ < 8) {
      var earliest = remaining;
      _ContactKind? contact;

      if (ball.vx < 0) {
        final t = (r - ball.x) / ball.vx;
        if (t >= 0 && t < earliest) {
          earliest = t;
          contact = _ContactKind.wall;
        }
      } else if (ball.vx > 0) {
        final t = ((1 - r) - ball.x) / ball.vx;
        if (t >= 0 && t < earliest) {
          earliest = t;
          contact = _ContactKind.wall;
        }
      }

      // The paddle is treated as static within one 8 ms tick; at the top
      // paddle speed that is a 0.02 unit approximation, far below the ball
      // radius.
      if (ball.vy > 0) {
        final face = length - rules.paddleThickness;
        final t = (face - r - ball.y) / ball.vy;
        if (t >= 0 && t < earliest) {
          final hitX = ball.x + ball.vx * t;
          if ((hitX - state.bottom.x).abs() <= state.bottom.halfWidth + r) {
            earliest = t;
            contact = _ContactKind.bottomPaddle;
          }
        }
      } else if (ball.vy < 0) {
        final face = rules.paddleThickness;
        final t = (face + r - ball.y) / ball.vy;
        if (t >= 0 && t < earliest) {
          final hitX = ball.x + ball.vx * t;
          if ((hitX - state.top.x).abs() <= state.top.halfWidth + r) {
            earliest = t;
            contact = _ContactKind.topPaddle;
          }
        }
      }

      ball.x += ball.vx * earliest;
      ball.y += ball.vy * earliest;
      remaining -= earliest;

      switch (contact) {
        case null:
          remaining = 0;
        case _ContactKind.wall:
          ball.vx = -ball.vx;
          ball.x = ball.x < 0.5 ? r : 1 - r;
          events.add(GameEvent(GameEventType.wallHit, ballSpeed: ball.speed));
        case _ContactKind.bottomPaddle:
          _bounceOffPaddle(FieldSide.bottom, events);
        case _ContactKind.topPaddle:
          _bounceOffPaddle(FieldSide.top, events);
      }
    }

    if (ball.y - r > length) {
      _awardPoint(FieldSide.top, events);
    } else if (ball.y + r < 0) {
      _awardPoint(FieldSide.bottom, events);
    }
  }

  void _bounceOffPaddle(FieldSide side, List<GameEvent> events) {
    final ball = state.ball;
    final paddle = state.paddle(side);
    final r = rules.ballRadius;

    // Where on the paddle the ball landed, -1 at the far left edge, +1 right.
    final span = paddle.halfWidth + r;
    final offset = span <= 0 ? 0.0 : ((ball.x - paddle.x) / span).clamp(-1.0, 1.0);

    // A moving paddle drags the ball sideways. This is what makes inertia a
    // tactical choice rather than just a handicap.
    final spin = (paddle.velocity / rules.maxPaddleSpeed).clamp(-1.0, 1.0) *
        rules.spinInfluence;
    final angle = (offset * rules.maxBounceAngle + spin)
        .clamp(-rules.maxTotalBounceAngle, rules.maxTotalBounceAngle);

    final speed = math.min(ball.speed * rules.ballAccelPerHit, rules.maxBallSpeed);
    final dirSign = side == FieldSide.bottom ? -1.0 : 1.0;
    ball.vx = speed * math.sin(angle);
    ball.vy = dirSign * speed * math.cos(angle);

    // Lift the ball clear of the paddle so the same contact cannot fire twice.
    final face = side == FieldSide.bottom
        ? rules.fieldLength - rules.paddleThickness
        : rules.paddleThickness;
    ball.y = side == FieldSide.bottom ? face - r - 1e-6 : face + r + 1e-6;

    state.rallyHits++;
    if (state.rallyHits > state.longestRally) {
      state.longestRally = state.rallyHits;
    }

    if (rules.paddleShrinkPerHit < 1) {
      for (final p in [state.bottom, state.top]) {
        p.width = math.max(rules.paddleMinWidth, p.width * rules.paddleShrinkPerHit);
      }
    }

    events.add(GameEvent(GameEventType.paddleHit, side: side, ballSpeed: speed));
  }

  void _awardPoint(FieldSide winner, List<GameEvent> events) {
    if (winner == FieldSide.bottom) {
      state.bottomScore++;
    } else {
      state.topScore++;
    }
    state.lastPointWinner = winner;
    state.server = winner.other;
    _parkBall();
    events.add(GameEvent(GameEventType.score, side: winner));

    if (state.scoreOf(winner) >= rules.pointsToWin) {
      state.phase = MatchPhase.matchOver;
      state.matchWinner = winner;
      events.add(GameEvent(GameEventType.matchOver, side: winner));
    } else {
      state.phase = MatchPhase.pointScored;
      state.countdown = rules.pointPause;
    }
  }
}
