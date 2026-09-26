import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';

import 'helpers/bank_fixture.dart';

void main() {
  final game = GameLogicService();
  final bank = buildBank();

  /// A provider wired up for deterministic, non-Firestore testing.
  LevelProvider makeProvider() =>
      LevelProvider(gameLogic: game, questionBank: null, dryRun: true);

  String correctAnswer(LevelProvider p) => p.currentQuestion!.displayCorrectAnswer;
  String wrongAnswer(LevelProvider p) => ['A', 'B', 'C', 'D']
      .firstWhere((k) => k != p.currentQuestion!.displayCorrectAnswer);

  group('LevelProvider — preparation (non-challenge) level', () {
    test('starting level 1 selects a question and completes on submit', () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 1,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.phase, PlayerPhase.playing);
      expect(provider.currentQuestion, isNotNull);
      expect(provider.currentQuestion!.level, 1);
      expect(provider.isChallengeLevel, isFalse);

      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.phase, PlayerPhase.levelComplete);
    });

    test('preparation level requires a CORRECT answer to complete', () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 1,
        usedHistory: const [],
        seedBank: bank,
      );
      final firstQuestionId = provider.currentQuestion!.questionId;

      await provider.submitAnswer(wrongAnswer(provider)); // wrong -> repeats same question
      expect(provider.phase, PlayerPhase.playing);
      expect(provider.currentQuestion!.questionId, firstQuestionId);

      await provider.submitAnswer(correctAnswer(provider)); // correct -> completes
      expect(provider.phase, PlayerPhase.levelComplete);
    });
  });

  group('LevelProvider — challenge failure and remediation workflow', () {
    test('wrong answer on a challenge enters remediationPrep with range [1..4]',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 5,
        usedHistory: const [],
        seedBank: bank,
      );
      expect(provider.isChallengeLevel, isTrue);

      await provider.submitAnswer(wrongAnswer(provider)); // wrong -> enters remediation
      expect(provider.phase, PlayerPhase.remediationPrep);
      expect(provider.inRemediation, isTrue);
      expect(provider.preparationRange, [1, 2, 3, 4]);
      expect(provider.lastCorrect, isFalse);
      expect(provider.feedbackPending, isTrue);
      expect(provider.remediationCycleCount, 1);
      expect(provider.needsTeacherSupport, isFalse);
    });

    test('remediation preparation requires mastery before unlocking challenge retry',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 5,
        usedHistory: const [],
        seedBank: bank,
      );

      // 1. Fail initial challenge
      await provider.submitAnswer(wrongAnswer(provider));
      provider.dismissFeedback();
      expect(provider.phase, PlayerPhase.remediationPrep);

      // 2. Answer 4 prep questions correctly to hit 100% (>= 75% mastery requirement)
      for (int i = 0; i < 4; i++) {
        await provider.submitAnswer(correctAnswer(provider));
        provider.dismissFeedback();
      }

      // After meeting mastery, phase transitions to challengeRetry
      expect(provider.phase, PlayerPhase.challengeRetry);

      // 3. Passing retry completes the level
      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.phase, PlayerPhase.levelComplete);
    });

    test('exceeding 3 remediation cycles triggers needsTeacherSupport phase',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 5,
        usedHistory: const [],
        seedBank: bank,
      );

      // Fail initial challenge -> Cycle 1
      await provider.submitAnswer(wrongAnswer(provider));
      provider.dismissFeedback();
      expect(provider.phase, PlayerPhase.remediationPrep);
      expect(provider.remediationCycleCount, 1);

      // Reach mastery in prep -> challengeRetry
      for (int i = 0; i < 4; i++) {
        await provider.submitAnswer(correctAnswer(provider));
        provider.dismissFeedback();
      }
      expect(provider.phase, PlayerPhase.challengeRetry);

      // Fail retry 1 -> repeats to Cycle 2
      await provider.submitAnswer(wrongAnswer(provider));
      provider.dismissFeedback();
      expect(provider.remediationCycleCount, 2);
      expect(provider.phase, PlayerPhase.remediationPrep);

      // Reach mastery again -> challengeRetry
      for (int i = 0; i < 4; i++) {
        await provider.submitAnswer(correctAnswer(provider));
        provider.dismissFeedback();
      }
      expect(provider.phase, PlayerPhase.challengeRetry);

      // Fail retry 2 -> repeats to Cycle 3
      await provider.submitAnswer(wrongAnswer(provider));
      provider.dismissFeedback();
      expect(provider.remediationCycleCount, 3);
      expect(provider.phase, PlayerPhase.remediationPrep);

      // Reach mastery again -> challengeRetry
      for (int i = 0; i < 4; i++) {
        await provider.submitAnswer(correctAnswer(provider));
        provider.dismissFeedback();
      }
      expect(provider.phase, PlayerPhase.challengeRetry);

      // Fail retry 3 -> cycle limit exceeded (> 3) -> transitions to needsTeacherSupport!
      await provider.submitAnswer(wrongAnswer(provider));
      provider.dismissFeedback();
      expect(provider.remediationCycleCount, 4);
      expect(provider.needsTeacherSupport, isTrue);
      expect(provider.phase, PlayerPhase.needsTeacherSupport);
    });
  });

  group('LevelProvider — difficulty facade', () {
    test('reports difficulty and challenge classification per level', () async {
      final p5 = makeProvider();
      await p5.startLevel(userId: 'u', level: 5, usedHistory: const [], seedBank: bank);
      expect(p5.difficulty, 'Hard');
      expect(p5.isChallengeLevel, isTrue);

      final p20 = makeProvider();
      await p20.startLevel(userId: 'u', level: 20, usedHistory: const [], seedBank: bank);
      expect(p20.difficulty, 'Super Hardcore');
      expect(p20.isChallengeLevel, isTrue);
    });

    test('returns levelFailed when the bank has no questions for the level',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u',
        level: 61, // outside the 1-60 game range
        usedHistory: const [],
        seedBank: bank,
      );
      expect(provider.phase, PlayerPhase.levelFailed);
      expect(provider.currentQuestion, isNull);
    });

    test('reports Intermediate-zone difficulties through the facade', () async {
      final p21 = makeProvider();
      await p21.startLevel(userId: 'u', level: 21, usedHistory: const [], seedBank: bank);
      expect(p21.difficulty, 'Moderate');
      expect(p21.isChallengeLevel, isFalse);

      final p40 = makeProvider();
      await p40.startLevel(userId: 'u', level: 40, usedHistory: const [], seedBank: bank);
      expect(p40.difficulty, 'Moderate (Multi-Step)');
      expect(p40.isChallengeLevel, isFalse);

      // Level 20 remains the ONLY Super Hardcore gate for now.
      expect(game.getDifficulty(40), isNot('Super Hardcore'));
    });
  });

    group('LevelProvider — real-time profile sync', () {
    test('subscribeToProfile stores StudentProfile with teacher fields', () {
      final provider = LevelProgressProvider();

      // Simulate the profile document the teacher dashboard writes to
      // /users/{uid}
      final teacherDoc = <String, dynamic>{
        'uid': 'student-uid',
        'role': 'student',
        'lrn': '107170918362',
        'fullName': 'Ana Santiago',
        'gradeLevel': 'Grade 4',
        'section': 'Sampaguita',
        'status': 'active',
        'avatar': 'avocado_1.png',
        'currentXP': 450,
        'coins': 90,
        'parentDetails': {
          'parentName': 'Lola Nena',
          'parentEmail': 'lola.nena@example.com',
          'parentPhone': '09171234567',
          'verificationCode': 'MTH-X4Q7',
        },
        'levelStatus': {'1': 'completed', '2': 'unlocked'},
        'currentLevel': 2,
        'startingLevel': 1,
      };

      // Inject the profile the same way the real-time stream would.
      provider.injectProfileFromSnapshot(teacherDoc, 'student-uid');

      final profile = provider.studentProfile!;

      expect(profile.uid, 'student-uid');
      expect(profile.displayName, 'Ana Santiago');
      expect(profile.lrn, '107170918362');
      expect(profile.gradeLevel, 4);
      expect(profile.gradeLevelLabel, 'Grade 4');
      expect(profile.section, 'Sampaguita');
      expect(profile.studentStatus, 'active');
      expect(profile.avatarUrl, 'avocado_1.png');
      expect(profile.stats.totalXp, 450);
      expect(profile.stats.coins, 90);
      expect(profile.parentGuardianName, 'Lola Nena');
      expect(profile.parentGuardianEmail, 'lola.nena@example.com');
      expect(profile.parentGuardianPhone, '09171234567');
      expect(profile.verificationCode, 'MTH-X4Q7');
      expect(profile.levelStatusMap['1'], 'completed');
      expect(profile.levelStatusMap['2'], 'unlocked');
    });

    test('studentProfile is null before any profile data arrives', () {
      final provider = LevelProgressProvider();
      expect(provider.studentProfile, isNull);
    });
  });

  group('LevelProvider — answer feedback & session scoring', () {
    test('correct answer sets feedback pending, lastCorrect, and score 1',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u',
        level: 1,
        usedHistory: const [],
        seedBank: bank,
      );

      // Submit correct answer dynamically based on shuffled display slot.
      await provider.submitAnswer(correctAnswer(provider));

      expect(provider.feedbackPending, isTrue);
      expect(provider.lastCorrect, isTrue);
      expect(provider.lastAnsweredQuestion, provider.currentQuestion);
      expect(provider.score, 1);
      expect(provider.attemptedTotal, 1);
    });

    test('wrong answer records lastCorrect=false and does not add to score',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u',
        level: 1,
        usedHistory: const [],
        seedBank: bank,
      );

      await provider.submitAnswer(wrongAnswer(provider)); // incorrect

      expect(provider.feedbackPending, isTrue);
      expect(provider.lastCorrect, isFalse);
      expect(provider.score, 0);
      expect(provider.attemptedTotal, 1);
    });

    test('dismissFeedback clears the pending-feedback record', () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u',
        level: 1,
        usedHistory: const [],
        seedBank: bank,
      );
      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.feedbackPending, isTrue);

      provider.dismissFeedback();
      expect(provider.feedbackPending, isFalse);
      expect(provider.lastCorrect, isNull);
      expect(provider.lastAnsweredQuestion, isNull);
      // Score is preserved after dismissal (persists across questions).
      expect(provider.score, 1);
    });
  });

  group('LevelProvider — Intermediate zone (21–40, no gates)', () {
    test('Level 21 draws a Moderate question and is NOT a challenge level',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 21,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.difficulty, 'Moderate');
      expect(provider.isChallengeLevel, isFalse);
      expect(provider.phase, PlayerPhase.playing);
      expect(provider.currentQuestion!.level, 21);
      expect(provider.currentQuestion!.difficulty, 'Moderate');
    });

    test('Level 25: wrong answer repeats SAME question — never remediation',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 25,
        usedHistory: const [],
        seedBank: bank,
      );
      final firstQuestionId = provider.currentQuestion!.questionId;

      await provider.submitAnswer(wrongAnswer(provider)); // wrong
      expect(provider.phase, PlayerPhase.playing); // NOT remediationPrep
      expect(provider.inRemediation, isFalse);
      expect(provider.preparationRange, isEmpty);
      expect(provider.currentQuestion!.questionId, firstQuestionId);

      await provider.submitAnswer(correctAnswer(provider)); // correct -> completes normally
      expect(provider.phase, PlayerPhase.levelComplete);
    });

    test('Level 40 reports "Moderate (Multi-Step)" and completes gate-free',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 40,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.difficulty, 'Moderate (Multi-Step)');
      expect(provider.isChallengeLevel, isFalse);

      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.phase, PlayerPhase.levelComplete);
      expect(provider.inRemediation, isFalse);
    });

    test('remediation engine refuses to trigger for any Zone 2 level', () {
      for (final level in const [21, 25, 30, 35, 39, 40]) {
        expect(
          () => game.resolveChallengeAttempt(level: level, isCorrect: false),
          throwsArgumentError,
          reason: 'level $level must not start remediation',
        );
      }
    });
  });
group('LevelProvider — Advanced zone (41–60, gates return)', () {
    test('Level 41 draws a Preparation question and completes on a correct answer',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 41,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.difficulty, 'Preparation');
      expect(provider.isChallengeLevel, isFalse);
      expect(provider.phase, PlayerPhase.playing);
      expect(provider.currentQuestion!.level, 41);

      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.phase, PlayerPhase.levelComplete);
    });

    test('Level 45 is a Hard challenge level (gate restored in Zone 3)', () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 45,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.difficulty, 'Hard');
      expect(provider.isChallengeLevel, isTrue);
      // Wrong answer on a challenge initiates remediation with range [41..44]
      await provider.submitAnswer(wrongAnswer(provider));
      expect(provider.phase, PlayerPhase.remediationPrep);
      expect(provider.inRemediation, isTrue);
      expect(provider.preparationRange, [41, 42, 43, 44]);
    });

    test('Passing Level 60 surfaces the adventureComplete phase (not levelComplete)',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 60,
        usedHistory: const [],
        seedBank: bank,
      );

      expect(provider.difficulty, 'Final Boss');
      expect(provider.isChallengeLevel, isTrue);

      await provider.submitAnswer(correctAnswer(provider));
      expect(provider.phase, PlayerPhase.adventureComplete);
      expect(provider.isGameComplete, isTrue);
    });

    test('final-boss completion payload marks Level 60 completed and records ZONE_3',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 60,
        usedHistory: const ['L60-Q1'],
        seedBank: bank,
      );
      await provider.submitAnswer(correctAnswer(provider));

      final payload = provider.buildCompletePayload();
      // The completed boss level must be persisted as 'completed' so the map
      // renders it finished (previously it stayed 'unlocked' → challenge).
      expect(payload['levelStatus.60'], 'completed');
      // currentLevel stays clamped at the final boss (no Level 61 exists).
      expect(payload['currentLevel'], 60);
      // The end-of-game milestone is recorded for the profile/game state.
      expect(payload['completedZones'], isNotNull);
      // Used-question history is still appended.
      expect(payload['usedQuestionsHistory'], isNotNull);
    });

    test('regular level payload marks the level completed and unlocks the next',
        () async {
      final provider = makeProvider();
      await provider.startLevel(
        userId: 'u1',
        level: 3,
        usedHistory: const [],
        seedBank: bank,
      );
      await provider.submitAnswer(correctAnswer(provider));

      final payload = provider.buildCompletePayload();
      expect(payload['levelStatus.3'], 'completed');
      expect(payload['levelStatus.4'], 'unlocked');
      expect(payload['currentLevel'], 4);
      // Non-final levels do not record the zone milestone.
      expect(payload['completedZones'], isNull);
    });

    test('resolveChallengeAttempt covers Zone 3 gates and throws for prep-only levels',
        () {
      // Zone 3 gate levels resolve normally.
      expect(game.resolveChallengeAttempt(level: 45, isCorrect: true).nextLevel, 46);
      expect(game.resolveChallengeAttempt(level: 60, isCorrect: false).returnToLevel, 56);
      // A preparation level (e.g. 41) is not a challenge level → throws.
      expect(
        () => game.resolveChallengeAttempt(level: 41, isCorrect: false),
        throwsArgumentError,
      );
    });
  });
}