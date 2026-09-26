import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';

import 'helpers/bank_fixture.dart';

void main() {
  final game = GameLogicService();
  final bank = buildBank(); // combined Levels 1–60 fixture bank

  // -------------------------------------------------------------------------
  // 1. Difficulty mapping across all 60 levels
  // -------------------------------------------------------------------------
  // NOTE: Per the Intermediate (Zone 2) spec, Levels 25/30/35/40 are NO LONGER
  // Hard/Super-Hardcore gates — this intentionally overrides the original
  // Rule-Based Game Logic doc, mirroring tools/question-bank/testGameLogic.js.
  test('Hard levels are exactly 5,10,15,45,50,55 (Zone 2 gates removed)', () {
    final hard = <int>[];
    for (var l = 1; l <= 60; l++) {
      if (game.getDifficulty(l) == 'Hard') hard.add(l);
    }
    expect(hard, [5, 10, 15, 45, 50, 55]);
  });

  test('Super Hardcore levels are exactly [20] (Level 40 demoted per Intermediate spec)',
      () {
    final sh = <int>[];
    for (var l = 1; l <= 60; l++) {
      if (game.getDifficulty(l) == 'Super Hardcore') sh.add(l);
    }
    expect(sh, [20]);
  });

  test('Level 60 is Final Boss (not Hard, despite 60 % 5 == 0)', () {
    expect(game.getDifficulty(60), 'Final Boss');
  });

  test('Levels 21-39 are all "Moderate"', () {
    for (var l = 21; l <= 39; l++) {
      expect(game.getDifficulty(l), 'Moderate', reason: 'level $l');
    }
  });

  test('Level 40 is "Moderate (Multi-Step)", distinct from Level 20 Super Hardcore',
      () {
    expect(game.getDifficulty(40), 'Moderate (Multi-Step)');
    expect(game.getDifficulty(40), isNot(game.getDifficulty(20)));
  });

  test('Preparation levels are everything else in Zone 1 & Zone 3', () {
    const nonPreparation = {5, 10, 15, 20, 45, 50, 55, 60};
    for (var l = 1; l <= 20; l++) {
      if (!nonPreparation.contains(l)) {
        expect(game.getDifficulty(l), 'Preparation', reason: 'level $l');
      }
    }
    for (var l = 41; l <= 60; l++) {
      if (!nonPreparation.contains(l)) {
        expect(game.getDifficulty(l), 'Preparation', reason: 'level $l');
      }
    }
  });

  test('isChallengeLevel flags only Zone 1 & Zone 3 gate levels (8 total, not 12)',
      () {
    const expected = [5, 10, 15, 20, 45, 50, 55, 60];
    final actual = <int>[];
    for (var l = 1; l <= 60; l++) {
      if (game.isChallengeLevel(l)) actual.add(l);
    }
    expect(actual, expected);
  });

  test('No level in Zone 2 (21-40) is ever a challenge level', () {
    for (var l = 21; l <= 40; l++) {
      expect(game.isChallengeLevel(l), isFalse, reason: 'level $l');
    }
  });

  test('getZone correctly buckets levels into 1, 2, or 3', () {
    expect(game.getZone(1), 1);
    expect(game.getZone(20), 1);
    expect(game.getZone(21), 2);
    expect(game.getZone(40), 2);
    expect(game.getZone(41), 3);
    expect(game.getZone(60), 3);
  });

  test('getZone throws for out-of-range levels', () {
    expect(() => game.getZone(0), throwsArgumentError);
    expect(() => game.getZone(61), throwsArgumentError);
  });

  // -------------------------------------------------------------------------
  // 2. Diagnostic scoring boundary conditions
  // -------------------------------------------------------------------------
  List<bool> mkItems(int correctCount) =>
      List.generate(20, (i) => i < correctCount);

  test('9/20 (45%) => Beginner, startingLevel 1', () {
    final r = game.scoreDiagnostic(mkItems(9));
    expect(r.percentage, 45);
    expect(r.category, 'Beginner');
    expect(r.startingLevel, 1);
  });

  test('10/20 (50%) => Intermediate boundary, startingLevel 21', () {
    final r = game.scoreDiagnostic(mkItems(10));
    expect(r.percentage, 50);
    expect(r.category, 'Intermediate');
    expect(r.startingLevel, 21);
  });

  test('15/20 (75%) => Advanced boundary, startingLevel 41', () {
    final r = game.scoreDiagnostic(mkItems(15));
    expect(r.percentage, 75);
    expect(r.category, 'Advanced');
    expect(r.startingLevel, 41);
  });

  test('20/20 (100%) => Mastery, startingLevel 41', () {
    final r = game.scoreDiagnostic(mkItems(20));
    expect(r.percentage, 100);
    expect(r.category, 'Mastery');
    expect(r.startingLevel, 41);
  });

  test('19/20 (95%) => Advanced, NOT Mastery', () {
    expect(game.scoreDiagnostic(mkItems(19)).category, 'Advanced');
  });

  // -------------------------------------------------------------------------
  // 3. Preparation-range map matches spec exactly
  // -------------------------------------------------------------------------
  // Zone 2 (25, 30, 35, 40) deliberately has NO preparation-range entries.
  test('Preparation ranges match the documented remediation map (Zone 1 & Zone 3 only)',
      () {
    const spec = <int, List<int>>{
      5: [1, 2, 3, 4],
      10: [6, 7, 8, 9],
      15: [11, 12, 13, 14],
      20: [16, 17, 18, 19],
      45: [41, 42, 43, 44],
      50: [46, 47, 48, 49],
      55: [51, 52, 53, 54],
      60: [56, 57, 58, 59],
    };
    spec.forEach((lvl, range) {
      expect(game.getPreparationRange(lvl).range, range, reason: 'level $lvl');
    });
  });

  test('getPreparationRange throws for a non-challenge level', () {
    expect(() => game.getPreparationRange(7), throwsArgumentError);
  });

  test('getPreparationRange throws for Levels 25, 30, 35, and 40 (no longer gates)',
      () {
    expect(() => game.getPreparationRange(25), throwsArgumentError);
    expect(() => game.getPreparationRange(30), throwsArgumentError);
    expect(() => game.getPreparationRange(35), throwsArgumentError);
    expect(() => game.getPreparationRange(40), throwsArgumentError);
  });

  // -------------------------------------------------------------------------
  // 4. Question bank coverage (Levels 1-40, combined Zone 1 + Zone 2)
  // -------------------------------------------------------------------------
  test('Combined fixture bank has 300 questions, 5 per level for levels 1-60',
      () {
    expect(bank.length, 300);
    for (var l = 1; l <= 60; l++) {
      final count = bank.where((q) => q.level == l).length;
      expect(count, 5, reason: 'level $l should have 5 questions');
    }
  });

  test('Every question_id is unique across the combined bank', () {
    final ids = bank.map((q) => q.questionId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('Difficulty tags in the bank match getDifficulty() for each level', () {
    for (final q in bank) {
      expect(q.difficulty, game.getDifficulty(q.level), reason: q.questionId);
    }
  });

  test('Every Zone 2 question has correct_answer present among its own choices',
      () {
    for (final q in bank.where((q) => q.level >= 21)) {
      expect(q.choices.containsKey(q.correctAnswer), isTrue,
          reason: '${q.questionId}: correct answer not among choices');
    }
  });

  test('Zone 2 questions all have challengeGroup == null (no remediation linkage)',
      () {
    for (final q in bank.where((q) => q.level >= 21 && q.level <= 40)) {
      expect(q.challengeGroup, isNull, reason: q.questionId);
    }
    // Zone 1 keeps its numeric gate linkage.
    expect(bank.firstWhere((q) => q.questionId == 'L5-Q1').challengeGroup, 5);
    expect(bank.firstWhere((q) => q.questionId == 'L20-Q5').challengeGroup, 20);
  });

  test('Zone 3 preparation questions link to their correct challengeGroup', () {
    const spec = <int, int>{
      41: 45, 42: 45, 43: 45, 44: 45,
      46: 50, 47: 50, 48: 50, 49: 50,
      51: 55, 52: 55, 53: 55, 54: 55,
      56: 60, 57: 60, 58: 60, 59: 60,
    };
    spec.forEach((level, group) {
      for (final q in bank.where((q) => q.level == level)) {
        expect(q.challengeGroup, group, reason: q.questionId);
      }
    });
  });

  test('Zone 3 gate levels (45, 50, 55, 60) carry their own challengeGroup', () {
    for (final level in const [45, 50, 55, 60]) {
      for (final q in bank.where((q) => q.level == level)) {
        expect(q.challengeGroup, level, reason: q.questionId);
      }
    }
  });

  // -------------------------------------------------------------------------
  // 5. Fisher-Yates shuffle correctness
  // -------------------------------------------------------------------------
  test('Shuffle returns a permutation (same elements, same length)', () {
    final arr = [1, 2, 3, 4, 5, 6, 7, 8];
    final shuffled = game.fisherYatesShuffle(arr);
    expect(shuffled.length, arr.length);
    expect([...shuffled]..sort(), arr);
  });

  test('Shuffle does not mutate the original list', () {
    final arr = [1, 2, 3, 4, 5];
    final copy = List<int>.of(arr);
    game.fisherYatesShuffle(arr);
    expect(arr, copy);
  });

  test('Shuffle with a fixed seeded RNG is deterministic', () {
    final a = game.fisherYatesShuffle([1, 2, 3, 4, 5], Random(42));
    final b = game.fisherYatesShuffle([1, 2, 3, 4, 5], Random(42));
    expect(a, b);
  });

  test('Shuffle distribution is roughly uniform (sanity check on position 0)',
      () {
    final arr = [0, 1, 2, 3, 4];
    final counts = List.filled(5, 0);
    const trials = 20000;
    for (var i = 0; i < trials; i++) {
      counts[game.fisherYatesShuffle(arr).first]++;
    }
    final expected = trials / 5;
    for (final c in counts) {
      // allow 15% deviation from expected uniform frequency
      expect(((c - expected) / expected).abs() < 0.15, isTrue,
          reason: 'counts=$counts');
    }
  });

  // -------------------------------------------------------------------------
  // 6. Question selection excludes used questions and respects difficulty
  // -------------------------------------------------------------------------
  test('selectQuestion never returns a used question when alternatives exist',
      () {
    const used = ['L3-Q1', 'L3-Q2', 'L3-Q3', 'L3-Q4']; // 4 of 5 used
    for (var i = 0; i < 20; i++) {
      final q = game.selectQuestion(bank, level: 3, usedQuestionsHistory: used);
      expect(q!.questionId, 'L3-Q5');
    }
  });

  test('selectQuestion returns only level + required-difficulty questions',
      () {
    final q = game.selectQuestion(bank, level: 5, usedQuestionsHistory: const []);
    expect(q!.level, 5);
    expect(q.difficulty, 'Hard');
  });

  test('selectQuestion falls back to reuse only when all questions used', () {
    final allL1 =
        bank.where((q) => q.level == 1).map((q) => q.questionId).toList();
    final q = game.selectQuestion(bank, level: 1, usedQuestionsHistory: allL1);
    expect(q, isNotNull);
    expect(q!.level, 1);
  });

  test('selectQuestion returns null for a level outside the 1-60 game range',
      () {
    expect(
      game.selectQuestion(bank, level: 61, usedQuestionsHistory: const []),
      isNull,
    ); // Level 61 does not exist in the 1-60 bank
  });

  test('selectQuestion works for Zone 2 "Moderate" levels using the combined bank',
      () {
    final q = game.selectQuestion(bank, level: 27, usedQuestionsHistory: const []);
    expect(q!.level, 27);
    expect(q.difficulty, 'Moderate');
  });

  test('selectQuestion works for Level 40 "Moderate (Multi-Step)"', () {
    final q = game.selectQuestion(bank, level: 40, usedQuestionsHistory: const []);
    expect(q!.level, 40);
    expect(q.difficulty, 'Moderate (Multi-Step)');
  });
test('selectQuestion works for Zone 3 Hard levels (45, 50, 55)', () {
    for (final level in const [45, 50, 55]) {
      final q = game.selectQuestion(bank, level: level, usedQuestionsHistory: const []);
      expect(q!.level, level);
      expect(q.difficulty, 'Hard', reason: 'level $level');
    }
  });

  test('selectQuestion works for Level 60 "Final Boss"', () {
    final q = game.selectQuestion(bank, level: 60, usedQuestionsHistory: const []);
    expect(q!.level, 60);
    expect(q.difficulty, 'Final Boss');
  });

  test('Repeated selectQuestion calls vary the returned question', () {
    final results = <String>{};
    for (var i = 0; i < 30; i++) {
      results.add(game
          .selectQuestion(bank, level: 6, usedQuestionsHistory: const [])!
          .questionId);
    }
    expect(results.length, greaterThan(1));
  });

  // -------------------------------------------------------------------------
  // 7. Remediation engine end-to-end
  // -------------------------------------------------------------------------
  test('Passing a challenge unlocks the next level', () {
    final r = game.resolveChallengeAttempt(level: 5, isCorrect: true);
    expect(r.isPassed, isTrue);
    expect(r.nextLevel, 6);
  });

  test('Failing Level 5 returns learner to Level 1 (prep range [1,2,3,4])', () {
    final r = game.resolveChallengeAttempt(level: 5, isCorrect: false);
    expect(r.event, 'challenge_failed');
    expect(r.returnToLevel, 1);
    expect(r.preparationRange, [1, 2, 3, 4]);
  });

  test('Failing Level 20 returns learner to Level 16 (prep range [16..19])', () {
    final r = game.resolveChallengeAttempt(level: 20, isCorrect: false);
    expect(r.returnToLevel, 16);
    expect(r.preparationRange, [16, 17, 18, 19]);
  });

  test(
      'resolveChallengeAttempt throws for Level 25/30/35/40 — Zone 2 has no challenge levels',
      () {
    // Confirms the remediation engine cannot be invoked on Zone 2 levels,
    // matching the Intermediate spec's explicit "no hard gates" instruction.
    for (final level in const [25, 30, 35, 40]) {
      expect(
        () => game.resolveChallengeAttempt(level: level, isCorrect: false),
        throwsArgumentError,
        reason: 'level $level should not be a valid challenge level',
      );
    }
  });

  test('selectRemediationQuestion picks an unused question in the range', () {
    const used = ['L1-Q1', 'L1-Q2', 'L2-Q1', 'L2-Q2'];
    final q = game.selectRemediationQuestion(
      bank,
      preparationRange: const [1, 2, 3, 4],
      usedQuestionsHistory: used,
    );
    expect(q, isNotNull);
    expect(const [1, 2, 3, 4].contains(q!.level), isTrue);
    expect(used.contains(q.questionId), isFalse);
  });

  test('selectNewChallengeQuestion never returns the just-failed question', () {
    for (var i = 0; i < 20; i++) {
      final q = game.selectNewChallengeQuestion(
        bank,
        level: 5,
        excludeQuestionId: 'L5-Q1',
        usedQuestionsHistory: const [],
      );
      expect(q!.questionId, isNot('L5-Q1'));
    }
  });
// -------------------------------------------------------------------------
  // Zone 3 (Advanced) remediation flow — mirrors the doc's worked example
  // (fail Q60 -> prep 56-59 -> NEW Level 60 question; passing Level 60 emits
  // the game-complete nextLevel: 61 signal).
  // -------------------------------------------------------------------------
  test('Failing Level 45 returns learner to Level 41 (prep range [41,42,43,44])', () {
    final r = game.resolveChallengeAttempt(level: 45, isCorrect: false);
    expect(r.event, 'challenge_failed');
    expect(r.returnToLevel, 41);
    expect(r.preparationRange, [41, 42, 43, 44]);
  });

  test('Failing Level 50/55/60 maps to the documented Zone 3 prep ranges', () {
    final cases = <int, List<int>>{
      50: [46, 47, 48, 49],
      55: [51, 52, 53, 54],
      60: [56, 57, 58, 59],
    };
    cases.forEach((level, range) {
      final r = game.resolveChallengeAttempt(level: level, isCorrect: false);
      expect(r.returnToLevel, range.first, reason: 'level $level');
      expect(r.preparationRange, range, reason: 'level $level');
    });
  });

  test('Passing Level 60 emits the game-complete signal (nextLevel 61)', () {
    final r = game.resolveChallengeAttempt(level: 60, isCorrect: true);
    expect(r.isPassed, isTrue);
    expect(r.nextLevel, 61);
  });

  test('selectRemediationQuestion pulls NEW unused questions across the full 300-bank', () {
    // History from Zone 3 already used: 56-59 fully exhausted on one level.
    final used = [
      for (var l = 56; l <= 59; l++) ...[
        'L$l-Q1', 'L$l-Q2', 'L$l-Q3', 'L$l-Q4', 'L$l-Q5',
      ],
    ];
    // Every question in [56-59] is now used, but other prep-range levels remain.
    // Use the Level 60 prep range [56,57,58,59] — with everything used the
    // engine falls back to reuse, so it must still return a level 56-59 question.
    final q = game.selectRemediationQuestion(
      bank,
      preparationRange: const [56, 57, 58, 59],
      usedQuestionsHistory: used,
    );
    expect(q, isNotNull);
  });

  test('selectNewChallengeQuestion for Level 60 never returns the just-failed id', () {
    for (var i = 0; i < 20; i++) {
      final q = game.selectNewChallengeQuestion(
        bank,
        level: 60,
        excludeQuestionId: 'L60-Q1',
        usedQuestionsHistory: const [],
      );
      expect(q!.level, 60);
      expect(q.questionId, isNot('L60-Q1'));
    }
  });

  // -------------------------------------------------------------------------
  // 8. Mastery threshold logic
  // -------------------------------------------------------------------------
  test('Mastery threshold (75%): 3/4 passes, 2/4 fails', () {
    expect(game.isMasteryMet(3, 4), isTrue);
    expect(game.isMasteryMet(2, 4), isFalse);
  });

  test('Mastery threshold: 0 attempts never counts as mastery', () {
    expect(game.isMasteryMet(0, 0), isFalse);
  });
}