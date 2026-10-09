import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/providers/remediation_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_map_screen.dart';

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
  User? get user => null;

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
  LevelState getLevelState(int level) {
    if (level < 30) return LevelState.completed;
    if (level == 30) return LevelState.unlocked;
    return LevelState.locked;
  }

  @override
  void initLocal({
    int currentLevel = 1,
    int startingLevel = 1,
    Map<int, String>? customStatusMap,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLearnProvider extends ChangeNotifier implements LearnProvider {
  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  GradeLearnContent? get currentGradeContent => null;

  @override
  Future<void> loadForStudent(StudentProfile? profile) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRemediationProvider extends ChangeNotifier
    implements RemediationProvider {
  @override
  bool get hasActiveSession => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('AdventureMapScreen navigation between tabs and header presence',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => MockAuthService()),
          ChangeNotifierProvider<LevelProgressProvider>(
              create: (_) => MockLevelProgressProvider()),
          ChangeNotifierProvider<LearnProvider>(
              create: (_) => MockLearnProvider()),
          ChangeNotifierProvider<RemediationProvider>(
              create: (_) => MockRemediationProvider()),
        ],
        child: const MaterialApp(
          home: AdventureMapScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Initial tab is Home (0) -> Level Map
    expect(find.text('Continue · Level 30'), findsOneWidget);

    // 2. Navigate to Learn tab (1)
    await tester.tap(find.text('Learn'));
    await tester.pump(const Duration(milliseconds: 200));

    // On Learn: HomeHeader is visible, title 'Learn' is visible
    expect(find.text('fettiz'), findsOneWidget);
    expect(find.text('Level 30'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('340 XP'), findsOneWidget);
    expect(find.text('Choose a module and keep building your math skills.'),
        findsOneWidget);

    // 3. Navigate to Progress tab (2)
    await tester.tap(find.text('Progress'));
    await tester.pump(const Duration(milliseconds: 200));

    // On Progress: HomeHeader is visible, title 'My Progress' is visible
    expect(find.text('fettiz'), findsOneWidget);
    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('29 of 60 levels completed'), findsOneWidget);

    // 4. Test "Go to Learn" button in Progress switches to Learn tab
    await tester.ensureVisible(find.text('Go to Learn'));
    await tester.tap(find.text('Go to Learn'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Choose a module and keep building your math skills.'),
        findsOneWidget);

    // 5. Navigate to Profile tab (3)
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 200));

    // On Profile: NO top HomeHeader (no "Level 30" pill under top avatar),
    // but the hero card has "Current Level: 30" and "Grade 4 · Cute"
    // "Profile" appears twice: title (34px) and bottom nav (13px)
    expect(find.text('Profile'), findsNWidgets(2));
    expect(find.text('My details'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });
}
