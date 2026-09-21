import 'dart:math' as math;

import 'engine.dart';
import 'game_state.dart';
import 'paddle_controller.dart';

/// Drives the engine at a fixed rate from a variable frame clock.
class MatchRunner {
  MatchRunner({
    required this.engine,
    required this.bottom,
    required this.top,
  });

  /// A frame longer than this (app resumed, debugger stopped) is treated as a
  /// hiccup rather than replayed, so the simulation cannot spiral.
  static const double maxFrame = 0.25;

  final GameEngine engine;
  final PaddleController bottom;
  final PaddleController top;

  final List<GameEvent> _events = [];
  double _accumulator = 0;

  GameState get state => engine.state;

  List<GameEvent> advance(double frameSeconds) {
    _events.clear();
    _accumulator += math.min(frameSeconds, maxFrame);
    while (_accumulator >= GameEngine.fixedStep) {
      const dt = GameEngine.fixedStep;
      final bottomTarget = bottom.update(engine.state, dt);
      final topTarget = top.update(engine.state, dt);
      _events.addAll(engine.step(dt, bottomTarget, topTarget));
      _accumulator -= dt;
    }
    return _events;
  }

  void reset({FieldSide firstServer = FieldSide.bottom}) {
    _accumulator = 0;
    _events.clear();
    bottom.reset();
    top.reset();
    engine.resetMatch(firstServer: firstServer);
  }
}
