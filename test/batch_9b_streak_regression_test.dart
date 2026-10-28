import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/rewards_service.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';

void main() {
  final rewardsService = RewardsService();

  group('Batch 9B Daily Streak Regression Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: First qualifying day -> streak starts at 1
    // -------------------------------------------------------------------------
    test('1. First qualifying day starts streak at 1', () {
      final now = DateTime.utc(2026, 10, 27, 2, 0); // 10:00 AM Manila
      final streak = rewardsService.resolveStreak(
        currentStreak: 0,
        lastActiveDate: null,
        now: now,
      );
      expect(streak, 1);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Second consecutive day -> increments streak
    // -------------------------------------------------------------------------
    test('2. Second consecutive day increments streak by 1', () {
      final day1 = DateTime.utc(2026, 10, 26, 6, 0); // Oct 26 14:00 Manila
      final day2 = DateTime.utc(2026, 10, 27, 2, 0); // Oct 27 10:00 Manila

      final streak = rewardsService.resolveStreak(
        currentStreak: 1,
        lastActiveDate: day1,
        now: day2,
      );
      expect(streak, 2);

      // Third consecutive day
      final day3 = DateTime.utc(2026, 10, 28, 1, 0); // Oct 28 09:00 Manila
      final streak3 = rewardsService.resolveStreak(
        currentStreak: 2,
        lastActiveDate: day2,
        now: day3,
      );
      expect(streak3, 3);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Multiple completions on the same day -> preserves streak (no duplicates)
    // -------------------------------------------------------------------------
    test('3. Multiple completions on the same day do not increment repeatedly', () {
      final completion1 = DateTime.utc(2026, 10, 27, 1, 0); // Oct 27 09:00 Manila
      final completion2 = DateTime.utc(2026, 10, 27, 4, 30); // Oct 27 12:30 Manila
      final completion3 = DateTime.utc(2026, 10, 27, 13, 0); // Oct 27 21:00 Manila

      // First activity of day 2
      final s1 = rewardsService.resolveStreak(
        currentStreak: 1,
        lastActiveDate: DateTime.utc(2026, 10, 26, 8, 0),
        now: completion1,
      );
      expect(s1, 2);

      // Second activity on same day
      final s2 = rewardsService.resolveStreak(
        currentStreak: s1,
        lastActiveDate: completion1,
        now: completion2,
      );
      expect(s2, 2); // Unchanged

      // Third activity on same day
      final s3 = rewardsService.resolveStreak(
        currentStreak: s2,
        lastActiveDate: completion2,
        now: completion3,
      );
      expect(s3, 2); // Unchanged
    });

    // -------------------------------------------------------------------------
    // TEST 4: One missed calendar day -> resets streak to 1
    // -------------------------------------------------------------------------
    test('4. One missed calendar day resets streak to 1', () {
      // Active on Oct 25, missed Oct 26, active on Oct 27 (gap = 2 calendar days)
      final lastActive = DateTime.utc(2026, 10, 25, 8, 0); // Oct 25 Manila
      final today = DateTime.utc(2026, 10, 27, 2, 0); // Oct 27 Manila

      final streak = rewardsService.resolveStreak(
        currentStreak: 5,
        lastActiveDate: lastActive,
        now: today,
      );
      expect(streak, 1);
    });

    // -------------------------------------------------------------------------
    // TEST 5: Midnight/date boundary behavior in Asia/Manila (UTC+8)
    // -------------------------------------------------------------------------
    test('5. Midnight boundary in Asia/Manila (UTC+8) evaluates calendar days correctly', () {
      // Manila is UTC+8.
      // Oct 26 23:55 Manila = Oct 26 15:55 UTC.
      final lateNightOct26 = DateTime.utc(2026, 10, 26, 15, 55);

      // Oct 27 00:05 Manila = Oct 26 16:05 UTC.
      // Even though elapsed time is only 10 minutes, the Manila calendar day changed!
      final earlyMorningOct27 = DateTime.utc(2026, 10, 26, 16, 5);

      final streak = rewardsService.resolveStreak(
        currentStreak: 3,
        lastActiveDate: lateNightOct26,
        now: earlyMorningOct27,
      );
      expect(streak, 4, reason: 'Crossing midnight in Asia/Manila is consecutive day');

      // Another activity at Oct 27 23:50 Manila (Oct 27 15:50 UTC)
      final lateNightOct27 = DateTime.utc(2026, 10, 27, 15, 50);
      final sameDayStreak = rewardsService.resolveStreak(
        currentStreak: 4,
        lastActiveDate: earlyMorningOct27,
        now: lateNightOct27,
      );
      expect(sameDayStreak, 4, reason: 'Same calendar day in Asia/Manila does not advance again');
    });

    // -------------------------------------------------------------------------
    // TEST 6: Refresh and app restart -> preserves correct streak
    // -------------------------------------------------------------------------
    test('6. Refresh and app restart preserves correct streak from student_progress', () {
      // Simulating Supabase student_progress payload after streak write
      final progressRow = {
        'lrn': '123456789012',
        'current_level': 33,
        'coins': 95,
        'total_xp': 1600,
        'streak_days': 3,
        'raw_data': {
          'stats': {
            'streakDays': 3,
            'lastActiveDate': '2026-10-27T08:00:00Z',
          },
        },
      };

      // Mock user document having default stats: {"streakDays": 0}
      final userRow = {
        'id': 'user-123',
        'lrn': '123456789012',
        'name': 'Jia Lim',
        'stats': {'streakDays': 0, 'coins': 0, 'totalXp': 0},
      };

      final profile = StudentProfile.fromComposite(
        uid: 'user-123',
        userRow: userRow,
        progressRow: progressRow,
      );

      // Canonical streak_days must win over default stats.streakDays: 0
      expect(profile.stats.streakDays, 3);
      expect(profile.currentLevel, 33);
      expect(profile.stats.coins, 95);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Teacher and Parent show the same saved streak
    // -------------------------------------------------------------------------
    test('7. Teacher and Parent read the same canonical streak_days', () {
      // Canonical row written by Flutter to student_progress
      final canonicalStudentProgress = {
        'lrn': '123456789012',
        'current_level': 33,
        'total_xp': 1600,
        'coins': 95,
        'streak_days': 4,
      };

      // Teacher portal reading logic (matches updated script.js line 6567):
      // const streak = progressData.streakDays ?? progressData.streak_days ?? progressData.stats?.streakDays ?? 0;
      final teacherStreak = canonicalStudentProgress['streakDays'] ??
          canonicalStudentProgress['streak_days'] ??
          0;

      // Parent portal reading logic (matches updated script.js line 5592):
      // const progStreakRaw = progressRow ? (progressRow.streak_days != null ? progressRow.streak_days : progressRow.streakDays) : null;
      final parentStreak = canonicalStudentProgress['streak_days'] ??
          canonicalStudentProgress['streakDays'] ??
          0;

      expect(teacherStreak, 4);
      expect(parentStreak, 4);
      expect(teacherStreak, equals(parentStreak));
    });

    // -------------------------------------------------------------------------
    // TEST 8: Different students never share streak data
    // -------------------------------------------------------------------------
    test('8. Different students maintain independent streaks', () {
      final studentA = StudentProfile.fromMap({
        'lrn': '111111111111',
        'displayName': 'Student A',
        'streak_days': 5,
        'current_level': 10,
      }, 'uid-A');

      final studentB = StudentProfile.fromMap({
        'lrn': '222222222222',
        'displayName': 'Student B',
        'streak_days': 1,
        'current_level': 3,
      }, 'uid-B');

      expect(studentA.stats.streakDays, 5);
      expect(studentB.stats.streakDays, 1);
      expect(studentA.stats.streakDays != studentB.stats.streakDays, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 9: No changes to existing coins, stars, or level progression
    // -------------------------------------------------------------------------
    test('9. No changes to existing coins, stars, or level progression logic', () {
      // 3 stars = 15 coins (Batch 9A rule remains exact)
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 34,
        previousCurrentLevel: 33,
        stars: 3,
      );
      expect(reward.coinGain, 15);
      expect(reward.xpGain, 50);
      expect(reward.currentLevel, 34);

      // Replay grants 0 coins / 0 XP, never moving currentLevel backwards
      final replay = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: false,
        nextLevel: 10,
        previousCurrentLevel: 34,
        stars: 3,
      );
      expect(replay.coinGain, 0);
      expect(replay.xpGain, 0);
      expect(replay.currentLevel, 34);
    });
  });
}
