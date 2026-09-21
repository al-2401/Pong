import 'dart:math' as math;

import 'dart:ui' show Offset, Rect, Size;

/// Maps the engine's logical field onto the screen.
///
/// The engine only ever knows a field that is `1` wide and `fieldLength` long,
/// with the player's paddle at the far end of the long axis. Orientation lives
/// here and nowhere else: in landscape the whole field is simply drawn rotated
/// a quarter turn, so the ball still travels along the long side of the screen
/// and the game plays identically whichever way the phone is held.
class FieldProjection {
  const FieldProjection({
    required this.rect,
    required this.rotated,
    required this.fieldLength,
  });

  /// The part of the screen the field covers. In a single player match this is
  /// the whole safe area; a networked guest whose screen is a different shape
  /// gets letterboxed instead, because the host owns the field geometry.
  final Rect rect;

  /// True when the field's long axis runs across the screen horizontally.
  final bool rotated;

  final double fieldLength;

  double get scale => rotated ? rect.height : rect.width;

  /// The field length a full-screen match on this area would use. Always >= 1,
  /// because the ball always travels along the long side.
  static double lengthFor(Size available) {
    if (available.shortestSide <= 0) return 1;
    return available.longestSide / available.shortestSide;
  }

  factory FieldProjection.fit(Size available, double fieldLength) {
    final rotated = available.width > available.height;
    final along = rotated ? available.width : available.height;
    final across = rotated ? available.height : available.width;
    final scale = math.min(across, along / fieldLength);
    final width = rotated ? scale * fieldLength : scale;
    final height = rotated ? scale : scale * fieldLength;
    return FieldProjection(
      rect: Rect.fromCenter(
        center: Offset(available.width / 2, available.height / 2),
        width: width,
        height: height,
      ),
      rotated: rotated,
      fieldLength: fieldLength,
    );
  }

  Offset toScreen(double fieldX, double fieldY) {
    if (!rotated) {
      return Offset(rect.left + fieldX * scale, rect.top + fieldY * scale);
    }
    // A quarter turn anticlockwise, which puts the player's end of the field
    // on the right of the screen where a thumb can reach it.
    return Offset(rect.left + fieldY * scale, rect.top + (1 - fieldX) * scale);
  }

  Rect toScreenRect(double x0, double y0, double x1, double y1) {
    return Rect.fromPoints(toScreen(x0, y0), toScreen(x1, y1));
  }

  /// Turns a touch position into a position across the field, in [0, 1].
  double fieldXFromLocal(Offset local) {
    if (scale <= 0) return 0.5;
    final value = rotated
        ? 1 - (local.dy - rect.top) / scale
        : (local.dx - rect.left) / scale;
    return value.clamp(0.0, 1.0);
  }
}
