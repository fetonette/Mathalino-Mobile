import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/widgets/level_node.dart';
import 'package:mathalino_student_app/widgets/zone_banner.dart';

void main() {
  group('LevelProgressProvider State Tests', () {
    test('Initializes with default level 1 and starting level 1', () {
      final provider = LevelProgressProvider();
      provider.initLocal(currentLevel: 1, startingLevel: 1);

      expect(provider.currentLevel, equals(1));
      expect(provider.startingLevel, equals(1));
      expect(provider.getLevelState(1), equals(LevelState.unlocked));
      expect(provider.getLevelState(2), equals(LevelState.locked));
      expect(provider.getLevelState(60), equals(LevelState.locked));
    });

    test('Classifies Hard levels and Boss levels correctly', () {
      expect(LevelProgressProvider.isHardLevel(5), isTrue);
      expect(LevelProgressProvider.isHardLevel(10), isTrue);
      expect(LevelProgressProvider.isHardLevel(7), isFalse);

      // Intermediate zone (21–40): NO gates per the Intermediate spec —
      // levels unlock in a straight line.
      expect(LevelProgressProvider.isHardLevel(25), isFalse);
      expect(LevelProgressProvider.isHardLevel(30), isFalse);
      expect(LevelProgressProvider.isHardLevel(35), isFalse);
      expect(LevelProgressProvider.isHardLevel(40), isFalse);

      // Zone 3 keeps its original gate structure.
      expect(LevelProgressProvider.isHardLevel(45), isTrue);
      expect(LevelProgressProvider.isHardLevel(50), isTrue);
      expect(LevelProgressProvider.isHardLevel(55), isTrue);

      expect(LevelProgressProvider.isBossLevel(20), isTrue);
      expect(LevelProgressProvider.isBossLevel(60), isTrue);
      // Level 40 was DEMOTED from boss to "Moderate (Multi-Step)".
      expect(LevelProgressProvider.isBossLevel(40), isFalse);
      expect(LevelProgressProvider.isBossLevel(15), isFalse);
    });

    test('Correctly maps zones to levels', () {
      expect(LevelProgressProvider.getZoneForLevel(1), equals(1));
      expect(LevelProgressProvider.getZoneForLevel(20), equals(1));
      expect(LevelProgressProvider.getZoneForLevel(21), equals(2));
      expect(LevelProgressProvider.getZoneForLevel(40), equals(2));
      expect(LevelProgressProvider.getZoneForLevel(41), equals(3));
      expect(LevelProgressProvider.getZoneForLevel(60), equals(3));
    });

    test('Placement Skipping: Levels below startingLevel are completed', () {
      final provider = LevelProgressProvider();
      provider.initLocal(currentLevel: 21, startingLevel: 21);

      // Levels 1-20 should be completed/unlocked
      expect(provider.getLevelState(1), equals(LevelState.completed));
      expect(provider.getLevelState(20), equals(LevelState.completed));
      // Level 21 is active current level (unlocked)
      expect(provider.getLevelState(21), equals(LevelState.unlocked));
      // Level 22 is locked
      expect(provider.getLevelState(22), equals(LevelState.locked));
    });
  });

  group('Widget Tests: LevelNode & ZoneBanner', () {
    testWidgets('Renders LevelNode locked state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelNode(
              levelNumber: 5,
              state: LevelState.locked,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('Renders LevelNode completed state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelNode(
              levelNumber: 10,
              state: LevelState.completed,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Renders ZoneBanner with completed count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoneBanner.zone1(completedCount: 15),
          ),
        ),
      );

      expect(find.text('ZONE 1'), findsOneWidget);
      expect(find.text('15 / 20 Completed'), findsOneWidget);
      expect(find.text('Zone 1: Foundations Realm'), findsOneWidget);
    });
  });
}
