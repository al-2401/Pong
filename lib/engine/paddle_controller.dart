import 'game_state.dart';

/// Where a paddle wants to be.
///
/// Everything that can drive a paddle implements this: the player's finger,
/// the AI, and later the opponent arriving over the network. The engine never
/// learns which is which, so a local match and a networked one run exactly the
/// same simulation.
abstract class PaddleController {
  /// Returns the desired paddle position along the field width, in [0, 1].
  /// Called once per fixed simulation step.
  double update(GameState state, double dt);

  void reset();
}
