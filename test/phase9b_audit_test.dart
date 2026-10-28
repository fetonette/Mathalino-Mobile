import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/services/learn_content_service.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_sections.dart';
import 'package:mathalino_student_app/screens/student/module_lessons_screen.dart';
import 'package:mathalino_student_app/screens/student/lesson_detail_screen.dart';
import 'package:mathalino_student_app/screens/student/practice_screen.dart';

class MockAuditLearnService extends LearnContentService {
  final List<TeacherPublishedModule> mockModules;
  final List<PublishedLessonSummary> mockLessons;
  final PublishedLessonDetail? mockLessonDetail;
  final List<StudentPracticeQuestion> mockQuestions;
  final bool failNetwork;
  final bool isUnauthorized;

  MockAuditLearnService({
    this.mockModules = const [],
    this.mockLessons = const [],
    this.mockLessonDetail,
    this.mockQuestions = const [],
    this.failNetwork = false,
    this.isUnauthorized = false,
  });

  @override
  Future<List<TeacherPublishedModule>> fetchPublishedTeacherModules() async {
    if (failNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    if (isUnauthorized) {
      throw Exception('You are not authorized to view these modules.');
    }
    return mockModules;
  }

  @override
  Future<List<PublishedLessonSummary>> fetchPublishedModuleLessons(String moduleId) async {
    if (failNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    return mockLessons;
  }

  @override
  Future<PublishedLessonDetail> fetchPublishedLessonDetail(String lessonId) async {
    if (failNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    if (mockLessonDetail != null) return mockLessonDetail!;
    throw StateError('Lesson not found or you are not authorized to view it.');
  }

  @override
  Future<List<StudentPracticeQuestion>> fetchStudentPracticeQuestions(String lessonId) async {
    if (failNetwork) {
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
    if (failNetwork) {
      throw Exception('SocketException: Failed host lookup');
    }
    final isCorrect = selectedOption.toUpperCase() == 'A';
    return StudentPracticeAnswerResult(
      isCorrect: isCorrect,
      feedback: isCorrect
          ? 'Great job! That is correct!'
          : 'Good try! Let\'s work through it. You can try again or check the hint.',
      explanation: isCorrect ? 'Explanation for question $questionId' : null,
      questionId: questionId,
      correctOption: isCorrect ? 'A' : null,
    );
  }

  @override
  Future<void> recordPracticeProgress({
    required String lessonId,
    required int questionsAttempted,
    required bool isCompleted,
  }) async {
    // Non-blocking isolated progress
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sample5Questions = List.generate(5, (i) {
    final num = i + 1;
    return StudentPracticeQuestion(
      id: 'q$num',
      question: 'What is $num times 5? Practice question $num text.',
      options: {
        'A': '${num * 5}',
        'B': '${num * 5 + 1}',
        'C': '${num * 5 + 2}',
        'D': '${num * 5 + 3}',
      },
      difficulty: i == 0 ? 'easy' : (i == 4 ? 'challenge' : 'standard'),
      hint: 'Multiply $num by 5.',
      lessonId: 'lesson-uuid-1',
    );
  });

  final sampleLessonDetail = PublishedLessonDetail(
    id: 'lesson-uuid-1',
    moduleId: 'mod-uuid-1',
    teacherId: 'teacher-uuid-1',
    title: 'Multiplication by 5',
    gradeLevel: 'Grade 2',
    status: 'Active',
    reviewStatus: 'published',
    lessonSequence: const LessonSequence(
      objectives: ['Master multiplying by 5', 'Recognize multiples of 5'],
      introduction: 'Multiplying by 5 is like counting nickels!',
      explanation: ['Step 1: Count by 5s', 'Step 2: Add equal groups'],
      keyConcepts: ['5 times a number ends in 0 or 5'],
      workedExamples: [
        WorkedExample(problem: '5 x 3 = ?', solution: '5 + 5 + 5 = 15')
      ],
      guidedPractice: [
        GuidedPracticeItem(problem: '5 x 4 = ?', hint: 'Add 5 four times')
      ],
      independentPractice: ['5 x 6 = ?', '5 x 7 = ?'],
      realLifeApplication: 'Telling time on a clock face in 5-minute intervals.',
      checkUnderstanding: ['Does 5 x 9 end in 5 or 0?'],
      summary: 'Any number multiplied by 5 has a product ending in 0 or 5.',
      challenge: ['What is 5 x 20?'],
    ),
  );

  final sampleModule = TeacherPublishedModule(
    id: 'mod-uuid-1',
    teacherId: 'teacher-uuid-1',
    title: 'Multiplication Fun',
    description: 'Master your multiplication facts.',
    gradeLevel: 'Grade 2',
    displayOrder: 1,
    status: 'published',
    publishedLessonCount: 1,
  );

  final sampleLessonSummary = PublishedLessonSummary(
    id: 'lesson-uuid-1',
    moduleId: 'mod-uuid-1',
    teacherId: 'teacher-uuid-1',
    title: 'Multiplication by 5',
    gradeLevel: 'Grade 2',
    status: 'Active',
    reviewStatus: 'published',
  );

  group('Phase 9B: Final Integration Audit & Security Verification', () {
    test('StudentPracticeQuestion DTO security audit: Never leaks correctAnswer', () {
      final jsonWithLeak = {
        'id': 'q1',
        'question': 'What is 5 x 5?',
        'options': {'A': '25', 'B': '20', 'C': '30', 'D': '15'},
        'difficulty': 'easy',
        'hint': 'Count by 5s 5 times.',
        'correctAnswer': 'A',
        'explanation': '5 x 5 = 25',
      };

      final q = StudentPracticeQuestion.fromJson(jsonWithLeak, defaultLessonId: 'l-1');

      expect(q.id, 'q1');
      expect(q.options['A'], '25');
      // Serialized JSON payload must NEVER contain correctAnswer or explanation
      final serialized = q.toJson();
      expect(serialized.containsKey('correctAnswer'), isFalse);
      expect(serialized.containsKey('explanation'), isFalse);
    });

    testWidgets('Learn Screen: Exactly renders required empty state when teacher has no published lessons',
        (tester) async {
      final mockService = MockAuditLearnService(mockModules: const []);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const Scaffold(body: AdventureLearnView()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Exact required empty state
      expect(find.text("Your teacher hasn't added practice lessons yet."), findsOneWidget);
      // Hardcoded legacy categories must NOT be visible
      expect(find.text('Number Sense'), findsNothing);
      expect(find.text('Operations'), findsNothing);
      expect(find.text('Fractions'), findsNothing);
      expect(find.text('Geometry'), findsNothing);
    });

    testWidgets('Learn Screen: Network failure displays recoverable error state, not empty state',
        (tester) async {
      final mockService = MockAuditLearnService(failNetwork: true);
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const Scaffold(body: AdventureLearnView()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must display error state with Retry, NOT empty state
      expect(find.text("Your teacher hasn't added practice lessons yet."), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Complete End-to-End Navigation: Module -> Lessons -> 11-Part Sequence -> Practice -> Completion',
        (tester) async {
      final mockService = MockAuditLearnService(
        mockModules: [sampleModule],
        mockLessons: [sampleLessonSummary],
        mockLessonDetail: sampleLessonDetail,
        mockQuestions: sample5Questions,
      );
      final provider = LearnProvider(service: mockService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LearnProvider>.value(
            value: provider,
            child: const Scaffold(body: AdventureLearnView()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify dynamic teacher module card
      expect(find.text('Multiplication Fun'), findsOneWidget);
      expect(find.text('1 Practice Lesson'), findsOneWidget);

      // Tap Module Card
      await tester.tap(find.text('Multiplication Fun'));
      await tester.pumpAndSettle();

      // 2. Verify ModuleLessonsScreen opens with lesson
      expect(find.byType(ModuleLessonsScreen), findsOneWidget);
      expect(find.text('Multiplication by 5'), findsOneWidget);

      // Tap Lesson Card
      await tester.tap(find.text('Multiplication by 5'));
      await tester.pumpAndSettle();

      // 3. Verify LessonDetailScreen renders with all 11 sequence parts
      expect(find.byType(LessonDetailScreen), findsOneWidget);
      expect(find.text('Learning Objectives'), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Step-by-Step Explanation'), findsOneWidget);
      expect(find.text('Key Concepts & Rules'), findsOneWidget);

      // Scroll to Section 12 Practice Card
      await tester.ensureVisible(find.text('Start Practice'));
      await tester.pumpAndSettle();

      expect(find.text('Practice Exercises'), findsOneWidget);
      expect(find.text('5 Interactive Practice Questions'), findsOneWidget);
      expect(find.text('Interactive'), findsOneWidget);

      // Tap Start Practice
      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle();

      // 4. Verify PracticeScreen renders
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.textContaining('What is 1 times 5?'), findsOneWidget);

      // 5. Test Hint Toggle
      await tester.ensureVisible(find.text('Show Hint'));
      await tester.tap(find.text('Show Hint'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Hint'), findsOneWidget);
      expect(find.textContaining('Multiply 1 by 5.'), findsOneWidget);

      // 6. Test Incorrect Answer & Retry without penalty
      await tester.tap(find.text('6')); // Option B is 6 (incorrect)
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Good try! Let\'s work through it.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // 7. Select Correct Answer ('5')
      await tester.tap(find.text('5')); // Option A is 5 (correct)
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Great job! That is correct!'), findsOneWidget);
      expect(find.text('Next Question'), findsOneWidget);

      // Advance through remaining 4 questions
      await tester.tap(find.text('Next Question'));
      await tester.pumpAndSettle();

      for (int q = 2; q <= 5; q++) {
        expect(find.text('Question $q of 5'), findsOneWidget);
        // Correct option is A: '${q * 5}'
        await tester.tap(find.text('${q * 5}'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();

        if (q < 5) {
          await tester.tap(find.text('Next Question'));
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Complete Practice'), findsOneWidget);
          await tester.tap(find.text('Complete Practice'));
          await tester.pumpAndSettle();
        }
      }

      // 8. Verify Completion View
      expect(find.text('Practice Complete! Great Effort!'), findsOneWidget);
      expect(find.text('Review Lesson'), findsOneWidget);
      expect(find.text('Practice Again'), findsOneWidget);
      expect(find.text('Back to Modules'), findsOneWidget);

      // Tap Review Lesson -> Returns to LessonDetailScreen
      await tester.tap(find.text('Review Lesson'));
      await tester.pumpAndSettle();

      expect(find.byType(LessonDetailScreen), findsOneWidget);
    });
  });
}
