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

  /// Computes coins awarded for completing a level or challenge.
  /// Formula: Coins earned = Stars earned × 5.
  /// - 3 stars = 15 coins
  /// - 2 stars = 10 coins
  /// - 1 star = 5 coins
  /// - 0 stars = 0 coins
  int calculateCoins({
    int? stars,
    int? correctCount,
    int? totalQuestions,
  }) {
    if (stars != null) {
      return (stars * 5).clamp(0, 15);
    }
    final score = correctCount ?? 0;
    final attempted = totalQuestions ?? 0;
    if (score <= 0 || attempted <= 0) return 0;
    final accuracy = (score / attempted) * 100.0;
    final derivedStars = accuracy >= 90.0
        ? 3
        : (accuracy >= 60.0 ? 2 : (accuracy > 0.0 ? 1 : 0));
    return (derivedStars * 5).clamp(0, 15);
  }

  /// Normalizes a timestamp to the calendar day in Asia/Manila (UTC+8).
  /// Asia/Manila is strictly UTC+8 with no Daylight Saving Time.
  static DateTime toManilaDate(DateTime dt) {
    final manilaInstant = dt.toUtc().add(const Duration(hours: 8));
    return DateTime.utc(manilaInstant.year, manilaInstant.month, manilaInstant.day);
  }

  /// Updates the daily streak based on the previous active date in Asia/Manila.
  ///
  /// Returns a SIGNAL value (not the actual streak):
  /// - 0 when [lastActiveDate] is today (keep existing streak).
  /// - 1 when [lastActiveDate] is yesterday (increment streak).
  /// - 0 when the gap is more than one day (reset to 1).
  ///
  /// Prefer [resolveStreak] when the actual new streak count is needed.
  int updateStreak(DateTime lastActiveDate, {DateTime? now}) {
    final today = toManilaDate(now ?? DateTime.now());
    final last = toManilaDate(lastActiveDate);

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
  /// the previous active date, strictly using Asia/Manila (UTC+8) calendar days.
  ///
  /// Approved rules (Batch 9B):
  /// - Any qualifying learning activity (passed level or daily challenge) updates streak.
  /// - Multiple completions on the same calendar day keep the same streak.
  /// - Consecutive calendar days increment the streak by 1.
  /// - A missed calendar day (gap > 1) resets the streak to 1.
  /// - First qualifying day starts the streak at 1.
  int resolveStreak({
    required int currentStreak,
    DateTime? lastActiveDate,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final today = toManilaDate(effectiveNow);

    if (lastActiveDate == null) {
      return 1; // First-ever active day
    }

    final last = toManilaDate(lastActiveDate);
    final difference = today.difference(last).inDays;

    if (difference == 0) {
      return currentStreak == 0 ? 1 : currentStreak; // Same calendar day: preserve streak (min 1)
    }
    if (difference == 1) {
      return (currentStreak == 0 ? 0 : currentStreak) + 1; // Consecutive day: increment
    }
    return 1; // Missed day (difference > 1) or future clock jump: reset to 1
  }
}
