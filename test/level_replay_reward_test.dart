import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';
import 'package:mathalino_student_app/widgets/star_rating.dart';

/// Unit tests for the pure reward/progress decisions used by
/// `SupabaseService.saveLevelCompletion`. The DB-writing method itself cannot be
/// exercised without a live Supabase client, so the exact shipped logic lives in
/// these top-level helpers and is verified here.
void main() {
  group('planLevelCompletionRewards — first completion vs replay', () {
    test('first regular completion earns 50 XP / 10 coins', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
      );
      expect(p.xpGain, 50);
      expect(p.coinGain, 10);
    });

    test('first challenge completion earns 100 XP / 20 coins', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: true,
        nextLevel: 6,
        previousCurrentLevel: 5,
      );
      expect(p.xpGain, 100);
      expect(p.coinGain, 20);
    });

    test('replay of an already-rewarded regular level earns 0 / 0', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 1,
      );
      expect(p.xpGain, 0);
      expect(p.coinGain, 0);
    });

    test('replay of an already-rewarded challenge level earns 0 / 0', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: true,
        nextLevel: 6,
        previousCurrentLevel: 5,
      );
      expect(p.xpGain, 0);
      expect(p.coinGain, 0);
    });

    test(
      'RMA-credited (placement-only) level is NOT treated as rewarded, so the '
      'first real gameplay completion still earns the full amount',
      () {
        // Placement-skipped levels never create a LEVEL_* student_results row
        // with xp_awarded > 0, so the ledger reports alreadyRewarded == false.
        final p = planLevelCompletionRewards(
          alreadyRewarded: false,
          isChallenge: false,
          nextLevel: 42,
          previousCurrentLevel: 41,
        );
        expect(p.xpGain, 50);
        expect(p.coinGain, 10);
      },
    );
  });

  group('planLevelCompletionRewards — never move current_level backwards', () {
    test('advances when nextLevel is ahead of the stored level', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 4,
        previousCurrentLevel: 3,
      );
      expect(p.currentLevel, 4);
    });

    test('keeps the higher stored level when replaying an earlier one', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: true,
        isChallenge: false,
        nextLevel: 4,
        previousCurrentLevel: 20,
      );
      expect(p.currentLevel, 20);
    });

    test('first-ever record (previous 0) still advances', () {
      final p = planLevelCompletionRewards(
        alreadyRewarded: false,
        isChallenge: false,
        nextLevel: 2,
        previousCurrentLevel: 0,
      );
      expect(p.currentLevel, 2);
    });
  });

  group('mergeLevelProgress — preserve the highest best_score and stars', () {
    test('a lower replay cannot overwrite a better prior best_score/stars', () {
      final m = mergeLevelProgress(
        previousBestScore: 9,
        previousStars: 3,
        score: 3,
        accuracyPct: 30.0,
      );
      expect(m.bestScore, 9);
      expect(m.stars, 3);
    });

    test('a better replay raises best_score/stars', () {
      final m = mergeLevelProgress(
        previousBestScore: 2,
        previousStars: 1,
        score: 10,
        accuracyPct: 100.0,
      );
      expect(m.bestScore, 10);
      expect(m.stars, 3);
    });

    test('equal values are preserved', () {
      final m = mergeLevelProgress(
        previousBestScore: 7,
        previousStars: 2,
        score: 7,
        accuracyPct: 65.0,
      );
      expect(m.bestScore, 7);
      expect(m.stars, 2);
    });

    test('stars thresholds match the on-screen StarRating source of truth', () {
      for (final pct in const [100.0, 90.0, 89.9, 60.0, 59.9, 0.0]) {
        final viaMerge = mergeLevelProgress(
          previousBestScore: 0,
          previousStars: 0,
          score: 0,
          accuracyPct: pct,
        ).stars;
        expect(
          viaMerge,
          StarRating.starsForAccuracy(pct),
          reason: 'stored and displayed stars must agree at $pct%',
        );
      }
    });
  });
}
