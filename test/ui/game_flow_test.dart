import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong/audio/sound_service.dart';
import 'package:pong/main.dart';
import 'package:pong/settings/preferences.dart';
import 'package:pong/stats/records.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return PongApp(
    preferences: await Preferences.load(),
    records: await Records.load(),
    // The audio plugin is not available in a widget test; the service is
    // expected to fall back to silence rather than throw.
    sound: SoundService(),
  );
}

void main() {
  testWidgets('the menu offers a difficulty and a way in', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();

    expect(find.text('PONG'), findsOneWidget);
    expect(find.text('НОРМА'), findsOneWidget);
    expect(find.text('ИГРАТЬ'), findsOneWidget);

    await tester.tap(find.text('ХАРД'));
    await tester.pump();
    expect(find.textContaining('ракетки сужаются'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a match starts, counts down and runs', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();

    await tester.tap(find.text('ИГРАТЬ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('Пауза'), findsOneWidget);

    // Run past the serve countdown and well into the rally.
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Пауза'));
    await tester.pump();
    expect(find.text('ПАУЗА'), findsOneWidget);

    await tester.tap(find.text('В МЕНЮ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PONG'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings expose inertia and orientation', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();

    await tester.tap(find.text('НАСТРОЙКИ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ИНЕРТНОСТЬ РАКЕТКИ'), findsOneWidget);
    expect(find.text('ОРИЕНТАЦИЯ'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('ЛАНДШАФТ'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
  });
}
