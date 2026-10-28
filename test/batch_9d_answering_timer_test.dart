import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/models/student_result_model.dart';
import 'package:mathalino_student_app/core/services/answering_timer.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';

/// Test double simulating SupabaseService for level completion writes.
class TestSupabaseService extends SupabaseService {
  final List<Map<String, dynamic>> recordedStudentResults = [];

  @override
  Future<void> recordUsedQuestions({
    required String userId,
    required String lrn,
    required int level,
    required List<String> questionIds,
  }) async {}

  final List<LevelCompletionOutcome> outcomes = [];
  bool shouldSucceed = true;

  @override
  Future<LevelCompletionOutcome> saveLevelCompletionWithOutcome({
    required String userId,
    required String lrn,
    required int level,
    required int nextLevel,
    required bool isGameComplete,
    required List<String> usedQuestions,
    required int score,
    required int maxScore,
    required double accuracyPct,
    required bool isChallenge,
    required String difficulty,
    required String zone,
    String? scoringMode,
    int? attemptNumber,
    int? durationSeconds,
  }) async {
    final outcome = LevelCompletionOutcome(
      level: level,
      xpAwarded: isChallenge ? 100 : 50,
      coinsAwarded: accuracyPct >= 90 ? 15 : (accuracyPct >= 60 ? 10 : (accuracyPct > 0 ? 5 : 0)),
      totalXpBefore: 0,
      totalXpAfter: isChallenge ? 100 : 50,
      coinsBefore: 0,
      coinsAfter: 15,
      previousSavedStars: 0,
      newSavedStars: accuracyPct >= 90 ? 3 : (accuracyPct >= 60 ? 2 : (accuracyPct > 0 ? 1 : 0)),
      totalStarsGain: 3,
      wasFirstCompletion: true,
      isChallenge: isChallenge,
      saveSucceeded: shouldSucceed,
      rewardsPersisted: shouldSucceed,
      starsPersisted: shouldSucceed,
      durationSeconds: durationSeconds,
    );
    outcomes.add(outcome);

    recordedStudentResults.add({
      'student_uid': userId,
      'lrn': lrn,
      'level_number': level,
      'score': score,
      'max_score': maxScore,
      'percentage': accuracyPct,
      'assessment_type': isChallenge ? 'LEVEL_CHALLENGE' : 'LEVEL_PRACTICE',
      'result_data': {
        'studentId': userId,
        'level': level,
        'score': score,
        'maxScore': maxScore,
        'percentage': accuracyPct,
        'isChallenge': isChallenge,
        'difficulty': difficulty,
        'zone': zone,
        'scoringMode': ?scoringMode,
        'attemptNumber': ?attemptNumber,
        'durationSeconds': ?durationSeconds,
      },
    });

    return outcome;
  }
}

QuestionModel _mockQuestion({
  required String id,
  required int level,
  String correct = 'A',
}) {
  return QuestionModel(
    questionId: id,
    level: level,
    domain: 'Number Identification',
    gradeTag: 'Grade 1-3',
    difficulty: level % 5 == 0 ? 'Challenge' : 'Preparation',
    questionText: 'What is 1 + 1?',
    choices: const {
      'A': '2',
      'B': '3',
      'C': '4',
      'D': '5',
    },
    correctAnswer: correct,
    challengeGroup: 1,
    attemptNumber: 0,
  );
}

void main() {
  group('Batch 9D — AnsweringTimer Unit Tests', () {
    test('1. Opening a level without answering does not start the timer', () {
      final timer = AnsweringTimer();
      expect(timer.hasStarted, isFalse);
      expect(timer.isRunning, isFalse);
      expect(timer.isPaused, isFalse);
      expect(timer.isStopped, isFalse);
      expect(timer.elapsedSeconds, isNull,
          reason: 'Unstarted timer must return null to distinguish from recorded 0s');
      expect(timer.elapsedDuration, Duration.zero);
    });

    test('2. First answer interaction starts timing', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      expect(timer.hasStarted, isTrue);
      expect(timer.isRunning, isTrue);
      expect(timer.isPaused, isFalse);
      expect(timer.isStopped, isFalse);
      expect(timer.elapsedSeconds, isNotNull);
    });

    test('3. Repeated answer taps do not restart or duplicate the timer', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 12));

      // Attempt repeated starts
      timer.startOnFirstInteraction();
      timer.startOnFirstInteraction();

      expect(timer.hasStarted, isTrue);
      expect(timer.elapsedSeconds, greaterThanOrEqualTo(12));
    });

    test('4. Moving between questions preserves elapsed answering time', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 8));

      // Question 1 feedback overlay
      timer.pause();
      expect(timer.isRunning, isFalse);
      expect(timer.isPaused, isTrue);

      // Question 2 begins
      timer.resume();
      expect(timer.isRunning, isTrue);
      expect(timer.isPaused, isFalse);
      timer.debugAddElapsed(const Duration(seconds: 7));

      // Cumulative active time across questions
      expect(timer.elapsedSeconds, greaterThanOrEqualTo(15));
    });

    test('5. Feedback dialogs pause timing and resume correctly', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 5));

      timer.pause();
      expect(timer.isPaused, isTrue);
      expect(timer.isRunning, isFalse);
      final pausedSeconds = timer.elapsedSeconds;

      // Time while paused should not accrue active answering time
      timer.resume();
      expect(timer.isPaused, isFalse);
      expect(timer.isRunning, isTrue);
      expect(timer.elapsedSeconds, equals(pausedSeconds));
    });

    test('6. App background/inactive pauses timing', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 10));

      // App backgrounded
      timer.pause();
      expect(timer.isPaused, isTrue);
      expect(timer.isRunning, isFalse);
    });

    test('7. Returning to active gameplay resumes timing correctly', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 10));

      timer.pause();
      timer.resume();
      expect(timer.isRunning, isTrue);
      expect(timer.isPaused, isFalse);
      timer.debugAddElapsed(const Duration(seconds: 5));
      expect(timer.elapsedSeconds, greaterThanOrEqualTo(15));
    });

    test('8. Successful completion stops and records duration', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 25));

      timer.stop();
      expect(timer.isStopped, isTrue);
      expect(timer.isRunning, isFalse);
      final finalDuration = timer.elapsedSeconds;
      expect(finalDuration, equals(25));

      // Subsequent resume or start cannot restart a stopped attempt
      timer.resume();
      expect(timer.isRunning, isFalse);
      timer.startOnFirstInteraction();
      expect(timer.isRunning, isFalse);
      expect(timer.elapsedSeconds, equals(25));
    });

    test('9. Genuinely recorded zero-second duration is distinguishable from missing', () {
      final unstartedTimer = AnsweringTimer();
      expect(unstartedTimer.elapsedSeconds, isNull);

      final zeroTimer = AnsweringTimer();
      zeroTimer.startOnFirstInteraction();
      zeroTimer.stop();
      expect(zeroTimer.elapsedSeconds, equals(0));
    });

    test('10. Resetting timer creates a fresh state without leakage', () {
      final timer = AnsweringTimer();
      timer.startOnFirstInteraction();
      timer.debugAddElapsed(const Duration(seconds: 45));
      timer.stop();
      expect(timer.elapsedSeconds, equals(45));

      timer.reset();
      expect(timer.hasStarted, isFalse);
      expect(timer.isRunning, isFalse);
      expect(timer.isStopped, isFalse);
      expect(timer.elapsedSeconds, isNull);
    });
  });

  group('Batch 9D — LevelProvider Gameplay & Persistence Flow', () {
    late TestSupabaseService testSupabase;
    late LevelProvider provider;
    late List<QuestionModel> seedQuestions;

    setUp(() {
      testSupabase = TestSupabaseService();
      seedQuestions = [
        _mockQuestion(id: 'L1-Q1', level: 1, correct: 'A'),
        _mockQuestion(id: 'L1-Q2', level: 1, correct: 'B'),
        _mockQuestion(id: 'L5-Q1', level: 5, correct: 'A'),
        _mockQuestion(id: 'L5-Q2', level: 5, correct: 'B'),
      ];
      provider = LevelProvider(
        supabaseService: testSupabase,
        dryRun: false,
      );
    });

    test('11. Opening a level does not start the timer until answer interaction', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      expect(provider.phase, PlayerPhase.playing);
      expect(provider.answeringTimer.hasStarted, isFalse,
          reason: 'Timer must NOT start on level entry or question display');
      expect(provider.answeringTimer.elapsedSeconds, isNull);
    });

    test('12. Submitting first answer starts timer and pauses during feedback', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      // Wrong answer to observe feedback overlay
      await provider.submitAnswer('B'); // Question L1-Q1 correct answer is 'A'

      expect(provider.answeringTimer.hasStarted, isTrue);
      expect(provider.feedbackPending, isTrue);
      expect(provider.answeringTimer.isPaused, isTrue,
          reason: 'Feedback dialog must pause answering timer');
    });

    test('13. Dismissing feedback resumes answering timer', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      await provider.submitAnswer('B'); // Wrong answer
      expect(provider.answeringTimer.isPaused, isTrue);

      provider.dismissFeedback();
      expect(provider.feedbackPending, isFalse);
      expect(provider.answeringTimer.isRunning, isTrue,
          reason: 'Dismissing feedback must resume timer for active question retry');
    });

    test('14. Successful completion stops timer and persists durationSeconds in result_data', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      // Advance mock timer
      provider.recordAnswerInteraction();
      provider.answeringTimer.debugAddElapsed(const Duration(seconds: 42));

      // Correct answer completes level 1
      final q = provider.currentQuestion!;
      final correctOpt = q.choiceOptions.firstWhere((o) => o.isCorrect);
      await provider.submitAnswer(correctOpt.displayLabel);

      expect(provider.phase, PlayerPhase.levelComplete);
      expect(provider.answeringTimer.isStopped, isTrue);
      expect(testSupabase.recordedStudentResults.length, equals(1));

      final savedRow = testSupabase.recordedStudentResults.first;
      expect(savedRow['level_number'], equals(1));
      expect(savedRow['assessment_type'], equals('LEVEL_PRACTICE'));

      final resultData = savedRow['result_data'] as Map<String, dynamic>;
      expect(resultData['durationSeconds'], equals(42),
          reason: 'durationSeconds must be persisted as nonnegative integer in result_data');
      expect(resultData['scoringMode'], equals('CHANCE_OF_3'),
          reason: 'Existing result_data keys must be preserved');
      expect(resultData['attemptNumber'], equals(1),
          reason: 'Existing result_data keys must be preserved');
    });

    test('15. Out of hearts stops timer without producing unauthorized student_results', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      // Fail 3 hearts
      for (int i = 0; i < 3; i++) {
        final q = provider.currentQuestion!;
        final wrongOpt = q.choiceOptions.firstWhere((o) => !o.isCorrect);
        await provider.submitAnswer(wrongOpt.displayLabel);
        if (i < 2) {
          provider.dismissFeedback();
        }
      }

      expect(provider.hearts, equals(0));
      expect(provider.phase, PlayerPhase.outOfHearts);
      expect(provider.answeringTimer.isStopped, isTrue,
          reason: 'Timer must stop when out of hearts');
      expect(testSupabase.recordedStudentResults.isEmpty, isTrue,
          reason: 'Failed attempts must not create student_results LEVEL_PRACTICE records');
    });

    test('16. Restarting level for hearts creates a fresh timer', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );
      provider.recordAnswerInteraction();
      provider.answeringTimer.debugAddElapsed(const Duration(seconds: 30));

      provider.restartLevelForHearts();
      expect(provider.hearts, equals(LevelProvider.kMaxHearts));
      expect(provider.answeringTimer.hasStarted, isFalse,
          reason: 'Fresh attempt must reset answering timer');
      expect(provider.answeringTimer.elapsedSeconds, isNull);
    });

    test('17. App lifecycle pause and resume methods coordinate correctly', () async {
      await provider.startLevel(
        userId: 'test_student',
        lrn: '123456789012',
        level: 1,
        usedHistory: [],
        seedBank: seedQuestions,
      );

      provider.recordAnswerInteraction();
      expect(provider.answeringTimer.isRunning, isTrue);

      // Backgrounded
      provider.pauseAnsweringTimer();
      expect(provider.answeringTimer.isPaused, isTrue);

      // Foregrounded
      provider.resumeAnsweringTimer();
      expect(provider.answeringTimer.isRunning, isTrue);

      // Screen exited
      provider.stopAnsweringTimer();
      expect(provider.answeringTimer.isStopped, isTrue);
    });

    test('18. Star-to-coin reward calculation (Batch 9A) remains intact', () {
      final r0 = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 0,
      );
      expect(r0.coinGain, equals(0));

      final r1 = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 1,
      );
      expect(r1.coinGain, equals(5));

      final r2 = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 2,
      );
      expect(r2.coinGain, equals(10));

      final r3 = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 3,
      );
      expect(r3.coinGain, equals(15));
    });

    test('19. StudentResult model deserializes durationSeconds from result_data', () {
      final jsonMap = {
        'id': 'res_123',
        'student_uid': 'stu_456',
        'score': 3,
        'max_score': 3,
        'percentage': 100.0,
        'assessment_type': 'LEVEL_PRACTICE',
        'durationSeconds': 85,
      };

      final model = StudentResult.fromMap(jsonMap, 'res_123');
      expect(model.durationSeconds, equals(85));

      // Also tolerates missing duration (historical row)
      final histMap = {
        'id': 'res_old',
        'student_uid': 'stu_456',
        'score': 2,
        'max_score': 3,
        'percentage': 66.7,
        'assessment_type': 'LEVEL_PRACTICE',
      };
      final histModel = StudentResult.fromMap(histMap, 'res_old');
      expect(histModel.durationSeconds, isNull);
    });
  });
}
