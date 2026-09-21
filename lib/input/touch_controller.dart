import '../engine/game_state.dart';
import '../engine/paddle_controller.dart';

/// The player's finger. The UI converts a touch position into a field
/// coordinate and drops it here; the paddle then travels towards it under the
/// usual speed and inertia limits.
class TouchPaddleController implements PaddleController {
  double _target = 0.5;

  set target(double value) => _target = value.clamp(0.0, 1.0);
  double get target => _target;

  @override
  double update(GameState state, double dt) => _target;

  @override
  void reset() => _target = 0.5;
}
