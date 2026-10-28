import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_sections.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  final StudentProfile? _profile = StudentProfile(
    uid: 'test_uid',
    displayName: 'fettiz',
    lrn: '123456789018',
    gradeLevel: 4,
    gradeLevelLabel: 'Grade 4',
    section: 'Cute',
    currentLevel: 30,
    startingLevel: 21,
    assignedCategory: 'Intermediate',
    diagnosticScore: 12,
    diagnosticPercentage: 60.0,
    isParentLinked: true,
    parentGuardianEmail: 'maria.santos@gmail.com',
    usedQuestionsHistory: const [],
    diagnosticCompleted: true,
    verificationCode: '123456',
    stats: StudentStats(
      coins: 120,
      totalXp: 340,
    ),
  );

  @override
  StudentProfile? get studentProfile => _profile;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isStudent => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLevelProgressProvider extends ChangeNotifier
    implements LevelProgressProvider {
  @override
  int get currentLevel => 30;

  @override
  bool get isLoading => false;

  @override
  StudentProfile? get studentProfile => null;

  @override
  int get totalStars => 45;

  @override
  LevelState getLevelState(int level) {
    if (level < 30) return LevelState.completed;
    if (level == 30) return LevelState.unlocked;
    return LevelState.locked;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLearnProvider extends ChangeNotifier implements LearnProvider {
  List<TeacherPublishedModule> _modules = const [];
  bool _loading = false;
  String? _error;

  void setPublishedModules(List<TeacherPublishedModule> modules) {
    _modules = modules;
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
  Future<void> loadForStudent(StudentProfile? profile) async {}

  @override
  GradeLearnContent? get currentGradeContent => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildTestableWidget(
  Widget child, {
  Size size = const Size(390, 844),
  MockLearnProvider? learnProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => MockAuthService()),
      ChangeNotifierProvider<LevelProgressProvider>(
          create: (_) => MockLevelProgressProvider()),
      ChangeNotifierProvider<LearnProvider>(
          create: (_) => learnProvider ?? MockLearnProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Learn Screen Tests (Phase 7)', () {
    testWidgets('Renders exact empty state when teacher hasn\'t added lessons yet',
        (tester) async {
      final mockLearn = MockLearnProvider();
      await tester.pumpWidget(buildTestableWidget(
        const AdventureLearnView(),
        learnProvider: mockLearn,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Learn'), findsOneWidget);
      expect(
        find.text('Choose a module and keep building your math skills.'),
        findsOneWidget,
      );
      // Section 7: Exact required empty state text
      expect(
        find.text("Your teacher hasn't added practice lessons yet."),
        findsOneWidget,
      );
      expect(find.text('Check for Updates'), findsOneWidget);
    });

    testWidgets('Renders dynamic teacher-published modules and lesson counts',
        (tester) async {
      final mockLearn = MockLearnProvider();
      mockLearn.setPublishedModules([
        const TeacherPublishedModule(
          id: 'mod-1',
          teacherId: 'teacher-1',
          title: 'Multiplication Mastery Module',
          description: 'Practice multiplication with fun word problems.',
          gradeLevel: 'Grade 3',
          publishedLessonCount: 3,
        ),
        const TeacherPublishedModule(
          id: 'mod-2',
          teacherId: 'teacher-1',
          title: 'Fractions & Halves',
          description: 'Discover visual fraction models.',
          gradeLevel: 'Grade 3',
          publishedLessonCount: 1,
        ),
      ]);

      await tester.pumpWidget(buildTestableWidget(
        const AdventureLearnView(),
        learnProvider: mockLearn,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Multiplication Mastery Module'), findsOneWidget);
      expect(find.text('3 Practice Lessons'), findsOneWidget);
      expect(find.text('Fractions & Halves'), findsOneWidget);
      expect(find.text('1 Practice Lesson'), findsOneWidget);
    });

    testWidgets('Renders recoverable error state with retry button',
        (tester) async {
      final mockLearn = MockLearnProvider();
      mockLearn.setError('Network connection failed. Please check your internet and retry.');

      await tester.pumpWidget(buildTestableWidget(
        const AdventureLearnView(),
        learnProvider: mockLearn,
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Network connection failed. Please check your internet and retry.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Renders on 360px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(
        const AdventureLearnView(),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Progress Screen Tests', () {
    testWidgets('Renders title, hero card, 3 stat tiles, and empty state',
        (tester) async {
      bool learnNavigated = false;
      await tester.pumpWidget(buildTestableWidget(
        AdventureProgressView(
          onNavigateToLearn: () => learnNavigated = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Progress'), findsOneWidget);
      expect(find.text('29 of 60 levels completed'), findsOneWidget);
      expect(find.text('48%'), findsOneWidget);

      // Stat tiles
      expect(find.text('Current level'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('12/20'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // Activity performance card
      expect(find.text('Activity performance'), findsOneWidget);
      expect(
        find.text('Finish a Learn activity and your scores will show up here.'),
        findsOneWidget,
      );
      expect(find.text('Go to Learn'), findsOneWidget);

      // Tap Go to Learn
      await tester.tap(find.text('Go to Learn'));
      expect(learnNavigated, isTrue);
    });

    testWidgets('Renders on 360px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(
        const AdventureProgressView(),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Profile Screen Tests', () {
    testWidgets('Renders hero card with avatar, my details, and log out',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AdventureProfileView()));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('fettiz'), findsAtLeastNWidgets(1));
      expect(find.text('Grade 4 · Cute'), findsOneWidget);
      expect(find.text('Current Level: 30'), findsOneWidget);
      expect(find.text('120 Coins'), findsOneWidget);
      expect(find.text('45 Stars'), findsOneWidget);

      // My details card
      expect(find.text('My details'), findsOneWidget);
      expect(find.text('LRN'), findsOneWidget);
      expect(find.text('123456789018'), findsOneWidget);
      expect(find.text('Grade level'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Placement'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Starting level'), findsOneWidget);
      expect(find.text('Level 21'), findsOneWidget);
      expect(find.text('Parent linked'), findsOneWidget);
      expect(find.text('✓ Yes'), findsOneWidget);
      expect(find.text('Parent email'), findsOneWidget);
      expect(find.text('maria.santos@gmail.com'), findsOneWidget);

      // Log out button
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('Renders on 360px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(
        const AdventureProfileView(),
        size: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
