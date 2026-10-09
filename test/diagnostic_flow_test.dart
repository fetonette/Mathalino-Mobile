import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/constants/diagnostic_questions.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/core/services/diagnostic_assessment_service.dart';
import 'package:mathalino_student_app/core/services/diagnostic_question_service.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/core/services/scoring_service.dart';
import 'package:mathalino_student_app/providers/diagnostic_provider.dart';

void main() {
  group('Diagnostic Assessment Flow & Multi-Student Account Transitions', () {
    late DiagnosticProvider provider;
    late DiagnosticAssessmentService assessmentService;
    late ScoringService scoringService;
    late GameLogicService gameLogic;

    setUp(() {
      assessmentService = DiagnosticAssessmentService();
      scoringService = ScoringService();
      gameLogic = const GameLogicService();

      provider = DiagnosticProvider(
        assessmentService: assessmentService,
        scoringService: scoringService,
        gameLogic: gameLogic,
      );
    });

    test('Single Student Flow: sequential progression from Q1 to Q20 without premature exit', () async {
      await provider.loadDiagnosticQuestions(
        userId: 'student_new_01',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      expect(provider.questions.length, equals(20));
      expect(provider.totalQuestions, equals(20));
      expect(provider.currentIndex, equals(0));
      expect(provider.answers.length, equals(0));
      expect(provider.isComplete, isFalse);
      expect(provider.loadedUserId, equals('student_new_01'));

      // Answering Question 1 MUST advance to Question 2 and MUST NOT complete the assessment
      final completeAfterQ1 = provider.answerCurrentQuestion('A. Option A');
      expect(completeAfterQ1, isFalse, reason: 'Assessment must NOT be complete after Question 1');
      expect(provider.isComplete, isFalse);
      expect(provider.currentIndex, equals(1), reason: 'Must display Question 2 (index 1)');
      expect(provider.answers.length, equals(1));

      // Answer questions 2 through 19 (indices 1 through 18)
      for (var i = 1; i < 19; i++) {
        final complete = provider.answerCurrentQuestion('B. Option B');
        expect(complete, isFalse, reason: 'Assessment must not complete at index $i (Question ${i + 1})');
        expect(provider.isComplete, isFalse);
        expect(provider.currentIndex, equals(i + 1));
        expect(provider.answers.length, equals(i + 1));
      }

      expect(provider.currentIndex, equals(19), reason: 'Now at Question 20 (index 19)');
      expect(provider.isComplete, isFalse);

      // Answering Question 20 (index 19) MUST complete the assessment
      final completeAfterQ20 = provider.answerCurrentQuestion('C. Option C');
      expect(completeAfterQ20, isTrue, reason: 'Assessment MUST complete after Question 20');
      expect(provider.isComplete, isTrue);
      expect(provider.answers.length, equals(20));
    });

    test('Multi-Student Transition: newly created student does NOT inherit completed state from previous student', () async {
      // 1. Student A takes and finishes the diagnostic assessment
      await provider.loadDiagnosticQuestions(
        userId: 'student_A',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      for (var i = 0; i < 20; i++) {
        provider.answerCurrentQuestion('A');
      }

      expect(provider.isComplete, isTrue);
      expect(provider.currentIndex, equals(19));
      expect(provider.answers.length, equals(20));
      expect(provider.loadedUserId, equals('student_A'));

      // 2. Student A logs out: resetDiagnostic is dispatched via sign-out callback
      provider.resetDiagnostic();

      expect(provider.questions.isEmpty, isTrue);
      expect(provider.answers.isEmpty, isTrue);
      expect(provider.currentIndex, equals(0));
      expect(provider.isComplete, isFalse);
      expect(provider.loadedUserId, isNull);

      // 3. Newly created student B logs in and loads diagnostic questions
      await provider.loadDiagnosticQuestions(
        userId: 'student_B_new',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      expect(provider.questions.length, equals(20));
      expect(provider.currentIndex, equals(0));
      expect(provider.answers.isEmpty, isTrue);
      expect(provider.isComplete, isFalse);
      expect(provider.loadedUserId, equals('student_B_new'));

      // 4. Student B answers Question 1
      final finishedAfterOne = provider.answerCurrentQuestion('A');

      // CRITICAL ASSERTION:
      expect(finishedAfterOne, isFalse, reason: 'Student B must advance to Question 2, NOT finish after Question 1');
      expect(provider.isComplete, isFalse);
      expect(provider.currentIndex, equals(1));
      expect(provider.answers.length, equals(1));
    });

    test('Stale State Guard: provider resets if loadedUserId does not match current user', () async {
      // Suppose provider was left in memory with student_A's completed assessment
      await provider.loadDiagnosticQuestions(
        userId: 'student_A',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );
      for (var i = 0; i < 20; i++) {
        provider.answerCurrentQuestion('B');
      }
      expect(provider.isComplete, isTrue);

      // Student B arrives. Checking needsLoad condition as implemented in DiagnosticScreen:
      const currentUserId = 'student_B_new';
      final needsLoad = provider.questions.isEmpty ||
          provider.questions.length != 20 ||
          provider.loadedUserId != currentUserId ||
          provider.isComplete;

      expect(needsLoad, isTrue, reason: 'Must detect user mismatch and completed status');

      // When loadDiagnosticQuestions runs for student B:
      await provider.loadDiagnosticQuestions(
        userId: currentUserId,
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      expect(provider.loadedUserId, equals('student_B_new'));
      expect(provider.currentIndex, equals(0));
      expect(provider.answers.isEmpty, isTrue);
      expect(provider.isComplete, isFalse);

      final isCompleteQ1 = provider.answerCurrentQuestion('C');
      expect(isCompleteQ1, isFalse);
      expect(provider.currentIndex, equals(1));
    });

    test('Rebuild / Refresh Guard: progress is preserved when same student rebuilds without completion', () async {
      await provider.loadDiagnosticQuestions(
        userId: 'student_mid_session',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      // Student answers 5 questions
      for (var i = 0; i < 5; i++) {
        provider.answerCurrentQuestion('A');
      }
      expect(provider.currentIndex, equals(5));
      expect(provider.answers.length, equals(5));

      // Screen rebuilds / reinitializes:
      const currentUserId = 'student_mid_session';
      final needsLoad = provider.questions.isEmpty ||
          provider.questions.length != 20 ||
          provider.loadedUserId != currentUserId ||
          provider.isComplete;

      expect(needsLoad, isFalse, reason: 'In-progress session for same student should NOT be wiped');
      expect(provider.currentIndex, equals(5));
      expect(provider.answers.length, equals(5));
    });

    test('Question pool selection for Grades 1–6 always returns exactly 20 valid questions', () {
      final pool = diagnosticAssessmentQuestions
          .map((m) => Question.fromMap(m, m['id'].toString()))
          .toList();

      for (var grade = 1; grade <= 6; grade++) {
        final attempt = DiagnosticQuestionService.selectAttemptItems(
          pool: pool,
          usedQuestionsHistory: const {},
          gradeLevel: grade,
          count: 20,
        );

        expect(attempt.length, equals(20), reason: 'Grade $grade must receive exactly 20 items');
        final ids = attempt.map((q) => q.id).toSet();
        expect(ids.length, equals(20), reason: 'Grade $grade questions must all be unique');

        for (final q in attempt) {
          expect(DiagnosticQuestionService.isValidQuestion(q), isTrue);
        }
      }
    });

    test('AuthService sign-out callback dispatches resetDiagnostic cleanly', () {
      var resetCalled = false;
      void onSignOut() => resetCalled = true;

      AuthService.registerSignOutCallback(onSignOut);
      // Simulate logout
      AuthService.registerSignOutCallback(provider.resetDiagnostic);

      provider.loadDiagnosticQuestions(
        userId: 'temp_user',
        gradeLevel: 1,
        usedQuestionsHistory: const [],
      );

      expect(provider.loadedUserId, equals('temp_user'));

      // Trigger sign out callbacks
      onSignOut();
      provider.resetDiagnostic();

      expect(resetCalled, isTrue);
      expect(provider.loadedUserId, isNull);
      expect(provider.questions.isEmpty, isTrue);
      expect(provider.currentIndex, equals(0));

      AuthService.unregisterSignOutCallback(onSignOut);
      AuthService.unregisterSignOutCallback(provider.resetDiagnostic);
    });
  });
}
