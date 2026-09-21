import 'package:flutter_test/flutter_test.dart';
import 'package:pong/engine/engine.dart';
import 'package:pong/engine/game_rules.dart';
import 'package:pong/engine/game_state.dart';
import 'package:pong/engine/match_runner.dart';
import 'package:pong/engine/paddle_controller.dart';

class _CountingController implements PaddleController {
  int calls = 0;

  @override
  double update(GameState state, double dt) {
    calls++;
    return 0.5;
  }

  @override
  void reset() => calls = 0;
}

void main() {
  const rules = GameRules(fieldLength: 1.8);

  test('a second of frames produces a second of fixed steps', () {
    final bottom = _CountingController();
    final runner = MatchRunner(
      engine: GameEngine(rules: rules),
      bottom: bottom,
      top: _CountingController(),
    );

    for (var i = 0; i < 60; i++) {
      runner.advance(1 / 60);
    }

    expect(bottom.calls, closeTo(1 / GameEngine.fixedStep, 1));
  });

  test('the simulation rate is the same at 60 and 144 frames per second', () {
    double countdownAfter(double frame) {
      final engine = GameEngine(rules: rules);
      final runner = MatchRunner(
        engine: engine,
        bottom: _CountingController(),
        top: _CountingController(),
      );
      for (var t = 0.0; t < 1.0; t += frame) {
        runner.advance(frame);
      }
      return engine.state.countdown;
    }

    expect(countdownAfter(1 / 60), closeTo(countdownAfter(1 / 144), 0.02));
  });

  test('a long stall is absorbed instead of replayed', () {
    final bottom = _CountingController();
    final runner = MatchRunner(
      engine: GameEngine(rules: rules),
      bottom: bottom,
      top: _CountingController(),
    );

    runner.advance(30.0);

    expect(bottom.calls,
        closeTo(MatchRunner.maxFrame / GameEngine.fixedStep, 1));
  });
}
