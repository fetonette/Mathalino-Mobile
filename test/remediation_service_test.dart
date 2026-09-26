import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/constants/game_rules.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/services/remediation_service.dart';
import 'package:mathalino_student_app/core/services/scoring_service.dart';
import 'package:mathalino_student_app/providers/remediation_provider.dart';

void main() {
  late RemediationService remediationService;

  Question makeQuestion({
    required String id,
    required String competencyCode,
    String correctAnswer = 'A',
    List<String> choices = const ['A', 'B', 'C', 'D'],
  }) {
    return Question(
      id: id,
      grade: 1,
      contentDomain: 'Number and Number Sense',
      competencyCode: competencyCode,
      competencyText: 'Test competency',
      cognitiveDomain: 'Knowing',
      type: 'multipleChoice',
      questionText: 'Question $id for $competencyCode',
      choices: choices,
      correctAnswer: correctAnswer,
    );
  }

  setUp(() {
    remediationService = RemediationService(
      scoringService: ScoringService(),
    );
  });

  group('RemediationService — 1. Previous-Level Selection & Range Derivation', () {
    test('derives preparation range for all challenge gates in Zone 1 and Zone 3', () {
      expect(getPreparationRangeForLevel(5), [1, 4]);
      expect(getPreparationRangeForLevel(10), [6, 9]);
      expect(getPreparationRangeForLevel(15), [11, 14]);
      expect(getPreparationRangeForLevel(20), [16, 19]);
      expect(getPreparationRangeForLevel(45), [41, 44]);
      expect(getPreparationRangeForLevel(50), [46, 49]);
      expect(getPreparationRangeForLevel(55), [51, 54]);
      expect(getPreparationRangeForLevel(60), [56, 59]);
    });

    test('refuses to derive preparation range for Zone 2 levels (21-40, no gates)', () {
      for (final lvl in [21, 25, 30, 35, 40]) {
        expect(
          () => getPreparationRangeForLevel(lvl),
          throwsArgumentError,
          reason: 'Level $lvl is in Zone 2 and must not start remediation',
        );
      }
    });
  });

  group('RemediationService — 2. Mastery Calculation & 75% Threshold', () {
    test('running mastery is computed across the sliding window', () {
      var state = const RemediationState(
        active: true,
        targetLevel: 5,
        preparationStart: 1,
        preparationEnd: 4,
        competencyCode: 'NUM_ADD',
      );

      final q = makeQuestion(id: 'Q1', competencyCode: 'NUM_ADD', correctAnswer: 'A');

      // Attempt 1: Correct -> 1/1 = 100%
      state = remediationService.recordPreparationAnswer(
        question: q,
        selectedAnswer: 'A',
        remediation: state,
      );
      expect(state.attemptsInRange, 1);
      expect(state.masteryScore, 1.0);
      // Min attempts = 3, so not achieved yet
      expect(remediationService.hasAchievedMastery(state), isFalse);

      // Attempt 2: Incorrect -> [true, false] -> 1/2 = 50%
      state = remediationService.recordPreparationAnswer(
        question: q,
        selectedAnswer: 'B',
        remediation: state,
      );
      expect(state.attemptsInRange, 2);
      expect(state.masteryScore, 0.5);
      expect(remediationService.hasAchievedMastery(state), isFalse);

      // Attempt 3: Correct -> [true, false, true] -> 2/3 = 66.7%
      state = remediationService.recordPreparationAnswer(
        question: q,
        selectedAnswer: 'A',
        remediation: state,
      );
      expect(state.attemptsInRange, 3);
      expect(state.masteryScore, closeTo(0.667, 0.01));
      // 66.7% is below the 75% threshold!
      expect(remediationService.hasAchievedMastery(state), isFalse);

      // Attempt 4: Correct -> [true, false, true, true] -> 3/4 = 75%
      state = remediationService.recordPreparationAnswer(
        question: q,
        selectedAnswer: 'A',
        remediation: state,
      );
      expect(state.attemptsInRange, 4);
      expect(state.masteryScore, 0.75);
      // 75% threshold satisfied!
      expect(remediationService.hasAchievedMastery(state), isTrue);
    });

    test('sliding window trims to kMasteryWindowSize (5)', () {
      var state = const RemediationState(
        active: true,
        targetLevel: 5,
        preparationStart: 1,
        preparationEnd: 4,
      );
      final q = makeQuestion(id: 'Q1', competencyCode: 'NUM_ADD', correctAnswer: 'A');

      // 5 wrong answers
      for (int i = 0; i < 5; i++) {
        state = remediationService.recordPreparationAnswer(
          question: q,
          selectedAnswer: 'B',
          remediation: state,
        );
      }
      expect(state.attemptsInRange, 5);
      expect(state.masteryScore, 0.0);
      expect(state.recentAnswerCorrectness.length, 5);

      // Next 4 correct answers -> drops older incorrects
      for (int i = 0; i < 4; i++) {
        state = remediationService.recordPreparationAnswer(
          question: q,
          selectedAnswer: 'A',
          remediation: state,
        );
      }
      expect(state.attemptsInRange, 9);
      // Window contains [false, true, true, true, true] -> 4/5 = 80%
      expect(state.recentAnswerCorrectness.length, 5);
      expect(state.masteryScore, 0.80);
      expect(remediationService.hasAchievedMastery(state), isTrue);
    });

    test('max prep attempts detection (>= 10)', () {
      final stateUnder = const RemediationState(
        active: true,
        targetLevel: 5,
        preparationStart: 1,
        preparationEnd: 4,
        attemptsInRange: 9,
      );
      expect(remediationService.hasExceededMaxAttempts(stateUnder), isFalse);

      final stateMax = const RemediationState(
        active: true,
        targetLevel: 5,
        preparationStart: 1,
        preparationEnd: 4,
        attemptsInRange: 10,
      );
      expect(remediationService.hasExceededMaxAttempts(stateMax), isTrue);
    });
  });

  group('RemediationState — 3. Serialization & Cycle Tracking', () {
    test('round-trips full state including cycleCount and needsTeacherSupport', () {
      final original = RemediationState(
        active: true,
        targetLevel: 10,
        preparationStart: 6,
        preparationEnd: 9,
        failedQuestionId: 'L10-FAIL',
        competencyCode: 'NUM_SUB',
        attemptsInRange: 8,
        masteryScore: 0.625,
        recentAnswerCorrectness: const [true, false, true],
        cycleCount: 3,
        needsTeacherSupport: true,
        supportReason: 'Struggling on Level 10 after 3 cycles',
        createdAt: DateTime(2026, 9, 20, 10, 0),
        updatedAt: DateTime(2026, 9, 20, 10, 30),
      );

      final map = original.toMap();
      expect(map['active'], isTrue);
      expect(map['targetLevel'], 10);
      expect(map['preparationRange'], [6, 9]);
      expect(map['cycleCount'], 3);
      expect(map['needsTeacherSupport'], isTrue);
      expect(map['supportReason'], contains('Level 10'));

      final reconstructed = RemediationState.fromMap(map);
      expect(reconstructed.active, isTrue);
      expect(reconstructed.targetLevel, 10);
      expect(reconstructed.preparationStart, 6);
      expect(reconstructed.preparationEnd, 9);
      expect(reconstructed.cycleCount, 3);
      expect(reconstructed.needsTeacherSupport, isTrue);
      expect(reconstructed.supportReason, contains('Level 10'));
    });

    test('fromMap applies defaults when sparse or inactive', () {
      expect(RemediationState.fromMap(null).active, isFalse);
      expect(RemediationState.fromMap({'active': false}).active, isFalse);

      final sparse = RemediationState.fromMap({'active': true, 'targetLevel': 5});
      expect(sparse.active, isTrue);
      expect(sparse.targetLevel, 5);
      expect(sparse.cycleCount, 1);
      expect(sparse.needsTeacherSupport, isFalse);
    });

    test('copyWith updates cycle count and support flags correctly', () {
      final initial = const RemediationState(
        active: true,
        targetLevel: 5,
        preparationStart: 1,
        preparationEnd: 4,
        cycleCount: 1,
      );

      final updated = initial.copyWith(
        cycleCount: 2,
        needsTeacherSupport: false,
      );
      expect(updated.cycleCount, 2);
      expect(updated.needsTeacherSupport, isFalse);

      final escalated = updated.copyWith(
        cycleCount: 4,
        needsTeacherSupport: true,
        supportReason: 'Intervention needed',
      );
      expect(escalated.cycleCount, 4);
      expect(escalated.needsTeacherSupport, isTrue);
      expect(escalated.supportReason, 'Intervention needed');
    });
  });

  group('RemediationProvider — 4. Phase Transitions', () {
    test('provider exposes needsTeacherSupport and cycleCount', () {
      final provider = RemediationProvider(
        remediationService: remediationService,
        scoringService: ScoringService(),
      );

      expect(provider.isRemediationActive, isFalse);
      expect(provider.phase, RemediationPhase.none);
      expect(provider.needsTeacherSupport, isFalse);
      expect(provider.cycleCount, 0);
    });

    test('clearRemediation resets state to inactive', () {
      final provider = RemediationProvider(
        remediationService: remediationService,
        scoringService: ScoringService(),
      );

      provider.clearRemediation();
      expect(provider.isRemediationActive, isFalse);
      expect(provider.phase, RemediationPhase.none);
      expect(provider.needsTeacherSupport, isFalse);
    });
  });
}
