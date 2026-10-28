import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/core/theme/mathalino_tokens.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_sections.dart';
import 'package:mathalino_student_app/widgets/home/home_widgets.dart';

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
  LevelState getLevelState(int level) {
    if (level < 30) return LevelState.completed;
    if (level == 30) return LevelState.unlocked;
    return LevelState.locked;
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory(
    r'C:\Users\saboc\.gemini\antigravity-ide\brain\4e4d537e-f6a2-4fbe-b575-4f47b1776962',
  );

  Future<void> captureScreen({
    required WidgetTester tester,
    required Size size,
    required String filename,
    required int tabIndex,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintBoundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>(create: (_) => MockAuthService()),
          ChangeNotifierProvider<LevelProgressProvider>(
              create: (_) => MockLevelProgressProvider()),
          ChangeNotifierProvider<LearnProvider>(
              create: (_) => MockLearnProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: repaintBoundaryKey,
            child: Scaffold(
              backgroundColor: AppTokens.background,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    if (tabIndex == 1 || tabIndex == 2)
                      const HomeHeader(
                        name: 'fettiz',
                        level: 30,
                        coins: 120,
                        xp: 340,
                        stars: 45,
                      ),
                    Expanded(child: child),
                  ],
                ),
              ),
              bottomNavigationBar: HomeBottomNav(
                selectedIndex: tabIndex,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('${outDir.path}/$filename');
          file.writeAsBytesSync(byteData.buffer.asUint8List());
          print('Captured screenshot: ${file.path}');
        }
      }
    });
  }

  testWidgets('Capture Learn 390', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'restyled_learn_390.png',
      tabIndex: 1,
      child: const AdventureLearnView(),
    );
  });

  testWidgets('Capture Progress 390', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'restyled_progress_390.png',
      tabIndex: 2,
      child: const AdventureProgressView(),
    );
  });

  testWidgets('Capture Profile 390', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'restyled_profile_390.png',
      tabIndex: 3,
      child: const AdventureProfileView(),
    );
  });

  testWidgets('Capture Learn 360', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(360, 640),
      filename: 'restyled_learn_360.png',
      tabIndex: 1,
      child: const AdventureLearnView(),
    );
  });

  testWidgets('Capture Progress 360', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(360, 640),
      filename: 'restyled_progress_360.png',
      tabIndex: 2,
      child: const AdventureProgressView(),
    );
  });

  testWidgets('Capture Profile 360', (tester) async {
    await captureScreen(
      tester: tester,
      size: const Size(360, 640),
      filename: 'restyled_profile_360.png',
      tabIndex: 3,
      child: const AdventureProfileView(),
    );
  });
}
