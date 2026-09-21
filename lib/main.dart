import 'package:flutter/material.dart';

import 'audio/sound_service.dart';
import 'settings/preferences.dart';
import 'stats/records.dart';
import 'ui/menu_screen.dart';
import 'ui/pong_scope.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await Preferences.load();
  final records = await Records.load();
  final sound = SoundService()..enabled = preferences.sound;
  await sound.init();

  // Keeping the service in step with the setting here means neither the game
  // screen nor the painter has to know the sound exists.
  preferences.addListener(() => sound.enabled = preferences.sound);

  runApp(
    PongApp(preferences: preferences, records: records, sound: sound),
  );
}

class PongApp extends StatelessWidget {
  const PongApp({
    super.key,
    required this.preferences,
    required this.records,
    required this.sound,
  });

  final Preferences preferences;
  final Records records;
  final SoundService sound;

  @override
  Widget build(BuildContext context) {
    return PongScope(
      preferences: preferences,
      records: records,
      sound: sound,
      child: MaterialApp(
        title: 'Pong',
        debugShowCheckedModeBanner: false,
        theme: buildPongTheme(),
        home: const MenuScreen(),
      ),
    );
  }
}
