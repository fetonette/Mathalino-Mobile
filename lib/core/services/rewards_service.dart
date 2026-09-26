import '../constants/game_rules.dart';

/// Rewards Service for Mathalino Student App.
///
/// Computes XP for a completed level and maintains the daily streak. Both
/// methods are pure (no Firestore I/O) so they are trivially unit-testable
/// and reused by the provider before a single atomic batch write.
class RewardsService {
  /// Computes the XP awarded for completing a level.
  ///
  /// XP = base + speed bonus + perfect bonus, then multiplied by the streak
  /// multiplier.
  ///
  /// [level]          - The completed level number.
  /// [correctCount]   - Number of questions answered correctly.
  /// [totalQuestions] - Number of questions in the session.
  /// [timeSpent]      - Total time spent answering the session.
  /// [streakDays]     - Current streak before today's update.
  int calculateXp({
    required int level,
    required int correctCount,
    required int totalQuestions,
    required Duration timeSpent,
    required int streakDays,
  }) {
    var xp = kXpBase;

    // Speed bonus: average time per question below threshold.
    if (totalQuestions > 0) {
      final avgSeconds = timeSpent.inSeconds / totalQuestions;
      if (avgSeconds < kSpeedBonusThresholdSeconds) {
        xp += kXpSpeedBonus;
      }
    }

    // Perfect bonus.
    if (totalQuestions > 0 && correctCount >= totalQuestions) {
      xp += kXpPerfectBonus;
    }

    // Streak multiplier: +10% per streak day, capped at +50%.
    final multiplier = 1.0 +
        (streakDays * kStreakXpMultiplierPerDay)
            .clamp(0.0, kMaxStreakXpMultiplier);
    return (xp * multiplier).round();
  }

  /// Computes coins awarded for completing a level.
  int calculateCoins({
    required int correctCount,
    required int totalQuestions,
  }) {
    var coins = kCoinsPerLevel;
    if (totalQuestions > 0 && correctCount >= totalQuestions) {
      coins += kCoinsPerfectBonus;
    }
    return coins;
  }

  /// Updates the daily streak based on the previous active date.
  ///
  /// Returns a SIGNAL value (not the actual streak):
  /// - 0 when [lastActiveDate] is today (keep existing streak).
  /// - 1 when [lastActiveDate] is yesterday (increment streak).
  /// - 0 when the gap is more than one day (reset to 1).
  ///
  /// Prefer [resolveStreak] when the actual new streak count is needed.
  int updateStreak(DateTime lastActiveDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      lastActiveDate.year,
      lastActiveDate.month,
      lastActiveDate.day,
    );

    final difference = today.difference(last).inDays;

    if (difference == 0) {
      return 0; // Signal: keep existing streak (caller merges with current value).
    }
    if (difference == 1) {
      return 1; // Signal: increment by 1.
    }
    return 0; // Gap > 1 day: reset. Signal value 0 will reset to 1 below.
  }

  /// Resolves the actual new streak count based on the current streak and
  /// the previous active date.
  ///
  /// Returns the concrete streak value to persist:
  /// - [currentStreak] when [lastActiveDate] is today.
  /// - [currentStreak] + 1 when [lastActiveDate] is yesterday.
  /// - 1 when the gap is more than one day or [lastActiveDate] is null.
  int resolveStreak({
    required int currentStreak,
    DateTime? lastActiveDate,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastActiveDate == null) {
      return 1;
    }

    final last = DateTime(
      lastActiveDate.year,
      lastActiveDate.month,
      lastActiveDate.day,
    );

    final difference = today.difference(last).inDays;

    if (difference == 0) {
      return currentStreak; // Already active today.
    }
    if (difference == 1) {
      return currentStreak + 1; // Consecutive day.
    }
    return 1; // Gap > 1 day: reset.
  }
}
