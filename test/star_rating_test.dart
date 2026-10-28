import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/widgets/star_rating.dart';

/// Guards the Phase 1 presentation rule: displayed stars must reuse the exact
/// thresholds already persisted by `SupabaseService.saveLevelCompletion`
/// (accuracy >= 90 → 3, >= 60 → 2, otherwise 1), computed from the same
/// score / attempted-total counters the persistence path uses.
void main() {
  group('StarRating.starsForAccuracy (canonical thresholds)', () {
    test('3 stars at/above 90%', () {
      expect(StarRating.starsForAccuracy(100.0), 3);
      expect(StarRating.starsForAccuracy(90.0), 3);
    });
    test('2 stars from 60% up to below 90%', () {
      expect(StarRating.starsForAccuracy(89.9), 2);
      expect(StarRating.starsForAccuracy(60.0), 2);
    });
    test('1 star below 60% and above 0%', () {
      expect(StarRating.starsForAccuracy(59.9), 1);
      expect(StarRating.starsForAccuracy(1.0), 1);
    });
    test('0 stars at 0%', () {
      expect(StarRating.starsForAccuracy(0.0), 0);
    });
  });

  group('StarRating.starsForScore (mirrors persistence path)', () {
    test('1-/2-/3-star gameplay scenarios', () {
      expect(StarRating.starsForScore(3, 3), 3); // 100%
      expect(StarRating.starsForScore(2, 3), 2); // 66.7%
      expect(StarRating.starsForScore(1, 3), 1); // 33.3%
      expect(StarRating.starsForScore(9, 10), 3); // 90%
      expect(StarRating.starsForScore(8, 10), 2); // 80%
      expect(StarRating.starsForScore(6, 10), 2); // 60%
      expect(StarRating.starsForScore(1, 2), 1); // 50%
    });

    test('zero-attempt defensive handling never divides by zero and yields 0 stars', () {
      expect(StarRating.accuracyForScore(0, 0), 0.0);
      expect(StarRating.starsForScore(0, 0), 0);
      expect(StarRating.starsForScore(0, 3), 0);
      expect(StarRating.accuracyForScore(5, -1), 0.0);
    });

    test('accuracy rounds to one decimal like the persisted value', () {
      expect(StarRating.accuracyForScore(2, 3), 66.7);
      expect(StarRating.accuracyForScore(1, 3), 33.3);
    });
  });

  test('messageForStars returns a friendly caption for 0/1/2/3', () {
    expect(StarRating.messageForStars(3), isNotEmpty);
    expect(StarRating.messageForStars(2), isNotEmpty);
    expect(StarRating.messageForStars(1), isNotEmpty);
    expect(StarRating.messageForStars(0), isNotEmpty);
  });
}
