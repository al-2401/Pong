import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The three tones the original cabinet made, preloaded so a hit does not have
/// to wait for a file to open.
///
/// Every call is best effort: on a device where the audio plugin misbehaves
/// the game must keep running silently rather than throw mid-rally.
class SoundService {
  static const _assets = <String, String>{
    'paddle': 'sounds/paddle.wav',
    'wall': 'sounds/wall.wav',
    'score': 'sounds/score.wav',
  };

  final Map<String, AudioPlayer> _players = {};
  bool enabled = true;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      for (final entry in _assets.entries) {
        final player = AudioPlayer(playerId: 'pong_${entry.key}');
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(entry.value));
        await player.setVolume(0.6);
        _players[entry.key] = player;
      }
      _ready = true;
    } catch (error) {
      debugPrint('Sound disabled: $error');
      _ready = false;
    }
  }

  void paddleHit() => _play('paddle');
  void wallHit() => _play('wall');
  void score() => _play('score');

  void _play(String name) {
    if (!enabled || !_ready) return;
    final player = _players[name];
    if (player == null) return;
    // Fire and forget; a dropped blip is not worth interrupting a rally for.
    player.seek(Duration.zero).then((_) => player.resume()).catchError((_) {});
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {
        // Nothing useful to do if the platform side is already gone.
      }
    }
    _players.clear();
    _ready = false;
  }
}
