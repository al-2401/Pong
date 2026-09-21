import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong/ui/field_projection.dart';

void main() {
  test('the field length is the screen shape, long side first', () {
    expect(FieldProjection.lengthFor(const Size(400, 800)), closeTo(2.0, 1e-12));
    expect(FieldProjection.lengthFor(const Size(800, 400)), closeTo(2.0, 1e-12));
    expect(FieldProjection.lengthFor(const Size(600, 800)), closeTo(4 / 3, 1e-12));
  });

  group('portrait', () {
    final projection = FieldProjection.fit(const Size(400, 800), 2.0);

    test('fills the screen', () {
      expect(projection.rotated, isFalse);
      expect(projection.rect, const Rect.fromLTWH(0, 0, 400, 800));
    });

    test('puts the player at the bottom', () {
      expect(projection.toScreen(0.5, 0), const Offset(200, 0));
      expect(projection.toScreen(0.5, 2.0), const Offset(200, 800));
    });

    test('reads a touch across the screen', () {
      expect(projection.fieldXFromLocal(const Offset(0, 700)), 0.0);
      expect(projection.fieldXFromLocal(const Offset(200, 700)), 0.5);
      expect(projection.fieldXFromLocal(const Offset(400, 700)), 1.0);
    });
  });

  group('landscape', () {
    final projection = FieldProjection.fit(const Size(800, 400), 2.0);

    test('fills the screen with the long axis lying down', () {
      expect(projection.rotated, isTrue);
      expect(projection.rect, const Rect.fromLTWH(0, 0, 800, 400));
    });

    test('puts the player on the right hand edge', () {
      expect(projection.toScreen(0.5, 0), const Offset(0, 200));
      expect(projection.toScreen(0.5, 2.0), const Offset(800, 200));
    });

    test('reads a touch along the screen height', () {
      expect(projection.fieldXFromLocal(const Offset(700, 400)), 0.0);
      expect(projection.fieldXFromLocal(const Offset(700, 200)), 0.5);
      expect(projection.fieldXFromLocal(const Offset(700, 0)), 1.0);
    });
  });

  test('a field shorter than the screen is letterboxed and centred', () {
    final projection = FieldProjection.fit(const Size(400, 800), 1.5);
    expect(projection.scale, 400);
    expect(projection.rect, const Rect.fromLTWH(0, 100, 400, 600));
    expect(projection.toScreen(0, 0), const Offset(0, 100));
    expect(projection.toScreen(1, 1.5), const Offset(400, 700));
  });

  test('screen and field coordinates round trip', () {
    for (final projection in [
      FieldProjection.fit(const Size(400, 800), 2.0),
      FieldProjection.fit(const Size(800, 400), 2.0),
    ]) {
      for (final fieldX in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final screen = projection.toScreen(fieldX, 1.0);
        expect(projection.fieldXFromLocal(screen), closeTo(fieldX, 1e-12));
      }
    }
  });
}
