import 'package:flutter/widgets.dart';

import '../audio/sound_service.dart';
import '../settings/preferences.dart';
import '../stats/records.dart';

/// The three long-lived objects every screen needs. Plain [InheritedWidget]
/// rather than a state-management package: the game has one live scene and no
/// asynchronous data graph to speak of, and the engine depends on none of it.
class PongScope extends InheritedWidget {
  const PongScope({
    super.key,
    required this.preferences,
    required this.records,
    required this.sound,
    required super.child,
  });

  final Preferences preferences;
  final Records records;
  final SoundService sound;

  static PongScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PongScope>();
    assert(scope != null, 'PongScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(PongScope oldWidget) =>
      preferences != oldWidget.preferences ||
      records != oldWidget.records ||
      sound != oldWidget.sound;
}
