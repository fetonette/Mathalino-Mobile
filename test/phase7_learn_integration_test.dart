import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_sections.dart';
import 'package:mathalino_student_app/screens/student/module_lessons_screen.dart';
import 'package:mathalino_student_app/screens/student/lesson_detail_screen.dart';

class MockPhase7AuthService extends ChangeNotifier implements AuthService {
  @override
  StudentProfile? get studentProfile => const StudentProfile(
        uid: 'student-test-uid',
        displayName: 'Test Student',
        lrn: '123456789028',
        gradeLevel: 3,
        gradeLevelLabel: 'Grade 3',
        section: 'Heart',
        currentLevel: 10,
        startingLevel: 1,
        assignedCategory: 'Beginner',
        stats: StudentStats(),
        usedQuestionsHistory: [],
        diagnosticCompleted: true,
        verificationCode: '123456',
      );

  @override
  bool get isAuthenticated => true;

  @override
  bool get isStudent => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPhase7LearnProvider extends ChangeNotifier implements LearnProvider {
  List<TeacherPublishedModule> _modules = const [];
  List<PublishedLessonSummary> _lessons = const [];
  PublishedLessonDetail? _detail;
  bool _loading = false;
  String? _error;

  void setModules(List<TeacherPublishedModule> modules) {
    _modules = modules;
    notifyListeners();
  }

  void setLessons(List<PublishedLessonSummary> lessons) {
    _lessons = lessons;
    notifyListeners();
  }

  void setDetail(PublishedLessonDetail detail) {
    _detail = detail;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  @override
  List<TeacherPublishedModule> get publishedModules => _modules;

  @override
  bool get hasPublishedModules => _modules.isNotEmpty;

  @override
  bool get isLoading => _loading;

  @override
  String? get errorMessage => _error;

  @override
  bool get isInitialized => true;

  @override
  Future<void> loadPublishedModules({bool force = false}) async {}

  @override
  Future<void> refreshPublishedModules() async {}

  @override
  Future<List<PublishedLessonSummary>> fetchModuleLessons(String moduleId) async {
    return _lessons;
  }

  @override
  Future<PublishedLessonDetail> fetchLessonDetail(String lessonId) async {
    if (_error != null) throw StateError(_error!);
    return _detail!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget wrapWithTestProviders(Widget child, {MockPhase7LearnProvider? learnProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => MockPhase7AuthService()),
      ChangeNotifierProvider<LearnProvider>(
        create: (_) => learnProvider ?? MockPhase7LearnProvider(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Phase 7: Data Models & Resilient Mapping', () {
    test('TeacherPublishedModule correctly calculates published lesson count from join', () {
      final json = {
        'id': 'mod-uuid-123',
        'teacher_id': 'teacher-uuid-456',
        'title': 'Multiplication Mastery Module',
        'description': 'Mastering basic facts and array models.',
        'grade_level': 'Grade 3',
        'display_order': 1,
        'status': 'published',
        'created_at': '2026-10-27T17:26:22.598Z',
        'math_materials': [
          {'id': 'mat-1', 'status': 'Active', 'review_status': 'published'},
          {'id': 'mat-2', 'status': 'Active', 'review_status': 'published'},
          {'id': 'mat-3', 'status': 'Draft', 'review_status': 'draft'}, // should be excluded
          {'id': 'mat-4', 'status': 'Archived', 'review_status': 'published'}, // should be excluded
        ]
      };

      final mod = TeacherPublishedModule.fromSupabase(json);
      expect(mod.id, 'mod-uuid-123');
      expect(mod.title, 'Multiplication Mastery Module');
      expect(mod.publishedLessonCount, 2);
    });

    test('LessonSequence.fromJson parses resiliently without errors on edge-case types', () {
      final rawLesson = {
        'objectives': 'Single string objective instead of array', // edge case
        'introduction': 'Welcome to multiplication!',
        'explanation': ['Step 1: Multiply ones', 'Step 2: Multiply tens'],
        'keyConcepts': ['Commutative property', 'Distributive property'],
        'workedExamples': [
          {'problem': '12 x 3', 'solution': '36'},
        ],
        'guidedPractice': [
          {'problem': '15 x 2', 'hint': 'Double 15'},
        ],
        'independentPractice': ['20 x 4', '11 x 5'],
        'realLifeApplication': 'Calculating prices when buying multiple notebooks.',
        'checkUnderstanding': ['What is 10 x 5?'],
        'summary': 'Multiplication is repeated addition.',
        'challenge': ['Can you calculate 25 x 4 in your head?']
      };

      final seq = LessonSequence.fromJson(rawLesson);
      expect(seq.objectives, ['Single string objective instead of array']);
      expect(seq.introduction, 'Welcome to multiplication!');
      expect(seq.workedExamples.length, 1);
      expect(seq.workedExamples.first.problem, '12 x 3');
      expect(seq.guidedPractice.length, 1);
      expect(seq.guidedPractice.first.hint, 'Double 15');
      expect(seq.summary, 'Multiplication is repeated addition.');
    });

    test('PublishedLessonDetail maps cleanly into LearnTopic', () {
      final detail = PublishedLessonDetail(
        id: 'lesson-123',
        moduleId: 'mod-123',
        teacherId: 'teacher-123',
        title: 'Multiplication Arrays',
        gradeLevel: 'Grade 3',
        lessonSequence: const LessonSequence(
          objectives: ['Understand arrays'],
          introduction: 'Arrays are grids.',
          explanation: ['Count rows', 'Count columns'],
          keyConcepts: ['Row x Column = Total'],
          workedExamples: [],
          guidedPractice: [],
          independentPractice: [],
          realLifeApplication: 'Egg cartons',
          checkUnderstanding: [],
          summary: 'Arrays model multiplication.',
          challenge: [],
        ),
      );

      final topic = detail.toLearnTopic(moduleName: 'Multiplication');
      expect(topic.id, 'lesson-123');
      expect(topic.title, 'Multiplication Arrays');
      expect(topic.module, 'Multiplication');
      expect(topic.lessonSequence.introduction, 'Arrays are grids.');
    });
  });

  group('Phase 7: Primary Student Learn Screen UI', () {
    testWidgets('Displays EXACT empty state when student has no authorized published modules', (tester) async {
      final mock = MockPhase7LearnProvider();
      mock.setModules([]); // No published modules

      await tester.pumpWidget(wrapWithTestProviders(
        const AdventureLearnView(),
        learnProvider: mock,
      ));
      await tester.pumpAndSettle();

      // Section 7 Requirement: Exactly "Your teacher hasn't added practice lessons yet."
      expect(find.text("Your teacher hasn't added practice lessons yet."), findsOneWidget);

      // Verify no hardcoded curriculum categories are shown
      expect(find.text('Number Sense'), findsNothing);
      expect(find.text('Operations'), findsNothing);
      expect(find.text('Geometry'), findsNothing);
    });

    testWidgets('Displays published teacher modules with dynamic titles and counts', (tester) async {
      final mock = MockPhase7LearnProvider();
      mock.setModules([
        const TeacherPublishedModule(
          id: 'mod-1',
          teacherId: 'teacher-1',
          title: 'Multiplication Mastery Module',
          description: 'Fun word problems and multiplication practice.',
          gradeLevel: 'Grade 3',
          publishedLessonCount: 4,
        ),
      ]);

      await tester.pumpWidget(wrapWithTestProviders(
        const AdventureLearnView(),
        learnProvider: mock,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Multiplication Mastery Module'), findsOneWidget);
      expect(find.text('4 Practice Lessons'), findsOneWidget);
      expect(find.text('Grade 3'), findsOneWidget);
      expect(find.text("Your teacher hasn't added practice lessons yet."), findsNothing);
    });

    testWidgets('Displays recoverable error message with Retry action on network failure', (tester) async {
      final mock = MockPhase7LearnProvider();
      mock.setError('Network connection failed. Please check your internet and retry.');

      await tester.pumpWidget(wrapWithTestProviders(
        const AdventureLearnView(),
        learnProvider: mock,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Network connection failed. Please check your internet and retry.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Phase 7: Module Lessons and Detail Screens', () {
    testWidgets('ModuleLessonsScreen renders dynamic published lessons list', (tester) async {
      final mock = MockPhase7LearnProvider();
      mock.setLessons([
        const PublishedLessonSummary(
          id: 'lesson-1',
          moduleId: 'mod-1',
          teacherId: 'teacher-1',
          title: 'Understanding 2-Digit Multiplication',
          gradeLevel: 'Grade 3',
        ),
        const PublishedLessonSummary(
          id: 'lesson-2',
          moduleId: 'mod-1',
          teacherId: 'teacher-1',
          title: 'Word Problems with Arrays',
          gradeLevel: 'Grade 3',
        ),
      ]);

      await tester.pumpWidget(wrapWithTestProviders(
        const ModuleLessonsScreen(
          publishedModule: TeacherPublishedModule(
            id: 'mod-1',
            teacherId: 'teacher-1',
            title: 'Multiplication Mastery Module',
            publishedLessonCount: 2,
          ),
        ),
        learnProvider: mock,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Multiplication Mastery Module'), findsAtLeastNWidgets(1));
      expect(find.text('Lesson 1'), findsOneWidget);
      expect(find.text('Understanding 2-Digit Multiplication'), findsOneWidget);
      expect(find.text('Lesson 2'), findsOneWidget);
      expect(find.text('Word Problems with Arrays'), findsOneWidget);
    });

    testWidgets('LessonDetailScreen renders all 11 sections and student-safe practice placeholder', (tester) async {
      const seq = LessonSequence(
        objectives: ['Master multiplication facts'],
        introduction: 'Multiplication helps us count fast.',
        explanation: ['Step 1: Write down numbers', 'Step 2: Multiply columns'],
        keyConcepts: ['Factors and products'],
        workedExamples: [
          WorkedExample(problem: '6 x 7', solution: '42'),
        ],
        guidedPractice: [
          GuidedPracticeItem(problem: '8 x 4', hint: 'Double 8 twice'),
        ],
        independentPractice: ['9 x 3'],
        realLifeApplication: 'Counting tiles in a floor grid.',
        checkUnderstanding: ['What is 7 x 7?'],
        summary: 'Multiplication simplifies grouping.',
        challenge: ['Try 12 x 12!'],
      );

      final topic = LearnTopic(
        id: 'lesson-1',
        gradeLevel: 3,
        module: 'Multiplication Mastery',
        title: 'Multiplication Facts',
        rmaCompetencyCodes: const [],
        rmaSource: 'Teacher Practice Material',
        lessonSequence: seq,
      );

      await tester.pumpWidget(wrapWithTestProviders(
        LessonDetailScreen(topic: topic),
      ));
      await tester.pumpAndSettle();

      // Verify all 11 sections are rendered
      expect(find.text('Learning Objectives'), findsOneWidget);
      expect(find.text('Master multiplication facts'), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Multiplication helps us count fast.'), findsOneWidget);
      expect(find.text('Step-by-Step Explanation'), findsOneWidget);
      expect(find.text('Key Concepts & Rules'), findsOneWidget);
      expect(find.text('Worked Examples'), findsOneWidget);
      expect(find.text('Guided Practice'), findsOneWidget);
      expect(find.text('Independent Practice'), findsOneWidget);
      expect(find.text('Real-Life Application'), findsOneWidget);
      expect(find.text('Check Understanding'), findsOneWidget);
      expect(find.text('Lesson Summary'), findsOneWidget);
      expect(find.text('Math Explorer Challenge'), findsOneWidget);

      // Verify Section 12: Practice Questions Entry Point
      expect(find.text('Practice Exercises'), findsOneWidget);
      expect(find.text('5 Interactive Practice Questions'), findsOneWidget);
      expect(find.text('Interactive'), findsOneWidget);
      expect(find.text('Start Practice'), findsOneWidget);
    });
  });
}
