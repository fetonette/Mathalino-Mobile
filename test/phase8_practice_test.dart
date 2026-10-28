import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/services/learn_content_service.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/screens/student/practice_screen.dart';
import 'package:mathalino_student_app/screens/student/lesson_detail_screen.dart';

/// Test mock implementation of [LearnContentService] for Phase 8 testing
class MockPhase8LearnContentService extends LearnContentService {
  final List<StudentPracticeQuestion> mockQuestions;
  final bool shouldFailNetwork;
  final bool isUnauthorized;

  MockPhase8LearnContentService({
    this.mockQuestions = const [],
    this.shouldFailNetwork = false,
    this.isUnauthorized = false,
  });

  @override
  Future<List<StudentPracticeQuestion>> fetchStudentPracticeQuestions(String lessonId) async {
    if (shouldFailNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    if (isUnauthorized) {
      throw Exception('You are not authorized to access practice questions from this teacher.');
    }
    return mockQuestions;
  }

  @override
  Future<StudentPracticeAnswerResult> checkPracticeAnswer({
    required String lessonId,
    required String questionId,
    required String selectedOption,
  }) async {
    if (shouldFailNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    // Simulate server-side verification: for q1 'A' is correct, for others 'B' is correct
    final isCorrect = (questionId == 'q1' && selectedOption == 'A') ||
        (questionId != 'q1' && selectedOption == 'B');

    return StudentPracticeAnswerResult(
      isCorrect: isCorrect,
      feedback: isCorrect
          ? 'Great job! That is correct!'
          : 'Good try! Let\'s work through it. You can try again or check the hint.',
      explanation: isCorrect ? 'Because 14 multiplied by 3 equals 42.' : null,
      questionId: questionId,
      correctOption: isCorrect ? selectedOption : null,
    );
  }

  @override
  Future<void> recordPracticeProgress({
    required String lessonId,
    required int questionsAttempted,
    required bool isCompleted,
  }) async {
    // Mock no-op
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleQuestions = List.generate(5, (index) {
    final qNum = index + 1;
    return StudentPracticeQuestion(
      id: 'q$qNum',
      question: 'What is ${qNum * 10} plus 5? A word problem with mathematical reasoning.',
      options: {
        'A': '${qNum * 10 + 5}',
        'B': '${qNum * 10 + 2}',
        'C': '${qNum * 10}',
        'D': '${qNum * 10 + 10}',
      },
      difficulty: index == 0 ? 'easy' : (index == 4 ? 'challenge' : 'standard'),
      hint: 'Think about adding 5 to ${qNum * 10}.',
      lessonId: 'lesson-123',
    );
  });

  group('Phase 8: Data Models & Answer Key Protection', () {
    test('StudentPracticeQuestion strictly omits correctAnswer and maps safely', () {
      final json = {
        'id': 'q1',
        'question': 'What is 14 x 3?',
        'options': {'A': '42', 'B': '32', 'C': '45', 'D': '54'},
        'difficulty': 'easy',
        'hint': 'Break 14 into 10 + 4.',
        // Even if malicious/accidental server response contained correctAnswer, DTO does not expose it
        'correctAnswer': 'A',
      };

      final question = StudentPracticeQuestion.fromJson(json, defaultLessonId: 'lesson-abc');

      expect(question.id, 'q1');
      expect(question.question, 'What is 14 x 3?');
      expect(question.options['A'], '42');
      expect(question.options['B'], '32');
      expect(question.difficulty, 'easy');
      expect(question.hint, 'Break 14 into 10 + 4.');
      expect(question.lessonId, 'lesson-abc');
      // Verify serialization never contains correctAnswer
      expect(question.toJson().containsKey('correctAnswer'), isFalse);
    });

    test('StudentPracticeAnswerResult parses server evaluation accurately', () {
      final json = {
        'is_correct': true,
        'feedback': 'Great job! That is correct!',
        'explanation': '14 x 3 = 42.',
        'question_id': 'q1',
        'correct_option': 'A',
      };

      final result = StudentPracticeAnswerResult.fromJson(json);

      expect(result.isCorrect, isTrue);
      expect(result.feedback, 'Great job! That is correct!');
      expect(result.explanation, '14 x 3 = 42.');
      expect(result.questionId, 'q1');
      expect(result.correctOption, 'A');
    });
  });

  group('Phase 8: Interactive Practice UI & Retry Flows', () {
    testWidgets('Renders Question 1 of 5, question text, 4 options, and difficulty',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const PracticeScreen(
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
              moduleTitle: 'Operations',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Multiplication Fundamentals'), findsOneWidget);
      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.textContaining('What is 10 plus 5?'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Check Answer'), findsOneWidget);
    });

    testWidgets('Toggling Show Hint expands and hides hint without giving away the answer',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const PracticeScreen(
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Show Hint'));
      expect(find.text('Show Hint'), findsOneWidget);
      expect(find.textContaining('Think about adding 5'), findsNothing);

      // Tap Show Hint
      await tester.tap(find.text('Show Hint'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Hint'), findsOneWidget);
      expect(find.textContaining('Think about adding 5'), findsOneWidget);

      // Tap Hide Hint
      await tester.ensureVisible(find.text('Hide Hint'));
      await tester.tap(find.text('Hide Hint'));
      await tester.pumpAndSettle();

      expect(find.text('Show Hint'), findsOneWidget);
      expect(find.textContaining('Think about adding 5'), findsNothing);
    });

    testWidgets('Correct answer displays celebration feedback, explanation, and Next Question',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const PracticeScreen(
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Option A is '15' (the correct option for q1 in mock)
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Tap Check Answer
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Great job! That is correct!'), findsOneWidget);
      expect(find.textContaining('Because 14 multiplied by 3 equals 42.'), findsOneWidget);
      expect(find.text('Next Question'), findsOneWidget);
    });

    testWidgets('Incorrect answer displays supportive feedback, allows Retry without penalty',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const PracticeScreen(
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Option B is '12' (incorrect for q1)
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();

      // Tap Check Answer
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Good try! Let\'s work through it.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Tap Try Again to reset selection and retry
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Selection reset: Check Answer is disabled again until an option is selected
      expect(find.text('Check Answer'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);

      // Now select option A
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Check Answer is enabled
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    });

    testWidgets('Completing all 5 questions renders Practice Complete screen with actions',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const PracticeScreen(
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Complete all 5 questions sequentially
      for (int i = 0; i < 5; i++) {
        // Select correct option (A for q1, B for q2..q5)
        final correctText = i == 0 ? '${10 + 5}' : '${(i + 1) * 10 + 2}';
        await tester.tap(find.text(correctText));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();

        if (i < 4) {
          await tester.tap(find.text('Next Question'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Complete Practice'));
          await tester.pumpAndSettle();
        }
      }

      // Friendly completion view
      expect(find.text('Practice Complete! Great Effort!'), findsOneWidget);
      expect(find.text('Review Lesson'), findsOneWidget);
      expect(find.text('Practice Again'), findsOneWidget);
      expect(find.text('Back to Modules'), findsOneWidget);

      // Practice Again resets back to Question 1 of 5
      await tester.tap(find.text('Practice Again'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 5'), findsOneWidget);
    });
  });

  group('Phase 8: LessonDetailScreen Practice Entry Point', () {
    testWidgets('LessonDetailScreen features Start Practice button launching PracticeScreen',
        (tester) async {
      final mockService = MockPhase8LearnContentService(mockQuestions: sampleQuestions);
      final provider = LearnProvider(service: mockService);

      final dummyTopic = LearnTopic(
        id: 'lesson-123',
        gradeLevel: 1,
        module: 'Operations',
        title: 'Multiplication Fundamentals',
        rmaCompetencyCodes: const [],
        rmaSource: 'Teacher Practice',
        lessonSequence: const LessonSequence(
          objectives: ['Learn multiplication'],
          introduction: 'Intro to multiplying numbers.',
          explanation: ['Step 1: Repeat addition'],
          keyConcepts: ['Factors and products'],
          workedExamples: [],
          guidedPractice: [],
          independentPractice: ['3 x 4 = ?'],
          realLifeApplication: 'Counting pairs of shoes',
          checkUnderstanding: ['What is 2 x 2?'],
          summary: 'Multiplication is fast addition.',
          challenge: ['What is 10 x 100?'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: LessonDetailScreen(
              topic: dummyTopic,
              lessonId: 'lesson-123',
              lessonTitle: 'Multiplication Fundamentals',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Start Practice'));
      await tester.pumpAndSettle();

      expect(find.text('Practice Exercises'), findsOneWidget);
      expect(find.text('5 Interactive Practice Questions'), findsOneWidget);
      expect(find.text('Start Practice'), findsOneWidget);

      // Tap Start Practice
      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle();

      // Verify PracticeScreen is launched
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.text('Question 1 of 5'), findsOneWidget);
    });
  });
}
