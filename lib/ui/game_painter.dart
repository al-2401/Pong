import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/game_state.dart';
import 'field_projection.dart';
import 'theme.dart';

class PongPainter extends CustomPainter {
  PongPainter({
    required this.state,
    required this.projection,
    required this.trail,
    required this.showSpeedMeter,
    required this.shake,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameState state;
  final FieldProjection projection;

  /// Recent ball positions in field coordinates, oldest first. Kept in the UI
  /// layer because it is decoration, not simulation.
  final List<Offset> trail;

  final bool showSpeedMeter;
  final Offset shake;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shake.dx, shake.dy);

    _paintWalls(canvas);
    _paintCentreLine(canvas);
    _paintScores(canvas);
    if (showSpeedMeter) _paintSpeedMeter(canvas);
    _paintTrail(canvas);
    _paintPaddles(canvas);
    _paintBall(canvas);
    _paintCountdown(canvas);

    canvas.restore();
  }

  double get _scale => projection.scale;
  double get _length => state.rules.fieldLength;

  void _paintWalls(Canvas canvas) {
    final paint = Paint()
      ..color = PongColors.foreground.withValues(alpha: 0.10)
      ..strokeWidth = math.max(1, _scale * 0.004);
    canvas.drawLine(projection.toScreen(0, 0), projection.toScreen(0, _length), paint);
    canvas.drawLine(projection.toScreen(1, 0), projection.toScreen(1, _length), paint);
  }

  void _paintCentreLine(Canvas canvas) {
    final paint = Paint()
      ..color = PongColors.foreground.withValues(alpha: 0.14)
      ..strokeWidth = math.max(1, _scale * 0.006)
      ..strokeCap = StrokeCap.round;
    final middle = _length / 2;
    const dash = 0.04;
    const gap = 0.03;
    for (var x = 0.02; x < 0.98; x += dash + gap) {
      // Leave the middle clear: the rally counter lives there.
      if ((x - 0.5).abs() < 0.14) continue;
      final end = math.min(x + dash, 0.98);
      canvas.drawLine(
        projection.toScreen(x, middle),
        projection.toScreen(end, middle),
        paint,
      );
    }
  }

  void _paintScores(Canvas canvas) {
    final middle = _length / 2;
    _drawText(
      canvas,
      '${state.topScore}',
      projection.toScreen(0.5, middle - 0.3),
      mono(
        size: _scale * 0.3,
        color: PongColors.opponent.withValues(alpha: 0.16),
        weight: FontWeight.w700,
      ),
    );
    _drawText(
      canvas,
      '${state.bottomScore}',
      projection.toScreen(0.5, middle + 0.3),
      mono(
        size: _scale * 0.3,
        color: PongColors.player.withValues(alpha: 0.16),
        weight: FontWeight.w700,
      ),
    );

    if (state.rallyHits > 0) {
      _drawText(
        canvas,
        '${state.rallyHits}',
        projection.toScreen(0.5, middle),
        mono(
          size: _scale * 0.085,
          color: PongColors.foreground.withValues(alpha: 0.45),
        ),
      );
    }
  }

  /// A gauge on the left wall that fills as the ball speeds up. Without it the
  /// acceleration just feels like the player getting worse.
  void _paintSpeedMeter(Canvas canvas) {
    const left = 0.012;
    const right = 0.026;
    final track = projection.toScreenRect(left, 0, right, _length);
    final radius = Radius.circular(track.shortestSide / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = PongColors.foreground.withValues(alpha: 0.07),
    );

    final progress = state.speedProgress;
    if (progress <= 0) return;
    final filled = projection.toScreenRect(
      left,
      _length * (1 - progress),
      right,
      _length,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(filled, radius),
      Paint()
        ..color = Color.lerp(
          PongColors.player,
          PongColors.opponent,
          progress,
        )!
            .withValues(alpha: 0.75),
    );
  }

  void _paintTrail(Canvas canvas) {
    if (trail.length < 2) return;
    final radius = state.rules.ballRadius * _scale;
    for (var i = 0; i < trail.length; i++) {
      final t = (i + 1) / trail.length;
      canvas.drawCircle(
        projection.toScreen(trail[i].dx, trail[i].dy),
        radius * (0.25 + 0.6 * t),
        Paint()..color = PongColors.ball.withValues(alpha: 0.05 + 0.15 * t),
      );
    }
  }

  void _paintPaddles(Canvas canvas) {
    final thickness = state.rules.paddleThickness;
    _paintPaddle(
      canvas,
      state.top,
      0,
      thickness,
      PongColors.opponent,
    );
    _paintPaddle(
      canvas,
      state.bottom,
      _length - thickness,
      _length,
      PongColors.player,
    );
  }

  void _paintPaddle(
    Canvas canvas,
    PaddleState paddle,
    double fromY,
    double toY,
    Color color,
  ) {
    final rect = projection.toScreenRect(
      paddle.x - paddle.halfWidth,
      fromY,
      paddle.x + paddle.halfWidth,
      toY,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
      Paint()..color = color,
    );
  }

  void _paintBall(Canvas canvas) {
    final centre = projection.toScreen(state.ball.x, state.ball.y);
    final radius = state.rules.ballRadius * _scale;
    canvas.drawCircle(
      centre,
      radius * 2.2,
      Paint()..color = PongColors.ball.withValues(alpha: 0.07),
    );
    canvas.drawCircle(centre, radius, Paint()..color = PongColors.ball);
  }

  void _paintCountdown(Canvas canvas) {
    if (state.phase != MatchPhase.serving) return;
    final seconds = state.countdown.ceil();
    if (seconds <= 0) return;
    _drawText(
      canvas,
      '$seconds',
      projection.toScreen(0.5, _length / 2),
      mono(
        size: _scale * 0.34,
        color: PongColors.foreground.withValues(alpha: 0.85),
        weight: FontWeight.w300,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset centre, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(PongPainter oldDelegate) => true;
}
