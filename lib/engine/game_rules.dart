import 'dart:math' as math;

/// Physical description of a match.
///
/// Everything here affects the simulation, so both players must run the exact
/// same [GameRules] for a networked match to stay in sync. Local-only choices
/// (theme, sound, orientation) live in `Preferences` instead.
///
/// ## Coordinate system
///
/// The engine always works in its own logical field, never in pixels:
///
/// ```
/// x in [0, 1]          across the field, the axis paddles slide along
/// y in [0, fieldLength] along the field, opponent at y = 0, player at y = L
/// ```
///
/// Units are square (one x unit is the same length as one y unit), so the ball
/// is round and its speed does not depend on direction. [fieldLength] is the
/// long side divided by the short side, so it is always >= 1. Screen
/// orientation is purely a rendering transform and never reaches the engine.
class GameRules {
  const GameRules({
    required this.fieldLength,
    this.ballRadius = 0.022,
    this.ballCrossTime = 1.2,
    this.ballAccelPerHit = 1.03,
    this.ballMaxSpeedFactor = 2.2,
    this.paddleWidth = 0.22,
    this.paddleThickness = 0.018,
    this.paddleCrossTime = 0.22,
    this.paddleInertia = 0.35,
    this.paddleShrinkPerHit = 1.0,
    this.paddleMinWidth = 0.10,
    this.maxBounceAngle = 1.0472, // 60 degrees
    this.spinInfluence = 0.3491, // 20 degrees at full paddle speed
    this.pointsToWin = 11,
    this.serveCountdown = 3.0,
    this.pointPause = 0.9,
  });

  /// Long side / short side of the playfield. Always >= 1.
  final double fieldLength;

  final double ballRadius;

  /// Seconds for the ball to travel the whole field length at base speed.
  /// Expressing speed as a time keeps the tempo identical on every screen
  /// shape: a longer field simply means a faster ball in absolute units.
  final double ballCrossTime;

  /// Speed multiplier applied on every paddle hit.
  final double ballAccelPerHit;

  /// Hard cap on the ball speed, as a multiple of the base speed.
  final double ballMaxSpeedFactor;

  final double paddleWidth;
  final double paddleThickness;

  /// Seconds for a paddle to cross the full field width at top speed.
  final double paddleCrossTime;

  /// 0 = reacts instantly, 1 = heavy, slow to accelerate and to stop. It caps
  /// how hard the paddle may accelerate and brake; the speed cap itself stays
  /// [paddleCrossTime], though a heavy paddle runs out of field before it
  /// reaches it.
  final double paddleInertia;

  /// Width multiplier applied to both paddles on every hit of a rally.
  /// 1.0 disables the shrinking escalation.
  final double paddleShrinkPerHit;
  final double paddleMinWidth;

  /// Largest deflection from the field axis a centred-speed hit can produce.
  final double maxBounceAngle;

  /// Extra deflection added when the paddle is moving at full speed.
  final double spinInfluence;

  final int pointsToWin;
  final double serveCountdown;
  final double pointPause;

  double get baseBallSpeed => fieldLength / ballCrossTime;
  double get maxBallSpeed => baseBallSpeed * ballMaxSpeedFactor;
  double get maxPaddleSpeed => 1.0 / paddleCrossTime;

  /// Deflection is clamped here so the ball can never crawl along the walls.
  double get maxTotalBounceAngle =>
      math.min(maxBounceAngle + spinInfluence, 1.3090); // 75 degrees

  GameRules copyWith({
    double? fieldLength,
    double? ballRadius,
    double? ballCrossTime,
    double? ballAccelPerHit,
    double? ballMaxSpeedFactor,
    double? paddleWidth,
    double? paddleThickness,
    double? paddleCrossTime,
    double? paddleInertia,
    double? paddleShrinkPerHit,
    double? paddleMinWidth,
    double? maxBounceAngle,
    double? spinInfluence,
    int? pointsToWin,
    double? serveCountdown,
    double? pointPause,
  }) {
    return GameRules(
      fieldLength: fieldLength ?? this.fieldLength,
      ballRadius: ballRadius ?? this.ballRadius,
      ballCrossTime: ballCrossTime ?? this.ballCrossTime,
      ballAccelPerHit: ballAccelPerHit ?? this.ballAccelPerHit,
      ballMaxSpeedFactor: ballMaxSpeedFactor ?? this.ballMaxSpeedFactor,
      paddleWidth: paddleWidth ?? this.paddleWidth,
      paddleThickness: paddleThickness ?? this.paddleThickness,
      paddleCrossTime: paddleCrossTime ?? this.paddleCrossTime,
      paddleInertia: paddleInertia ?? this.paddleInertia,
      paddleShrinkPerHit: paddleShrinkPerHit ?? this.paddleShrinkPerHit,
      paddleMinWidth: paddleMinWidth ?? this.paddleMinWidth,
      maxBounceAngle: maxBounceAngle ?? this.maxBounceAngle,
      spinInfluence: spinInfluence ?? this.spinInfluence,
      pointsToWin: pointsToWin ?? this.pointsToWin,
      serveCountdown: serveCountdown ?? this.serveCountdown,
      pointPause: pointPause ?? this.pointPause,
    );
  }

  /// Wire format for the future host -> guest handshake: the host decides the
  /// rules and the guest replays them verbatim.
  Map<String, dynamic> toJson() => {
        'fieldLength': fieldLength,
        'ballRadius': ballRadius,
        'ballCrossTime': ballCrossTime,
        'ballAccelPerHit': ballAccelPerHit,
        'ballMaxSpeedFactor': ballMaxSpeedFactor,
        'paddleWidth': paddleWidth,
        'paddleThickness': paddleThickness,
        'paddleCrossTime': paddleCrossTime,
        'paddleInertia': paddleInertia,
        'paddleShrinkPerHit': paddleShrinkPerHit,
        'paddleMinWidth': paddleMinWidth,
        'maxBounceAngle': maxBounceAngle,
        'spinInfluence': spinInfluence,
        'pointsToWin': pointsToWin,
        'serveCountdown': serveCountdown,
        'pointPause': pointPause,
      };

  factory GameRules.fromJson(Map<String, dynamic> json) {
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    const defaults = GameRules(fieldLength: 1.8);
    return GameRules(
      fieldLength: d('fieldLength', defaults.fieldLength),
      ballRadius: d('ballRadius', defaults.ballRadius),
      ballCrossTime: d('ballCrossTime', defaults.ballCrossTime),
      ballAccelPerHit: d('ballAccelPerHit', defaults.ballAccelPerHit),
      ballMaxSpeedFactor: d('ballMaxSpeedFactor', defaults.ballMaxSpeedFactor),
      paddleWidth: d('paddleWidth', defaults.paddleWidth),
      paddleThickness: d('paddleThickness', defaults.paddleThickness),
      paddleCrossTime: d('paddleCrossTime', defaults.paddleCrossTime),
      paddleInertia: d('paddleInertia', defaults.paddleInertia),
      paddleShrinkPerHit: d('paddleShrinkPerHit', defaults.paddleShrinkPerHit),
      paddleMinWidth: d('paddleMinWidth', defaults.paddleMinWidth),
      maxBounceAngle: d('maxBounceAngle', defaults.maxBounceAngle),
      spinInfluence: d('spinInfluence', defaults.spinInfluence),
      pointsToWin: (json['pointsToWin'] as num?)?.toInt() ?? defaults.pointsToWin,
      serveCountdown: d('serveCountdown', defaults.serveCountdown),
      pointPause: d('pointPause', defaults.pointPause),
    );
  }
}
