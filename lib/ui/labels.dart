import '../engine/difficulty.dart';
import '../settings/preferences.dart';

extension DifficultyLabel on Difficulty {
  String get title => switch (this) {
        Difficulty.rookie => 'НОВИЧОК',
        Difficulty.normal => 'НОРМА',
        Difficulty.hard => 'ХАРД',
        Difficulty.insane => 'БЕЗУМИЕ',
      };

  String get description => switch (this) {
        Difficulty.rookie => 'Медленный мяч, соперник замечает его поздно',
        Difficulty.normal => 'Мяч разгоняется, соперник иногда ошибается',
        Difficulty.hard => 'Быстрый мяч, ракетки сужаются за длинный розыгрыш',
        Difficulty.insane => 'Соперник почти не ошибается и бьёт по углам',
      };
}

extension OrientationLabel on FieldOrientation {
  String get title => switch (this) {
        FieldOrientation.auto => 'АВТО',
        FieldOrientation.portrait => 'ПОРТРЕТ',
        FieldOrientation.landscape => 'ЛАНДШАФТ',
      };
}
