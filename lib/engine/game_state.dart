import 'dart:math' as math;

import 'game_rules.dart';

/// Which end of the field a paddle sits at.
///
/// [bottom] is always "the local player" from the engine's point of view; a
/// networked guest will render the very same state rotated by 180 degrees so
/// that its own paddle is still the near one.
enum FieldSide { bottom, top }

extension FieldSideX on FieldSide {
  FieldSide get other => this == FieldSide.bottom ? FieldSide.top : FieldSide.bottom;
}

enum MatchPhase {
  /// Counting down before the serve; paddles move, the ball waits at centre.
  serving,

  /// Ball is live.
  rally,

  /// Short beat after a point before the next countdown starts.
  pointScored,

  /// Somebody reached [GameRules.pointsToWin].
  matchOver,
}

enum GameEventType { paddleHit, wallHit, score, matchOver }

class GameEvent {
  const GameEvent(this.type, {this.side, this.ballSpeed = 0});

  final GameEventType type;

  /// For [GameEventType.paddleHit] the paddle that was hit; for
  /// [GameEventType.score] the side that won the point.
  final FieldSide? side;

  final double ballSpeed;
}

class PaddleState {
  PaddleState({required this.x, required this.width});

  double x;
  double width;
  double velocity = 0;

  double get halfWidth => width / 2;
}

class BallState {
  BallState({this.x = 0.5, this.y = 0, this.vx = 0, this.vy = 0});

  double x;
  double y;
  double vx;
  double vy;

  double get speed => math.sqrt(vx * vx + vy * vy);
}

class GameState {
  GameState(this.rules)
      : ball = BallState(x: 0.5, y: rules.fieldLength / 2),
        bottom = PaddleState(x: 0.5, width: rules.paddleWidth),
        top = PaddleState(x: 0.5, width: rules.paddleWidth);

  final GameRules rules;
  final BallState ball;
  final PaddleState bottom;
  final PaddleState top;

  int bottomScore = 0;
  int topScore = 0;

  MatchPhase phase = MatchPhase.serving;

  /// Seconds left in [MatchPhase.serving] or [MatchPhase.pointScored].
  double countdown = 0;

  /// The side that serves next. The loser of the previous point serves, so the
  /// ball always travels towards the player who just won.
  FieldSide server = FieldSide.bottom;

  /// Paddle hits in the current rally, both sides counted.
  int rallyHits = 0;

  /// Longest rally of this match so far.
  int longestRally = 0;

  FieldSide? lastPointWinner;
  FieldSide? matchWinner;

  PaddleState paddle(FieldSide side) =>
      side == FieldSide.bottom ? bottom : top;

  int scoreOf(FieldSide side) =>
      side == FieldSide.bottom ? bottomScore : topScore;

  /// 0 at the serve, 1 once the ball has reached its top speed. Drives the
  /// on-screen speed meter, which is what makes the acceleration readable
  /// instead of just feeling like the player suddenly got worse.
  double get speedProgress {
    final base = rules.baseBallSpeed;
    final max = rules.maxBallSpeed;
    if (max <= base) return 0;
    return ((ball.speed - base) / (max - base)).clamp(0.0, 1.0);
  }
}
