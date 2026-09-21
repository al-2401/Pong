import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/difficulty.dart';

/// How the field is laid out on the screen. Purely local: the field geometry
/// is fixed by the rules, so a rotated view changes nothing about the game and
/// two networked players may hold their phones differently.
enum FieldOrientation { auto, portrait, landscape }

/// Local, per-player choices. Nothing here may affect the simulation — that is
/// what `GameRules` is for. Keeping the two apart is what makes a networked
/// match fair without having to police the other player's settings.
class Preferences extends ChangeNotifier {
  Preferences._(this._store);

  static const _kDifficulty = 'difficulty';
  static const _kInertia = 'paddleInertia';
  static const _kOrientation = 'orientation';
  static const _kSound = 'sound';
  static const _kHaptics = 'haptics';
  static const _kSpeedMeter = 'speedMeter';

  final SharedPreferences _store;

  Difficulty _difficulty = Difficulty.normal;
  double _paddleInertia = 0.35;
  FieldOrientation _orientation = FieldOrientation.auto;
  bool _sound = true;
  bool _haptics = true;
  bool _speedMeter = true;

  static Future<Preferences> load() async {
    final store = await SharedPreferences.getInstance();
    final prefs = Preferences._(store);
    prefs._read();
    return prefs;
  }

  void _read() {
    final difficultyName = _store.getString(_kDifficulty);
    _difficulty = Difficulty.values.firstWhere(
      (d) => d.name == difficultyName,
      orElse: () => Difficulty.normal,
    );
    _paddleInertia = _store.getDouble(_kInertia) ?? 0.35;
    final orientationName = _store.getString(_kOrientation);
    _orientation = FieldOrientation.values.firstWhere(
      (o) => o.name == orientationName,
      orElse: () => FieldOrientation.auto,
    );
    _sound = _store.getBool(_kSound) ?? true;
    _haptics = _store.getBool(_kHaptics) ?? true;
    _speedMeter = _store.getBool(_kSpeedMeter) ?? true;
  }

  Difficulty get difficulty => _difficulty;
  double get paddleInertia => _paddleInertia;
  FieldOrientation get orientation => _orientation;
  bool get sound => _sound;
  bool get haptics => _haptics;
  bool get speedMeter => _speedMeter;

  set difficulty(Difficulty value) {
    if (_difficulty == value) return;
    _difficulty = value;
    _store.setString(_kDifficulty, value.name);
    notifyListeners();
  }

  set paddleInertia(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_paddleInertia == clamped) return;
    _paddleInertia = clamped;
    _store.setDouble(_kInertia, clamped);
    notifyListeners();
  }

  set orientation(FieldOrientation value) {
    if (_orientation == value) return;
    _orientation = value;
    _store.setString(_kOrientation, value.name);
    notifyListeners();
  }

  set sound(bool value) {
    if (_sound == value) return;
    _sound = value;
    _store.setBool(_kSound, value);
    notifyListeners();
  }

  set haptics(bool value) {
    if (_haptics == value) return;
    _haptics = value;
    _store.setBool(_kHaptics, value);
    notifyListeners();
  }

  set speedMeter(bool value) {
    if (_speedMeter == value) return;
    _speedMeter = value;
    _store.setBool(_kSpeedMeter, value);
    notifyListeners();
  }
}
