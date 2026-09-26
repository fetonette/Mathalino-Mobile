import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/question_bank_service.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';
import 'package:mathalino_student_app/screens/student/beginner_zone_gameplay_screen.dart';

import 'helpers/bank_fixture.dart';

/// Deterministic, non-Firestore question bank used by the widget tests below.
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

int _indexOfSlot(String slot) => ['A', 'B', 'C', 'D'].indexOf(slot);
int _correctIndex(LevelProvider lp) => _indexOfSlot(lp.currentQuestion!.displayCorrectAnswer);
int _wrongIndex(LevelProvider lp) => _indexOfSlot(
      ['A', 'B', 'C', 'D'].firstWhere((k) => k != lp.currentQuestion!.displayCorrectAnswer),
    );

void main() {
  testWidgets('Level 1: correct answer shows "Correct!" then Level Complete',
      (tester) async {
    final bank = buildBank();
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 1, user: _profile()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // A question and its answer choices should be visible (keys A-D).
    expect(find.textContaining('Question L1-Q'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsWidgets);

    // Tap the correct answer dynamically based on shuffled display slot.
    final answerButtons = find.byType(OutlinedButton);
    await tester.tap(answerButtons.at(_correctIndex(levelProvider)));
    await tester.pumpAndSettle();

    // The combined level complete UI appears directly with "Correct!", score, and "Level 1 Complete!".
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Level 1 Complete!'), findsOneWidget);
    expect(find.textContaining('Score: 1/1'), findsOneWidget);
    expect(levelProvider.lastCorrect, isTrue);
    // Redundant popup modal is eliminated; answer text is never exposed.
    expect(find.text('Answer Feedback'), findsNothing);
    expect(find.textContaining('Correct Answer'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(levelProvider.phase, PlayerPhase.levelComplete);
  });

  testWidgets('Level 1: wrong answer shows wrong-feedback modal (answer hidden)',
      (tester) async {
    final bank = buildBank();
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 1, user: _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap an incorrect option (not the display correct answer).
    await tester.tap(find.byType(OutlinedButton).at(_wrongIndex(levelProvider)));
    await tester.pumpAndSettle();

    // Modal feedback: "Incorrect" + score stays 0/1. Correct answer hidden.
    expect(find.text('Answer Feedback'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.textContaining('Score: 0/1'), findsOneWidget);
    expect(levelProvider.lastCorrect, isFalse);
    expect(find.textContaining('Correct Answer'), findsNothing);
    expect(find.textContaining('Your Answer'), findsNothing);

    // Dismiss the modal -> the SAME question is re-shown (no advance).
    final firstQuestionId = levelProvider.currentQuestion!.questionId;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(levelProvider.phase, PlayerPhase.playing);
    expect(levelProvider.currentQuestion!.questionId, firstQuestionId);

    // Answer correctly -> now the level completes directly with combined UI.
    await tester.tap(find.byType(OutlinedButton).at(_correctIndex(levelProvider)));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Level 1 Complete!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Continue after Level 1 advances to Level 2, not the landing page',
      (tester) async {
    final bank = buildBank();
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 1, user: _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Answer correctly -> directly reaches unified Level Complete card.
    await tester.tap(find.byType(OutlinedButton).at(_correctIndex(levelProvider)));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Level 1 Complete!'), findsOneWidget);

    // Tap "Continue" â€” should navigate to Level 2's gameplay, NOT the map/landing.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining('Level 2'),
      ),
      findsOneWidget,
    );
    expect(levelProvider.level, 2);
    expect(levelProvider.phase, PlayerPhase.playing);
  });

  testWidgets('Level 5 challenge: wrong answer triggers remediation preparation',
      (tester) async {
    final bank = buildBank();
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 5, user: _profile()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Level 5 is a Hard challenge.
    expect(levelProvider.isChallengeLevel, isTrue);
    final firstQuestionId = levelProvider.currentQuestion!.questionId;

    // Tap an incorrect option -> feedback modal.
    await tester.tap(find.byType(OutlinedButton).at(_wrongIndex(levelProvider)));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect'), findsOneWidget);

    // Dismiss the modal -> failure on challenge gate transitions to remediation preparation.
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(levelProvider.phase, PlayerPhase.remediationPrep);
    expect(levelProvider.currentQuestion!.questionId, isNot(firstQuestionId));
  });

  testWidgets(
      'Level 21 (Intermediate): wrong answer retries in place — NO remediation redirect',
      (tester) async {
    final bank = buildBank(); // combined Levels 1–40 fixture
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 21, user: _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Zone 2 levels are plain "Moderate" — never challenge levels.
    expect(levelProvider.difficulty, 'Moderate');
    expect(levelProvider.isChallengeLevel, isFalse);
    expect(find.textContaining('Question L21-Q'), findsOneWidget);
    final firstQuestionId = levelProvider.currentQuestion!.questionId;

    // Wrong answer -> standard feedback modal...
    await tester.tap(find.byType(OutlinedButton).at(_wrongIndex(levelProvider)));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect'), findsOneWidget);

    // ...and after dismissing, the SAME question is re-presented in place.
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(levelProvider.phase, PlayerPhase.playing);
    expect(levelProvider.inRemediation, isFalse);
    expect(levelProvider.currentQuestion!.questionId, firstQuestionId);
  });

  // ————————————————————————————————————————————————————————————————
  // Choice ordering: choices must always be rendered in A, B, C, D
  // order — never shuffled — even if the model's choices map has its
  // keys in an arbitrary (e.g. Firestore) order.
  // ————————————————————————————————————————————————————————————————
  testWidgets(
      'Choices are always rendered in A, B, C, D order (never shuffled)',
      (tester) async {
    // Build a minimal bank with keys deliberately inserted out of order
    // (simulating Firestore returning keys in arbitrary order).
    final bank = [
      QuestionModel(
        questionId: 'Q-shuffle',
        level: 1,
        domain: 'Domain 0',
        gradeTag: 'Grade 1-3',
        difficulty: 'Preparation',
        questionText: 'Shuffled-order test',
        // Insert D, B, A, C — rendering must still show A, B, C, D.
        choices: {
          'D': 'Choice D',
          'B': 'Choice B',
          'A': 'Choice A',
          'C': 'Choice C',
        },
        correctAnswer: 'B',
        challengeGroup: 5,
      ),
    ];

    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 1, user: _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttons = find.byType(OutlinedButton);
    expect(buttons, findsNWidgets(4));

    // Each button's circular indicator shows the choice key letter.
    // Verify they appear in A, B, C, D order — never shuffled.
    final labels = <String>[];
    for (var i = 0; i < 4; i++) {
      final button = tester.widget<OutlinedButton>(buttons.at(i));
      final row = button.child as Row;
      final circle = row.children.first as Container;
      final text = circle.child as Text;
      labels.add(text.data!.trim());
    }

    expect(labels, equals(['A', 'B', 'C', 'D']));
  });

  testWidgets(
      'Level 40 badge reads "Moderate (Multi-Step)" without boss iconography',
      (tester) async {
    final bank = buildBank();
    final levelProvider = LevelProvider(
      questionBank: _FakeBankService(bank),
      dryRun: true,
    );
    final progress = LevelProgressProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LevelProvider>.value(value: levelProvider),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(
          home: BeginnerZoneGameplayScreen(levelNumber: 40, user: _profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Distinct multi-step label (badge chip) — visually different from the
    // Level 20 Super Hardcore boss screen.
    expect(levelProvider.difficulty, 'Moderate (Multi-Step)');
    expect(find.text('Moderate (Multi-Step)'), findsWidgets);
    // No Hard/Super-Hardcore boss iconography may appear for Zone 2 levels.
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });
}
