import 'dart:math' as math;

import 'game_rules.dart';
import 'game_state.dart';

/// Moves a paddle towards a target position under a speed and an acceleration
/// limit.
///
/// The paddle never teleports under the finger: a speed cap is what keeps the
/// game winnable for the other side. Inertia controls how hard the paddle can
/// accelerate and brake, which is also what feeds the spin applied to the ball
/// on contact — so a heavy paddle is a trade-off, not just a handicap.
class PaddleMotion {
  const PaddleMotion._();

  /// Seconds to reach top speed at [GameRules.paddleInertia] == 0. Small but
  /// non-zero, so the model stays continuous and free of division by zero.
  static const double minAccelTime = 0.015;

  /// Seconds to reach top speed at [GameRules.paddleInertia] == 1.
  static const double maxAccelTime = 0.25;

  static double accelTimeFor(GameRules rules) =>
      minAccelTime +
      rules.paddleInertia.clamp(0.0, 1.0) * (maxAccelTime - minAccelTime);

  static void apply(
    PaddleState paddle,
    double targetX,
    double dt,
    GameRules rules,
  ) {
    final half = paddle.halfWidth;
    final minX = half;
    final maxX = 1 - half;
    if (maxX <= minX) {
      paddle.x = 0.5;
      paddle.velocity = 0;
      return;
    }

    final target = targetX.clamp(minX, maxX);
    final topSpeed = rules.maxPaddleSpeed;
    final accel = topSpeed / accelTimeFor(rules);

    // Arrival profile: go flat out while there is room, then start braking at
    // the last moment the acceleration limit allows. An exponential approach
    // would be smoother but leaves most of the speed budget unused, which is
    // exactly what makes a heavy paddle feel broken rather than heavy.
    final distance = target - paddle.x;
    final brakingSpeed = math.sqrt(2 * accel * distance.abs());
    final desired = distance.sign * math.min(topSpeed, brakingSpeed);

    final maxDelta = accel * dt;
    paddle.velocity += (desired - paddle.velocity).clamp(-maxDelta, maxDelta);

    var next = paddle.x + paddle.velocity * dt;

    // One discrete step can still jump over the target; land on it instead of
    // oscillating around it.
    if (distance != 0 && (target - next) * distance < 0) {
      next = target;
      paddle.velocity = 0;
    }

    if (next < minX) {
      next = minX;
      if (paddle.velocity < 0) paddle.velocity = 0;
    } else if (next > maxX) {
      next = maxX;
      if (paddle.velocity > 0) paddle.velocity = 0;
    }
    paddle.x = next;
  }
}
