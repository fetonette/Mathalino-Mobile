library;

import '../constants/game_rules.dart';
import '../models/badge.dart';

/// Pure badge rules for Mathalino Student App.
///
/// Each check is a pure function taking only the stats/history it needs and
/// returning a bool. New badges are added by appending a new function and a
/// corresponding entry in [kBadgeRules] so the post-level rules pass stays
/// additive rather than scattering badge logic across providers.

/// Returns true when every question was answered correctly (perfect score).
bool checkPerfectScoreBadge({
  required int correctCount,
  required int totalQuestions,
}) {
  if (totalQuestions <= 0) return false;
  return correctCount >= totalQuestions;
}

/// Returns true when at least [kSpeedDemonConsecutiveAnswers] consecutive
/// answers were each submitted in under [kSpeedBonusThresholdSeconds]
/// seconds.
bool checkSpeedDemonBadge({
  required List<Duration> answerTimes,
}) {
  var consecutive = 0;
  for (final time in answerTimes) {
    if (time.inSeconds < kSpeedBonusThresholdSeconds) {
      consecutive++;
      if (consecutive >= kSpeedDemonConsecutiveAnswers) return true;
    } else {
      consecutive = 0;
    }
  }
  return false;
}

/// Returns true when the student's streak is at least [kStreakMasterBadgeDays] days.
bool checkStreakMasterBadge({required int streakDays}) {
  return streakDays >= kStreakMasterBadgeDays;
}

/// Returns true when the completed level is one of the boss levels (20, 40, 60).
bool checkBossSlayerBadge({required int completedLevel}) {
  return kBossLevels.contains(completedLevel);
}

/// Aggregates all badge checks into a single rules pass.
///
/// Returns the list of badge IDs earned given the latest session stats.
List<String> evaluateBadges({
  required int correctCount,
  required int totalQuestions,
  required List<Duration> answerTimes,
  required int streakDays,
  required int completedLevel,
}) {
  final earned = <String>[];

  if (checkPerfectScoreBadge(
    correctCount: correctCount,
    totalQuestions: totalQuestions,
  )) {
    earned.add(BadgeIds.perfectScore);
  }

  if (checkSpeedDemonBadge(answerTimes: answerTimes)) {
    earned.add(BadgeIds.speedDemon);
  }

  if (checkStreakMasterBadge(streakDays: streakDays)) {
    earned.add(BadgeIds.streakMaster);
  }

  if (checkBossSlayerBadge(completedLevel: completedLevel)) {
    earned.add(BadgeIds.bossSlayer);
  }

  return earned;
}
