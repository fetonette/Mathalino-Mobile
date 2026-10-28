import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/question_bank_service.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';
import 'package:mathalino_student_app/screens/student/beginner_zone_gameplay_screen.dart';
import 'package:mathalino_student_app/widgets/hearts.dart';

import 'helpers/bank_fixture.dart';

class _FakeBankService extends QuestionBankService {
  _FakeBankService(this.bank);
  final List<QuestionModel> bank;
  @override
  Future<List<QuestionModel>> fetchQuestionBank() async => bank;
}

StudentProfile _profile() => StudentProfile(
      uid: 'u1',
      lrn: '123456789012',
      displayName: 'Test',
      gradeLevel: 1,
      assignedCategory: 'Beginner',
      currentLevel: 1,
      startingLevel: 1,
      stats: const StudentStats(),
      usedQuestionsHistory: const [],
      diagnosticCompleted: false,
      verificationCode: 'MTH-0000',
    );

const List<String> _slots = ['A', 'B', 'C', 'D'];

/// Choices are display-shuffled, so the correct slot differs per question.
/// Derive the correct/wrong slots from the current question every time.
String _correctKey(LevelProvider lp) => lp.currentQuestion!.displayCorrectAnswer;
String _wrongKey(LevelProvider lp) =>
    _slots.firstWhere((k) => k != lp.currentQuestion!.displayCorrectAnswer);
int _wrongIndex(LevelProvider lp) => _slots.indexOf(_wrongKey(lp));

Future<LevelProvider> _startLevel(int level) async {
  final lp = LevelProvider(
    questionBank: _FakeBankService(buildBank()),
    dryRun: true,
  );
  await lp.startLevel(
    userId: 'u1',
    lrn: '123456789012',
    level: level,
    usedHistory: const [],
  );
  return lp;
}

void main() {
  group('LevelProvider hearts (Preparation / Moderate)', () {
    test('starts with 3 hearts', () async {
      final lp = await _startLevel(1);
      expect(lp.hearts, 3);
      expect(lp.phase, PlayerPhase.playing);
    });

    test('each incorrect answer removes exactly one heart, never below zero',
        () async {
      final lp = await _startLevel(1);
      final wrong = _wrongKey(lp);
      await lp.submitAnswer(wrong);
      expect(lp.hearts, 2);
      expect(lp.phase, PlayerPhase.playing);
      await lp.submitAnswer(wrong);
      expect(lp.hearts, 1);
      expect(lp.phase, PlayerPhase.playing);
      await lp.submitAnswer(wrong);
      expect(lp.hearts, 0);
      expect(lp.phase, PlayerPhase.outOfHearts);
      expect(lp.hearts, greaterThanOrEqualTo(0));
    });

    test('a correct answer does NOT remove a heart', () async {
      final lp = await _startLevel(1);
      final wrong = _wrongKey(lp);
      final right = _correctKey(lp);
      await lp.submitAnswer(wrong); // 2 hearts
      await lp.submitAnswer(right); // completes, hearts untouched
      expect(lp.phase, PlayerPhase.levelComplete);
      expect(lp.hearts, 2);
      expect(lp.score, 1);
    });

    test('three incorrect answers lead to out-of-hearts and stop completion',
        () async {
      final lp = await _startLevel(1);
      final wrong = _wrongKey(lp);
      for (var i = 0; i < 3; i++) {
        await lp.submitAnswer(wrong);
      }
      expect(lp.phase, PlayerPhase.outOfHearts);
      expect(lp.phase, isNot(PlayerPhase.levelComplete));
      expect(lp.score, 0);
    });

    test('extra submissions at zero hearts have no effect', () async {
      final lp = await _startLevel(1);
      final wrong = _wrongKey(lp);
      for (var i = 0; i < 3; i++) {
        await lp.submitAnswer(wrong);
      }
      expect(lp.phase, PlayerPhase.outOfHearts);
      // Even the correct answer is ignored while out of hearts.
      await lp.submitAnswer(_correctKey(lp));
      expect(lp.phase, PlayerPhase.outOfHearts);
      expect(lp.hearts, 0);
      expect(lp.score, 0);
    });

    test('Try Again resets hearts, score and attempt count with a valid question',
        () async {
      final lp = await _startLevel(1);
      final wrong = _wrongKey(lp);
      for (var i = 0; i < 3; i++) {
        await lp.submitAnswer(wrong);
      }
      lp.restartLevelForHearts();
      expect(lp.hearts, 3);
      expect(lp.score, 0);
      expect(lp.attemptedTotal, 0);
      expect(lp.phase, PlayerPhase.playing);
      expect(lp.currentQuestion, isNotNull);
    });

    test('Challenge wrong answer enters remediation WITHOUT losing hearts',
        () async {
      final lp = await _startLevel(5); // Hard gate
      expect(lp.isChallengeLevel, isTrue);
      expect(lp.hearts, 3);
      await lp.submitAnswer(_wrongKey(lp));
      expect(lp.phase, PlayerPhase.remediationPrep);
      expect(lp.hearts, 3); // hearts untouched on the challenge flow
      expect(lp.phase, isNot(PlayerPhase.outOfHearts));
    });

    test('Remediation prep answers remain unchanged (no heart loss)', () async {
      final lp = await _startLevel(5);
      await lp.submitAnswer(_wrongKey(lp)); // enter remediation
      expect(lp.phase, PlayerPhase.remediationPrep);
      final prepQuestionId = lp.currentQuestion!.questionId;
      await lp.submitAnswer(_wrongKey(lp)); // wrong prep answer repeats same
      expect(lp.phase, PlayerPhase.remediationPrep);
      expect(lp.hearts, 3);
      expect(lp.attemptedPrep, 0); // wrong prep answer does not count
      expect(lp.currentQuestion!.questionId, prepQuestionId);
    });
  });

  group('BeginnerZoneGameplayScreen hearts UI', () {
    Future<LevelProvider> pumpLevel(WidgetTester tester, int level) async {
      final lp = LevelProvider(
        questionBank: _FakeBankService(buildBank()),
        dryRun: true,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LevelProvider>.value(value: lp),
            ChangeNotifierProvider<LevelProgressProvider>.value(
                value: LevelProgressProvider()),
          ],
          child: MaterialApp(
            home:
                BeginnerZoneGameplayScreen(levelNumber: level, user: _profile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return lp;
    }

    testWidgets('shows a heart row for Preparation levels', (tester) async {
      await pumpLevel(tester, 1);
      expect(find.byType(Hearts), findsWidgets);
    });

    testWidgets('three wrong answers reveal the out-of-hearts screen',
        (tester) async {
      final lp = await pumpLevel(tester, 1);
      final wrongIdx = _wrongIndex(lp);

      await tester.tap(find.byType(OutlinedButton).at(wrongIdx));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OutlinedButton).at(wrongIdx));
      await tester.pumpAndSettle();
      // At one heart remaining the feedback dialog shows an encouraging hint.
      expect(find.textContaining('one heart left'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(OutlinedButton).at(wrongIdx));
      await tester.pumpAndSettle();

      expect(find.text("Let's Practice Again!"), findsOneWidget);
      expect(find.text('Back to Adventure Map'), findsOneWidget);
      expect(find.text('Incorrect'), findsNothing);
    });

    testWidgets('Try Again on the out-of-hearts screen restarts the level',
        (tester) async {
      final lp = await pumpLevel(tester, 1);
      final wrongIdx = _wrongIndex(lp);
      // Two wrong answers (dismiss the feedback dialog each time).
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(OutlinedButton).at(wrongIdx));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Try Again'));
        await tester.pumpAndSettle();
      }
      // Third wrong answer -> out of hearts.
      await tester.tap(find.byType(OutlinedButton).at(wrongIdx));
      await tester.pumpAndSettle();
      expect(lp.phase, PlayerPhase.outOfHearts);
      expect(find.text("Let's Practice Again!"), findsOneWidget);

      // Try Again restarts the same level in place (no completion / rewards).
      await tester.ensureVisible(find.text('Try Again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(lp.phase, PlayerPhase.playing);
      expect(lp.hearts, 3);
      expect(lp.score, 0);
      expect(lp.attemptedTotal, 0);
      // The answer choices are shown again for a fresh attempt.
      expect(find.byType(OutlinedButton), findsNWidgets(4));
    });

    testWidgets('Challenge levels show no hearts and keep remediation',
        (tester) async {
      final lp = await pumpLevel(tester, 5);
      expect(find.byType(Hearts), findsNothing);
      await tester.tap(find.byType(OutlinedButton).at(_wrongIndex(lp)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      // Challenge wrong answer routes to remediation, never out-of-hearts.
      expect(find.text("Let's Practice Again!"), findsNothing);
      expect(lp.phase, PlayerPhase.remediationPrep);
    });
  });
}
