import 'dart:math';

import '../models/question_model.dart';

/// The level that is the game's final boss (cannot be unlocked past).
const int kFinalBossLevel = 60;

/// Supervisor-class levels receiving "Super Hardcore" treatment.
///
/// Only Level 20 qualifies: the Intermediate-zone spec (Zone 2, Levels 21–40)
/// explicitly demoted Level 40 to "Moderate (Multi-Step)" so it must NOT be
/// treated as a Super-Hardcore boss. See
/// `md files/mathalino_intermediate_ide_prompt.md`.
const Set<int> kSuperHardcoreLevels = {20};

/// The mediator between this service and the maps that drive the gamified
/// difficulty + remediation engine. Kept here (rather than in an existing
/// constants file) so every value matches `tools/question-bank/gameLogic.js`
/// verbatim.
class GameRules {
  const GameRules._();

  /// Offline/zone level for a failed challenge level → preparation range
  /// target. This map is **contractually defined** in the architecture doc;
  /// the `range` values are the exact lower levels to re-practice.
  ///
  /// ⚠️ ZONE 2 OVERRIDE (Levels 21–40): the Intermediate question-bank spec
  /// removes ALL remediation gates from that zone — Levels 25, 30, 35 and 40
  /// deliberately have NO entries here, and
  /// [GameLogicService.getPreparationRange] throws for them. Zone 1 (1–20)
  /// and Zone 3 (41–60) keep their original gate structure.
  static const Map<int, PreparationRange> preparationMap = {
    5: PreparationRange(returnTo: 1, range: [1, 2, 3, 4]),
    10: PreparationRange(returnTo: 6, range: [6, 7, 8, 9]),
    15: PreparationRange(returnTo: 11, range: [11, 12, 13, 14]),
    20: PreparationRange(returnTo: 16, range: [16, 17, 18, 19]),
    45: PreparationRange(returnTo: 41, range: [41, 42, 43, 44]),
    50: PreparationRange(returnTo: 46, range: [46, 47, 48, 49]),
    55: PreparationRange(returnTo: 51, range: [51, 52, 53, 54]),
    60: PreparationRange(returnTo: 56, range: [56, 57, 58, 59]),
  };
}

/// Diagnosis outcome computed by [GameLogicService.scoreDiagnostic].
class DiagnosticScoreResult {
  final int correctAnswers;
  final int totalItems;
  final double percentage;

  /// 'Beginner' | 'Intermediate' | 'Advanced' | 'Mastery'
  final String category;

  /// Human-readable content-pool label (matches the system schema values).
  final String contentPool;

  /// The level the student should start their zone on (1 | 21 | 41).
  final int startingLevel;

  const DiagnosticScoreResult({
    required this.correctAnswers,
    required this.totalItems,
    required this.percentage,
    required this.category,
    required this.contentPool,
    required this.startingLevel,
  });

  @override
  String toString() =>
      'DiagnosticScoreResult(score: $correctAnswers/$totalItems '
      '(${percentage.toStringAsFixed(1)}%), category: $category, '
      'startingLevel: $startingLevel)';
}

/// Preparation range returned by [GameLogicService.getPreparationRange].
class PreparationRange {
  /// The first (lowest) level a failing student returns to.
  final int returnTo;

  /// The ordered list of levels to re-practice before retrying the challenge.
  final List<int> range;

  const PreparationRange({required this.returnTo, required this.range});
}

/// Result of a challenge-level attempt (see
/// [GameLogicService.resolveChallengeAttempt]).
class ChallengeResolution {
  /// 'challenge_passed' | 'challenge_failed'
  final String event;

  final int level;

  /// 'unlock_next_level' on pass, 'remediation_start' on failure.
  final String action;

  /// The level unlocked by a successful pass (level + 1).
  final int? nextLevel;

  /// The return-to level during remediation (failure only).
  final int? returnToLevel;

  /// The preparation range levels to practice (failure only).
  final List<int>? preparationRange;

  const ChallengeResolution({
    required this.event,
    required this.level,
    required this.action,
    this.nextLevel,
    this.returnToLevel,
    this.preparationRange,
  });

  bool get isPassed => event == 'challenge_passed';
  bool get isFailed => event == 'challenge_failed';

  @override
  String toString() => 'ChallengeResolution(event: $event, level: $level, '
      'action: $action, nextLevel: $nextLevel, returnToLevel: $returnToLevel)';
}
/// Pure, stateless Mathalino game engine.
///
/// This is the idiomatic Dart port of `tools/question-bank/gameLogic.js` and
/// contains **no** Firestore or I/O calls so it can be unit tested in
/// isolation. It drives:
///   * diagnostic scoring/placement ([scoreDiagnostic])
///   * level difficulty + challenge classification ([getDifficulty],
///     [isChallengeLevel])
///   * the remediation preparation-range map ([getPreparationRange])
///   * question selection via Fisher-Yates shuffle ([selectQuestion])
///   * the Hard / Super-Hardcore remediation loop
///     ([resolveChallengeAttempt], [selectRemediationQuestion],
///     [selectNewChallengeQuestion], [isMasteryMet])
class GameLogicService {
  const GameLogicService();

  /// Fisher-Yates (Knuth / Durstenfeld) shuffle.
  ///
  /// Returns a **new** list and never mutates [items]. Pass a [rng] only to
  /// make the result predictable in tests; when null a fresh [Random] is used.
  List<T> fisherYatesShuffle<T>(List<T> items, [Random? rng]) {
    final r = rng ?? Random();
    final result = List<T>.of(items);
    for (var i = result.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }
    return result;
  }

  /// Scores a 20-item diagnostic and assigns the placement category.
  ///
  /// Cut-offs (exactly as in `gameLogic.js`):
  ///   * percentage < 50  → Beginner      (starting level 1)
  ///   * percentage < 75  → Intermediate  (starting level 21)
  ///   * percentage < 100 → Advanced      (starting level 41)
  ///   * percentage == 100 → Mastery       (starting level 41)
  DiagnosticScoreResult scoreDiagnostic(List<bool> itemResults) {
    final correctAnswers = itemResults.where((b) => b).length;
    final percentage = (correctAnswers / 20) * 100;

    String category;
    String contentPool;
    int startingLevel;
    if (percentage < 50) {
      category = 'Beginner';
      contentPool = 'Grade 1-3';
      startingLevel = 1;
    } else if (percentage < 75) {
      category = 'Intermediate';
      contentPool = 'Grade 1-6 shuffled';
      startingLevel = 21;
    } else if (percentage < 100) {
      category = 'Advanced';
      contentPool = 'Grade 1-6 advanced';
      startingLevel = 41;
    } else {
      category = 'Mastery';
      contentPool = 'Grade 1-6 advanced/full range';
      startingLevel = 41;
    }

    return DiagnosticScoreResult(
      correctAnswers: correctAnswers,
      totalItems: itemResults.length,
      percentage: percentage,
      category: category,
      contentPool: contentPool,
      startingLevel: startingLevel,
    );
  }

  /// Returns the zone number for a level: 1 → Levels 1–20, 2 → Levels 21–40,
  /// 3 → Levels 41–60. Throws [ArgumentError] outside the 1–60 game range.
  ///
  /// Mirrors `getZone()` in `tools/question-bank/gameLogic.js`.
  int getZone(int level) {
    if (level >= 1 && level <= 20) return 1;
    if (level >= 21 && level <= 40) return 2;
    if (level >= 41 && level <= 60) return 3;
    throw ArgumentError('Level $level is outside the 1-60 game range.');
  }

  /// Returns the difficulty string for a decimal level number (1..60).
  ///
  /// Matches `gameLogic.js` exactly:
  ///   * 60 → 'Final Boss'
  ///   * 20 → 'Super Hardcore' (Level 40 was DEMOTED per the Intermediate spec)
  ///   * 21–39 → 'Moderate' (Zone 2, no gates)
  ///   * 40 → 'Moderate (Multi-Step)' (Zone 2 final level, still no gate)
  ///   * any other multiple of 5 → 'Hard' (5,10,15 Zone 1; 45,50,55 Zone 3)
  ///   * everything else → 'Preparation'
  String getDifficulty(int level) {
    if (level == kFinalBossLevel) return 'Final Boss';
    if (kSuperHardcoreLevels.contains(level)) return 'Super Hardcore';
    if (level >= 21 && level <= 39) return 'Moderate'; // Zone 2, no gates
    if (level == 40) return 'Moderate (Multi-Step)'; // Zone 2 final level
    if (level % 5 == 0) return 'Hard';
    return 'Preparation';
  }

  /// Whether [level] is a challenge level (triggers remediation on failure).
  ///
  /// Derived from [getDifficulty] rather than a hardcoded level list so that
  /// Zone 2's "Moderate" / "Moderate (Multi-Step)" levels automatically
  /// return false without needing an exclusion list.
  bool isChallengeLevel(int level) {
    final d = getDifficulty(level);
    return d == 'Hard' || d == 'Super Hardcore' || d == 'Final Boss';
  }

  /// Returns the preparation range to remediate after failing challenge
  /// [level]. Throws [ArgumentError] for non-challenge levels.
  PreparationRange getPreparationRange(int level) {
    final entry = GameRules.preparationMap[level];
    if (entry == null) {
      throw ArgumentError(
        'Level $level is not a challenge level with a preparation range.',
      );
    }
    return entry;
  }

  /// Selects ONE eligible [QuestionModel] for [level] using the Fisher-Yates
  /// shuffle so repeated calls (across students/attempts) do not always return
  /// the same "first" match in the bank array.
  ///
  /// Constraint priority mirrors `gameLogic.js`: level + required difficulty →
  /// optional competency → exclude-used. The "exclude used" constraint is
  /// relaxed last (reusing an already-seen question is a last resort), and
  /// `null` is returned only when no question for the level exists in the
  /// bank at all.
  QuestionModel? selectQuestion(
    List<QuestionModel> bank, {
    required int level,
    required List<String> usedQuestionsHistory,
    String? competency,
    Random? rng,
  }) {
    final usedSet = usedQuestionsHistory.toSet();
    final requiredDifficulty = getDifficulty(level);

    List<QuestionModel> passes({
      required bool difficulty,
      required bool excludeUsed,
      required bool competencyFilter,
    }) {
      return bank.where((q) {
        if (q.level != level) return false;
        if (difficulty && q.difficulty != requiredDifficulty) return false;
        if (excludeUsed && usedSet.contains(q.questionId)) return false;
        if (competencyFilter && competency != null && q.domain != competency) {
          return false;
        }
        return true;
      }).toList();
    }

    var eligible = passes(
      difficulty: true,
      excludeUsed: true,
      competencyFilter: true,
    );
    if (eligible.isEmpty && competency != null) {
      eligible = passes(
        difficulty: true,
        excludeUsed: true,
        competencyFilter: false,
      );
    }
    if (eligible.isEmpty) {
      eligible = passes(
        difficulty: true,
        excludeUsed: false,
        competencyFilter: false,
      );
    }
    if (eligible.isEmpty) return null;

    final shuffled = fisherYatesShuffle(eligible, rng);
    return shuffled.first;
  }

  /// Resolves a challenge-level attempt (Hard / Super Hardcore / Final Boss).
  ///
  /// * Correct  → 'challenge_passed' with an `unlock_next_level` action.
  /// * Incorrect → 'challenge_failed' with a `remediation_start` action and
  ///   the failed level's [PreparationRange] (returnTo + range levels).
  ///
  /// Throws [ArgumentError] if [level] is not a challenge level.
  ChallengeResolution resolveChallengeAttempt({
    required int level,
    required bool isCorrect,
  }) {
    if (!isChallengeLevel(level)) {
      throw ArgumentError('Level $level is not a challenge level.');
    }

    if (isCorrect) {
      return ChallengeResolution(
        event: 'challenge_passed',
        level: level,
        action: 'unlock_next_level',
        nextLevel: level + 1,
      );
    }

    final prep = getPreparationRange(level);
    return ChallengeResolution(
      event: 'challenge_failed',
      level: level,
      action: 'remediation_start',
      returnToLevel: prep.returnTo,
      preparationRange: List<int>.of(prep.range),
    );
  }

  /// Picks the next remediation practice question for a student currently
  /// cycling through a preparation range.
  ///
  /// Levels in [preparationRange] are visited in a shuffled order, returning
  /// the first level that yields an eligible (unused, difficulty-matched)
  /// question.
  QuestionModel? selectRemediationQuestion(
    List<QuestionModel> bank, {
    required List<int> preparationRange,
    required List<String> usedQuestionsHistory,
    String? competency,
    Random? rng,
  }) {
    final shuffledLevels = fisherYatesShuffle(preparationRange, rng);
    for (final lvl in shuffledLevels) {
      final q = selectQuestion(
        bank,
        level: lvl,
        usedQuestionsHistory: usedQuestionsHistory,
        competency: competency,
        rng: rng,
      );
      if (q != null) return q;
    }
    return null;
  }

  /// Selects a NEW challenge question (different `question_id` from the one
  /// just failed) once mastery has been satisfied.
  QuestionModel? selectNewChallengeQuestion(
    List<QuestionModel> bank, {
    required int level,
    required String excludeQuestionId,
    required List<String> usedQuestionsHistory,
    Random? rng,
  }) {
    final history = <String>{
      ...usedQuestionsHistory,
      excludeQuestionId,
    }.toList();
    return selectQuestion(
      bank,
      level: level,
      usedQuestionsHistory: history,
      rng: rng,
    );
  }

  /// Default mastery threshold: 75% correct across preparation-range attempts.
  ///
  /// With `attempted == 0` mastery is never considered met.
  bool isMasteryMet(
    int correct,
    int attempted, {
    double thresholdPct = 75,
  }) {
    if (attempted == 0) return false;
    return (correct / attempted) * 100 >= thresholdPct;
  }
}