import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/screens/student/lesson_detail_screen.dart';
import 'package:mathalino_student_app/screens/student/module_lessons_screen.dart';

void main() {
  late LearnContentPackage package;

  setUpAll(() {
    final file = File('assets/data/mathalino_learn_content_v2.json');
    final rawJson = file.readAsStringSync();
    package = LearnContentPackage.fromJson(json.decode(rawJson) as Map<String, dynamic>);
  });

  group('Learn Screens Widget Tests', () {
    testWidgets('ModuleLessonsScreen renders topics list for Grade 1 Number Sense', (tester) async {
      final g1 = package.getGrade(1)!;
      final nsModule = g1.getModule('number_sense')!;

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleLessonsScreen(
            module: nsModule,
            gradeLevel: 1,
          ),
        ),
      );

      // Verify header and topic titles
      expect(find.text('Number Sense'), findsNWidgets(2)); // in AppBar and Header
      expect(find.text('Grade 1 Curriculum'), findsOneWidget);
      expect(find.text('2 formal lessons'), findsOneWidget);
      expect(find.text('Counting, Reading, and Ordering Numbers to 100'), findsOneWidget);
      expect(find.text('What Comes Next? (Repeating Patterns)'), findsOneWidget);
    });

    testWidgets('ModuleLessonsScreen renders friendly Coming Soon state for empty module', (tester) async {
      final g4 = package.getGrade(4)!;
      final nsModule = g4.getModule('number_sense')!;

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleLessonsScreen(
            module: nsModule,
            gradeLevel: 4,
          ),
        ),
      );

      expect(find.text('Coming Soon'), findsOneWidget);
      expect(find.text('Back to Learn Modules'), findsOneWidget);
    });

    testWidgets('LessonDetailScreen renders all 11 formal sequence sections without error', (tester) async {
      final g1 = package.getGrade(1)!;
      final topic = g1.getModule('operations')!.topics.first;

      await tester.pumpWidget(
        MaterialApp(
          home: LessonDetailScreen(topic: topic),
        ),
      );

      // Verify title & badges
      expect(find.text(topic.title), findsAtLeastNWidgets(1));
      expect(find.text('Grade 1 • Operations'), findsOneWidget);
      expect(find.text('RMA Mapped'), findsOneWidget);

      // Verify the 11 section titles
      expect(find.text('Learning Objectives'), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Step-by-Step Explanation'), findsOneWidget);
      expect(find.text('Key Concepts & Rules'), findsOneWidget);
      expect(find.text('Worked Examples'), findsOneWidget);
      expect(find.text('Guided Practice'), findsOneWidget);
      expect(find.text('Independent Practice'), findsOneWidget);
      expect(find.text('Real-Life Application'), findsOneWidget);
      expect(find.text('Check Understanding'), findsOneWidget);
      expect(find.text('Lesson Summary'), findsOneWidget);
      expect(find.text('Math Explorer Challenge'), findsOneWidget);

      // Test interactive hint expansion in Guided Practice
      final hintFinder = find.text('Need a Hint?').first;
      expect(find.text('Need a Hint?'), findsWidgets);
      await tester.ensureVisible(hintFinder);
      await tester.pumpAndSettle();
      await tester.tap(hintFinder);
      await tester.pumpAndSettle();
      expect(find.text('Hide Hint'), findsOneWidget);
    });
  });
}
