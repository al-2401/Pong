import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/difficulty.dart';

/// What the player has to come back for.
///
/// The rally counter is the point of this: a score line says who won, but the
/// longest rally is the number people actually chase.
class Records extends ChangeNotifier {
  Records._(this._store);

  static const _kBestRally = 'bestRally';
  static const _kTotalHits = 'totalHits';
  static const _kMatches = 'matchesPlayed';
  static const _kTopSpeed = 'topSpeedReached';
  static const _kWinsPrefix = 'wins.';

  final SharedPreferences _store;

  int _bestRally = 0;
  int _totalHits = 0;
  int _matchesPlayed = 0;
  double _topSpeedReached = 0;
  final Map<Difficulty, int> _wins = {};

  static Future<Records> load() async {
    final store = await SharedPreferences.getInstance();
    final records = Records._(store);
    records._read();
    return records;
  }

  void _read() {
    _bestRally = _store.getInt(_kBestRally) ?? 0;
    _totalHits = _store.getInt(_kTotalHits) ?? 0;
    _matchesPlayed = _store.getInt(_kMatches) ?? 0;
    _topSpeedReached = _store.getDouble(_kTopSpeed) ?? 0;
    for (final difficulty in Difficulty.values) {
      _wins[difficulty] = _store.getInt('$_kWinsPrefix${difficulty.name}') ?? 0;
    }
  }

  int get bestRally => _bestRally;
  int get totalHits => _totalHits;
  int get matchesPlayed => _matchesPlayed;

  /// Highest point on the speed meter ever reached, 0 to 1.
  double get topSpeedReached => _topSpeedReached;

  int winsAt(Difficulty difficulty) => _wins[difficulty] ?? 0;
  int get totalWins => _wins.values.fold(0, (sum, value) => sum + value);

  /// Called when a rally ends. Returns true when it beat the all-time best,
  /// so the game screen can celebrate it.
  bool registerRally(int hits) {
    if (hits <= 0) return false;
    _totalHits += hits;
    _store.setInt(_kTotalHits, _totalHits);
    final isRecord = hits > _bestRally;
    if (isRecord) {
      _bestRally = hits;
      _store.setInt(_kBestRally, hits);
    }
    notifyListeners();
    return isRecord;
  }

  void registerSpeed(double progress) {
    if (progress <= _topSpeedReached) return;
    _topSpeedReached = progress.clamp(0.0, 1.0);
    _store.setDouble(_kTopSpeed, _topSpeedReached);
    notifyListeners();
  }

  void registerMatch({required Difficulty difficulty, required bool won}) {
    _matchesPlayed++;
    _store.setInt(_kMatches, _matchesPlayed);
    if (won) {
      final next = winsAt(difficulty) + 1;
      _wins[difficulty] = next;
      _store.setInt('$_kWinsPrefix${difficulty.name}', next);
    }
    notifyListeners();
  }
}
