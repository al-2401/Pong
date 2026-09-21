import 'dart:math' as math;

import 'game_state.dart';
import 'paddle_controller.dart';

/// How good the computer opponent is.
///
/// Difficulty is deliberately *not* expressed as paddle speed: an opponent
/// that slides slowly reads as broken, while one that reacts late and
/// misjudges the ball reads as a human who is not very good. The AI paddle
/// obeys exactly the same physics as the player's.
class AiProfile {
  const AiProfile({
    required this.reactionDelay,
    required this.aimError,
    this.aimBias = 0,
    this.trackEarly = true,
  });

  /// Seconds before the AI reacts to a shot it has just been hit with.
  final double reactionDelay;

  /// Largest aiming mistake, in field widths. Rolled once per shot and held
  /// for the whole flight: an error that shrank as the ball approached would
  /// leave the paddle perfectly placed at the only moment that matters, which
  /// is how an opponent ends up unbeatable at every level.
  final double aimError;

  /// How far the AI shifts its contact point to send the ball away from the
  /// player, as a fraction of its own half width. 0 means it just returns the
  /// ball without aiming.
  final double aimBias;

  /// When false the AI ignores the ball until it crosses the middle of the
  /// field, which is what makes the easiest level beatable.
  final bool trackEarly;
}

class AiPaddleController implements PaddleController {
  AiPaddleController({
    required this.side,
    required this.profile,
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// Time constant for drifting back to the middle between shots.
  static const double _recenterTime = 0.45;

  final FieldSide side;
  final AiProfile profile;
  final math.Random _random;

  double _target = 0.5;
  double _reactionLeft = 0;
  double _error = 0;
  int _lastDirection = 0;

  @override
  void reset() {
    _target = 0.5;
    _reactionLeft = 0;
    _error = 0;
    _lastDirection = 0;
  }

  @override
  double update(GameState state, double dt) {
    if (state.phase != MatchPhase.rally) {
      _lastDirection = 0;
      _target = 0.5;
      return _target;
    }

    final ball = state.ball;
    final direction = ball.vy == 0 ? 0 : (ball.vy > 0 ? 1 : -1);
    if (direction != _lastDirection) {
      // A new shot is on its way: start the reaction clock and commit to one
      // misjudgement for the whole flight.
      _lastDirection = direction;
      _reactionLeft = profile.reactionDelay;
      _error = (_random.nextDouble() * 2 - 1) * profile.aimError;
    }

    final incoming = side == FieldSide.top ? direction < 0 : direction > 0;
    if (!incoming) {
      _target += (0.5 - _target) * (1 - math.exp(-dt / _recenterTime));
      return _target;
    }

    if (_reactionLeft > 0) {
      _reactionLeft -= dt;
      return _target;
    }

    if (!profile.trackEarly && !_hasCrossedMidfield(state)) {
      return _target;
    }

    _target = _aim(state);
    return _target;
  }

  bool _hasCrossedMidfield(GameState state) {
    final middle = state.rules.fieldLength / 2;
    return side == FieldSide.top
        ? state.ball.y < middle
        : state.ball.y > middle;
  }

  double _aim(GameState state) {
    final rules = state.rules;
    final ball = state.ball;
    final r = rules.ballRadius;

    final face = side == FieldSide.top
        ? rules.paddleThickness + r
        : rules.fieldLength - rules.paddleThickness - r;

    if (ball.vy == 0) return _target;
    final timeToImpact = (face - ball.y) / ball.vy;
    if (timeToImpact <= 0) return _target;

    // Straight-line prediction folded back into the field: bouncing off the
    // side walls is the same as mirroring the trajectory, so there is no need
    // to step the simulation forward.
    final raw = ball.x + ball.vx * timeToImpact;
    var predicted = foldIntoRange(raw, r, 1 - r) + _error;

    final paddle = state.paddle(side);
    if (profile.aimBias > 0) {
      // Meet the ball off-centre so it leaves towards the side the player is
      // not standing on.
      final playerX = state.paddle(side.other).x;
      final away = playerX < 0.5 ? 1.0 : -1.0;
      predicted -= away * profile.aimBias * (paddle.halfWidth + r);
    }

    return predicted.clamp(paddle.halfWidth, 1 - paddle.halfWidth);
  }

  /// Reflects [value] back and forth between [lo] and [hi], the way a ball
  /// bounces between two walls.
  static double foldIntoRange(double value, double lo, double hi) {
    final span = hi - lo;
    if (span <= 0) return lo;
    final period = 2 * span;
    var t = (value - lo) % period;
    if (t < 0) t += period;
    if (t > span) t = period - t;
    return lo + t;
  }
}
