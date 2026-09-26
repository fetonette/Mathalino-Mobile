/// Centralized game rules and constants for Mathalino Student App.
///
/// These constants drive the Failure & Remediation Engine, level progression,
/// and mastery thresholds. Keeping them here allows tuning without touching
/// business logic scattered across services and providers.
library;

/// Mastery threshold (0.0 - 1.0) required to exit remediation.
///
/// A student must maintain a running mastery percentage at or above this
/// value across the preparation-range questions before being presented with
/// a NEW challenge question for the failed target level.
const double kMasteryThreshold = 0.75;

/// Number of most-recent preparation questions used to compute the running
/// mastery percentage. The engine keeps a sliding window of this size.
const int kMasteryWindowSize = 5;

/// Number of levels below the failed target level that form the preparation
/// range. For a failed level L, the preparation range is [L - kPrepRangeSize, L - 1].
const int kPrepRangeSize = 4;

/// Minimum number of preparation questions a student must answer before the
/// mastery threshold can be evaluated. Prevents premature challenge unlocks.
const int kMinPrepAttempts = 3;

/// Maximum number of preparation attempts allowed before the engine forces
/// a repeat-failure loop (re-enters remediation with the same target level).
const int kMaxPrepAttempts = 10;

/// Maximum number of remediation repeat cycles allowed before triggering
/// the 'Needs Teacher Support' state to prevent endless remediation loops.
const int kMaxRemediationCycles = 3;

/// Number of questions presented in a standard level practice session.
const int kQuestionsPerLevel = 5;

/// Number of questions presented in a remediation preparation session.
const int kRemediationPrepQuestionCount = 5;

/// Number of questions presented in a remediation challenge (retry) session.
const int kRemediationChallengeQuestionCount = 1;

/// Assessment type identifiers written to the `student_results` collection.
class AssessmentType {
  static const String levelPractice = 'LEVEL_PRACTICE';
  static const String challengeRemediation = 'CHALLENGE_REMEDIATION';
  static const String diagnostic = 'DIAGNOSTIC';
  static const String placement = 'PLACEMENT';
  static const String dailyChallenge = 'DAILY_CHALLENGE';
  static const String postAssessment = 'POST_ASSESSMENT';
  static const String remediationSupportNeeded = 'REMEDIATION_SUPPORT_NEEDED';
}

/// Identifiers for major zone progression milestones.
class ZoneMilestones {
  static const String zone1 = 'ZONE_1';
  static const String zone2 = 'ZONE_2';
  static const String zone3 = 'ZONE_3';

  static const Map<int, String> levelToZoneMap = {
    20: zone1,
    40: zone2,
    60: zone3,
  };
}

/// Firestore field keys for the remediation object stored on /users/{uid}.
class RemediationField {
  static const String active = 'remediation.active';
  static const String preparationRange = 'remediation.preparationRange';
  static const String targetLevel = 'remediation.targetLevel';
  static const String failedQuestionId = 'remediation.failedQuestionId';
  static const String competencyCode = 'remediation.competencyCode';
  static const String attemptsInRange = 'remediation.attemptsInRange';
  static const String masteryScore = 'remediation.masteryScore';
  static const String cycleCount = 'remediation.cycleCount';
  static const String needsTeacherSupport = 'remediation.needsTeacherSupport';
  static const String supportReason = 'remediation.supportReason';
  static const String createdAt = 'remediation.createdAt';
  static const String updatedAt = 'remediation.updatedAt';
}

/// Maps a failed target level to its preparation range [start, end].
///
/// Hard/Boss levels (multiples of 5) map to the four levels immediately
/// below them. The general formula is `start = failedLevel - 4`,
/// `end = failedLevel - 1`.
///
/// ⚠️ ZONE 2 OVERRIDE (Levels 21–40): the Intermediate spec removed ALL
/// remediation gates from that zone — rows for 25/30/35/40 were deleted from
/// this table and [getPreparationRangeForLevel] throws for any Level 21–40
/// target. Zone 1 and Zone 3 keep their original ranges.
Map<int, List<int>> kPreparationRangeTable = {
  5: [1, 4],
  10: [6, 9],
  15: [11, 14],
  20: [16, 19],
  45: [41, 44],
  50: [46, 49],
  55: [51, 54],
  60: [56, 59],
};

/// Whether [level] belongs to the Intermediate Zone (21–40), which by design
/// has no Hard/Super-Hardcode/Final-Boss gates at all.
bool isIntermediateZoneLevel(int level) => level >= 21 && level <= 40;

/// Returns the preparation range [start, end] for a given failed level.
///
/// Falls back to the general formula `[failedLevel - 4, failedLevel - 1]`
/// when the level is not an explicit entry in [kPreparationRangeTable].
///
/// Throws [ArgumentError] for Intermediate-Zone levels (21–40): the student
/// must never be pushed into a remediation flow there — failures on those
/// levels use standard retry feedback instead.
List<int> getPreparationRangeForLevel(int failedLevel) {
  if (isIntermediateZoneLevel(failedLevel)) {
    throw ArgumentError(
      'Level $failedLevel is in the Intermediate Zone (21-40), which has no '
      'remediation gates per the Intermediate question-bank spec.',
    );
  }

  final explicit = kPreparationRangeTable[failedLevel];
  if (explicit != null) return explicit;

  final start = (failedLevel - kPrepRangeSize).clamp(1, 60);
  final end = (failedLevel - 1).clamp(1, 60);
  if (start > end) return [1, 1];
  return [start, end];
}

// ---------------------------------------------------------------------------
// XP, Coins, Streaks, and Badges
// ---------------------------------------------------------------------------

/// Base XP awarded for completing a level.
const int kXpBase = 100;

/// Bonus XP awarded when the average time per question is below [kSpeedBonusThreshold].
const int kXpSpeedBonus = 25;

/// Average seconds per question below which the speed bonus is granted.
const int kSpeedBonusThresholdSeconds = 10;

/// Bonus XP awarded when every question is answered correctly (perfect run).
const int kXpPerfectBonus = 50;

/// Coins awarded for completing a level.
const int kCoinsPerLevel = 50;

/// Additional coins awarded for a perfect run.
const int kCoinsPerfectBonus = 25;

/// Streak multiplier percentage added per streak day (e.g. 0.10 = +10% per day).
const double kStreakXpMultiplierPerDay = 0.10;

/// Maximum streak multiplier (e.g. 0.50 = +50%).
const double kMaxStreakXpMultiplier = 0.50;

/// Streak length required to earn the Streak Master badge.
const int kStreakMasterBadgeDays = 7;

/// Consecutive fast answers required to earn the Speed Demon badge.
const int kSpeedDemonConsecutiveAnswers = 5;

/// Boss levels that award the Boss Slayer badge and boss visuals: 20
/// (Zone 1) and 60 (Zone 3).
///
/// ⚠️ ZONE 2 OVERRIDE: Level 40 was DEMOTED from Super-Hardcore boss to
/// "Moderate (Multi-Step)" by the Intermediate spec — it must NOT be listed
/// here or it would regain boss iconography/badges. See
/// md files/mathalino_intermediate_ide_prompt.md.
const Set<int> kBossLevels = {20, 60};

/// Hard-gate levels where failing triggers remediation: Zone 1 (5/10/15)
/// and Zone 3 (45/50/55). The Intermediate zone (21–40) has none.
const Set<int> kHardGateLevels = {5, 10, 15, 45, 50, 55};

/// Whether [level] is a Hard-gate level (remediation triggers on failure).
///
/// Use this instead of a bare `level % 5 == 0`, which wrongly gated the
/// Intermediate zone's Levels 25/30/35.
bool isHardGateLevel(int level) => kHardGateLevels.contains(level);

/// Whether [level] is a Boss level ([kBossLevels]).
bool isBossGateLevel(int level) => kBossLevels.contains(level);

/// Firestore document field keys for the stats object stored on /users/{uid}.stats.
class StatsField {
  static const String totalXp = 'totalXp';
  static const String coins = 'coins';
  static const String streakDays = 'streakDays';
  static const String lastActiveDate = 'lastActiveDate';
}

/// Firestore path for a user's earned badges collection.
String earnedBadgesPath(String userId) => 'users/$userId/earnedBadges';

/// Firestore document ID for the stats object stored on /users/{uid}.stats.
String statsDocumentPath(String userId) => 'users/$userId/stats/stats';