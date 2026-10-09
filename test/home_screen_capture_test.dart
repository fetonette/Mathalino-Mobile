import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/providers/remediation_provider.dart';
import 'package:mathalino_student_app/screens/student/adventure_map_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  StudentProfile? _profile;
  @override
  StudentProfile? get studentProfile => _profile;
  @override
  User? get user => null;

  void setProfile(StudentProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  @override
  Future<StudentProfile?> ensureProfileLoaded() async => _profile;
  @override
  Future<void> logout() async {}
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    required String studentName,
    required int currentLevel,
    required int startingLevel,
    required int coins,
    required int xp,
    required Map<int, String> statusMap,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockAuth = MockAuthService();
    mockAuth.setProfile(
      StudentProfile(
        uid: 'test_uid',
        lrn: '123456789018',
        displayName: studentName,
        gradeLevel: 1,
        assignedCategory: 'Beginner',
        currentLevel: currentLevel,
        startingLevel: startingLevel,
        stats: StudentStats(coins: coins, totalXp: xp),
        usedQuestionsHistory: [],
        diagnosticCompleted: true,
        verificationCode: '',
      ),
    );

    final levelProvider = LevelProgressProvider();
    levelProvider.initLocal(
      currentLevel: currentLevel,
      startingLevel: startingLevel,
      customStatusMap: statusMap,
    );

    final remediationProvider = RemediationProvider();

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: mockAuth),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: levelProvider),
          ChangeNotifierProvider<RemediationProvider>.value(value: remediationProvider),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: repaintKey,
            child: const AdventureMapScreen(),
          ),
        ),
      ),
    );

    // Let post-frame callbacks, animations and timers settle
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary not found');
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/$filename');
      file.writeAsBytesSync(bytes);
    });
  }

  testWidgets('Capture 1: Mid-zone student at 390x844 (Target spec matching)', (tester) async {
    // 9 of 20 levels in Zone 2 done: levels 21-29 completed, 30 current
    final statusMap = <int, String>{};
    for (int i = 1; i <= 29; i++) {
      statusMap[i] = 'completed';
    }
    statusMap[30] = 'unlocked';
    for (int i = 31; i <= 60; i++) {
      statusMap[i] = 'locked';
    }

    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'after_home_390_midzone.png',
      studentName: 'fettiz',
      currentLevel: 30,
      startingLevel: 1,
      coins: 120,
      xp: 340,
      statusMap: statusMap,
    );
  });

  testWidgets('Capture 2: Mid-zone student at 360x640 (Small screen)', (tester) async {
    final statusMap = <int, String>{};
    for (int i = 1; i <= 29; i++) {
      statusMap[i] = 'completed';
    }
    statusMap[30] = 'unlocked';
    for (int i = 31; i <= 60; i++) {
      statusMap[i] = 'locked';
    }

    await captureScreen(
      tester: tester,
      size: const Size(360, 640),
      filename: 'after_home_360_midzone.png',
      studentName: 'fettiz',
      currentLevel: 30,
      startingLevel: 1,
      coins: 120,
      xp: 340,
      statusMap: statusMap,
    );
  });

  testWidgets('Capture 3: New student with no progress (Level 1)', (tester) async {
    final statusMap = <int, String>{};
    statusMap[1] = 'unlocked';
    for (int i = 2; i <= 60; i++) {
      statusMap[i] = 'locked';
    }

    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'after_home_390_new_student.png',
      studentName: 'Maya',
      currentLevel: 1,
      startingLevel: 1,
      coins: 0,
      xp: 0,
      statusMap: statusMap,
    );
  });

  testWidgets('Capture 4: Student at start of new zone (Level 21)', (tester) async {
    final statusMap = <int, String>{};
    for (int i = 1; i <= 20; i++) {
      statusMap[i] = 'completed';
    }
    statusMap[21] = 'unlocked';
    for (int i = 22; i <= 60; i++) {
      statusMap[i] = 'locked';
    }

    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'after_home_390_new_zone.png',
      studentName: 'Carlos',
      currentLevel: 21,
      startingLevel: 1,
      coins: 80,
      xp: 210,
      statusMap: statusMap,
    );
  });

  testWidgets('Capture 5: Student who finished everything (Level 60 completed)', (tester) async {
    final statusMap = <int, String>{};
    for (int i = 1; i <= 60; i++) {
      statusMap[i] = 'completed';
    }

    await captureScreen(
      tester: tester,
      size: const Size(390, 844),
      filename: 'after_home_390_finished_all.png',
      studentName: 'Sam',
      currentLevel: 60,
      startingLevel: 1,
      coins: 500,
      xp: 1250,
      statusMap: statusMap,
    );
  });
}
