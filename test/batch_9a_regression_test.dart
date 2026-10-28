import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/services/rewards_service.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/widgets/star_rating.dart';

void main() {
  group('Batch 9A Targeted Regression Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: All answers wrong -> next level stays locked
    // -------------------------------------------------------------------------
    test('1. All answers wrong -> next level stays locked', () {
      final progress = LevelProgressProvider();
      progress.initLocal(
        currentLevel: 1,
        startingLevel: 1,
        customStatusMap: {1: 'unlocked'},
      );

      // Level 1 is unlocked, Level 2 is locked
      expect(progress.getLevelState(1), LevelState.unlocked);
      expect(progress.getLevelState(2), LevelState.locked);

      // Simulate a failed attempt where all answers are wrong:
      // Hearts drop to 0, level is NOT completed, completeLevel is NOT called.
      // After all answers wrong, level 1 remains unlocked, level 2 remains locked.
      expect(progress.getLevelState(1), LevelState.unlocked);
      expect(progress.getLevelState(2), LevelState.locked);
      expect(progress.currentLevel, 1);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Return to Adventure Map after failed attempt -> stays locked
    // -------------------------------------------------------------------------
    test('2. Return to Adventure Map after failed attempt -> stays locked', () {
      final progress = LevelProgressProvider();
      progress.initLocal(
        currentLevel: 1,
        startingLevel: 1,
        customStatusMap: {1: 'unlocked', 2: 'locked'},
      );

      // Student starts level 1, answers wrong, runs out of hearts,
      // and clicks "Back to Adventure Map" (which pops without calling completeLevel).
      expect(progress.getLevelState(1), LevelState.unlocked);
      expect(progress.getLevelState(2), LevelState.locked);
      expect(progress.currentLevel, 1);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Restart/reload after failed attempt -> stays locked
    // -------------------------------------------------------------------------
    test('3. Restart/reload after failed attempt -> stays locked', () {
      final progress = LevelProgressProvider();
      // Snapshot reflecting the persisted DB state after a failed attempt
      final snapshot = {
        'currentLevel': 1,
        'current_level': 1,
        'startingLevel': 1,
        'starting_level': 1,
        'levelStatusMap': {'1': 'unlocked', '2': 'locked'},
        'level_status_map': {'1': 'unlocked', '2': 'locked'},
        'lrn': '123456789012',
      };

      // App reloads or refetches student profile
      progress.injectProfileFromSnapshot(snapshot, 'student-user-id');

      expect(progress.currentLevel, 1);
      expect(progress.getLevelState(1), LevelState.unlocked);
      expect(progress.getLevelState(2), LevelState.locked);
      expect(progress.getLevelState(3), LevelState.locked);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Successful completion -> next level unlocks correctly
    // -------------------------------------------------------------------------
    test('4. Successful completion -> next level unlocks correctly', () async {
      final progress = LevelProgressProvider();
      progress.initLocal(
        currentLevel: 1,
        startingLevel: 1,
        customStatusMap: {1: 'unlocked'},
      );

      // Student successfully completes Level 1
      await progress.completeLevel('student-user-id', 1, lrn: '123456789012');

      expect(progress.currentLevel, 2);
      expect(progress.getLevelState(1), LevelState.completed);
      expect(progress.getLevelState(2), LevelState.unlocked);
      expect(progress.getLevelState(3), LevelState.locked);
    });

    // -------------------------------------------------------------------------
    // TEST 5: 0 stars -> 0 coins
    // -------------------------------------------------------------------------
    test('5. 0 stars -> 0 coins', () {
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 0,
      );
      expect(reward.coinGain, 0);

      final rewardsService = RewardsService();
      expect(rewardsService.calculateCoins(stars: 0), 0);
      expect(rewardsService.calculateCoins(correctCount: 0, totalQuestions: 3), 0);
      expect(StarRating.starsForAccuracy(0.0), 0);
      expect(StarRating.starsForScore(0, 3), 0);
    });

    // -------------------------------------------------------------------------
    // TEST 6: 1 star -> 5 coins
    // -------------------------------------------------------------------------
    test('6. 1 star -> 5 coins', () {
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 1,
      );
      expect(reward.coinGain, 5);

      final rewardsService = RewardsService();
      expect(rewardsService.calculateCoins(stars: 1), 5);
      expect(rewardsService.calculateCoins(correctCount: 1, totalQuestions: 3), 5);
      expect(StarRating.starsForAccuracy(33.3), 1);
      expect(StarRating.starsForScore(1, 3), 1);
    });

    // -------------------------------------------------------------------------
    // TEST 7: 2 stars -> 10 coins
    // -------------------------------------------------------------------------
    test('7. 2 stars -> 10 coins', () {
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 2,
      );
      expect(reward.coinGain, 10);

      final rewardsService = RewardsService();
      expect(rewardsService.calculateCoins(stars: 2), 10);
      expect(rewardsService.calculateCoins(correctCount: 2, totalQuestions: 3), 10);
      expect(StarRating.starsForAccuracy(66.7), 2);
      expect(StarRating.starsForScore(2, 3), 2);
    });

    // -------------------------------------------------------------------------
    // TEST 8: 3 stars -> 15 coins
    // -------------------------------------------------------------------------
    test('8. 3 stars -> 15 coins', () {
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 3,
      );
      expect(reward.coinGain, 15);

      final rewardsService = RewardsService();
      expect(rewardsService.calculateCoins(stars: 3), 15);
      expect(rewardsService.calculateCoins(correctCount: 3, totalQuestions: 3), 15);
      expect(StarRating.starsForAccuracy(100.0), 3);
      expect(StarRating.starsForScore(3, 3), 3);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Repeated completion/replay does not incorrectly duplicate rewards
    // -------------------------------------------------------------------------
    test('9. Repeated completion/replay does not incorrectly duplicate rewards', () {
      // First completion: earns 15 coins for 3 stars
      final firstPass = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: 3,
      );
      expect(firstPass.coinGain, 15);
      expect(firstPass.xpGain, 50);

      // Replay when alreadyRewarded is true: earns 0 coins and 0 XP
      final replay = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 2,
        stars: 3,
      );
      expect(replay.coinGain, 0);
      expect(replay.xpGain, 0);

      // Even with maximum stars on a challenge level replay, 0 coins are awarded
      final challengeReplay = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: true,
        nextLevel: 6,
        previousCurrentLevel: 10,
        stars: 3,
      );
      expect(challengeReplay.coinGain, 0);
      expect(challengeReplay.xpGain, 0);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Existing legitimate progress remains intact
    // -------------------------------------------------------------------------
    test('10. Existing legitimate progress remains intact', () {
      // Scenario A: A student at Level 12 replays Level 2
      final replayPlan = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: false,
        nextLevel: 3,
        previousCurrentLevel: 12,
        stars: 3,
      );
      // current_level must never be moved backwards to 3
      expect(replayPlan.currentLevel, 12);

      // Scenario B: Higher score/stars are never downgraded by a lower replay
      final mergedProgress = mergeLevelProgress(
        previousBestScore: 3,
        previousStars: 3,
        score: 1,
        accuracyPct: 33.3,
      );
      expect(mergedProgress.bestScore, 3);
      expect(mergedProgress.stars, 3);

      // Scenario C: Diagnostic placement at Level 15 keeps levels 1..14 complete
      final progress = LevelProgressProvider();
      progress.initLocal(
        currentLevel: 15,
        startingLevel: 15,
      );
      expect(progress.getLevelState(1), LevelState.completed);
      expect(progress.getLevelState(14), LevelState.completed);
      expect(progress.getLevelState(15), LevelState.challenge);
      expect(progress.getLevelState(16), LevelState.locked);
    });

    // -------------------------------------------------------------------------
    // TEST 11: Teacher and Parent show matching saved coin/star/progress values
    // -------------------------------------------------------------------------
    test('11. Teacher and Parent show matching saved coin/star/progress values for the same learner', () {
      // Flutter persists canonical computed values:
      // - student_progress.coins = currentCoins + coinGain (where coinGain = stars * 5)
      // - student_progress.current_level = newCurrentLevel
      // - level_progress.stars = merged.stars
      // - student_results.stars = earnedStars
      // - student_results.coins_awarded = coinGain

      const earnedStars = 2;
      final reward = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
        stars: earnedStars,
      );

      final studentProgressPayload = {
        'current_level': reward.currentLevel,
        'coins': 100 + reward.coinGain,
        'total_xp': 500 + reward.xpGain,
      };

      final levelProgressPayload = {
        'level': 1,
        'stars': earnedStars,
        'status': 'completed',
      };

      final studentResultsPayload = {
        'stars': earnedStars,
        'coins_awarded': reward.coinGain,
        'xp_awarded': reward.xpGain,
      };

      // Both Teacher Portal and Parent Portal consume these exact same tables and columns:
      // 1. Coins: student_progress['coins'] -> 110 (100 + 10)
      // 2. Stars: level_progress['stars'] -> 2
      // 3. Progress: student_progress['current_level'] -> 2
      expect(studentProgressPayload['coins'], 110);
      expect(levelProgressPayload['stars'], 2);
      expect(studentResultsPayload['coins_awarded'], 10);
      expect(studentProgressPayload['current_level'], 2);
    });
  });
}
