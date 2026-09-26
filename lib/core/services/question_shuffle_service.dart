// lib/core/services/question_shuffle_service.dart
//
// Mathalino question shuffling utility. Provides the shared Fisher-Yates
// shuffle used to randomize diagnostic attempts and level question sets.

import 'dart:math';

/// Shuffle service used to randomize question ordering across Mathalino.
///
/// The single dependency-free entrypoint, [fisherYatesShuffle], is used by the
/// diagnostic question selection flow (via [DiagnosticQuestionService]) and any
/// other feature that needs a random permutation of a question set (level
/// quests, remediation, daily challenges, etc.).
class QuestionShuffleService {
  /// Shuffles a copy of [items] using the Fisher-Yates (Knuth) algorithm.
  ///
  /// Returns a **NEW** `List<T>`; the input [items] is never mutated.
  ///
  /// **Time / space complexity:**
  /// O(n) time and O(n) extra space for the shuffled copy. The actual
  /// permutation work happens in-place on the copy with a single linear pass,
  /// so beyond the copy the shuffle itself uses O(1) auxiliary space.
  ///
  /// **Why Fisher-Yates instead of a sorting algorithm?**
  /// (Bubble / Selection / Insertion / Merge / Quick Sort)
  ///
  /// The goal here is a *random permutation*, not an *ordered arrangement*:
  /// - Sorting algorithms impose a total order through a comparator (e.g. by
  ///   difficulty, grade, or id) — the exact opposite of randomization. A
  ///   "shuffle via sort" hack that feeds a random key to a comparator is
  ///   non-deterministic, biased toward certain permutations, and can throw
  ///   off the comparator contract entirely.
  /// - Comparison sorts have running times that depend on the input
  ///   distribution: O(n²) worst/average for Bubble, Selection, and Insertion;
  ///   O(n log n) average for Merge/Quick. None of this matters for a shuffle,
  ///   which needs exactly n − 1 random swaps regardless of input ordering.
  /// - Fisher-Yates produces every one of the n! permutations with equal
  ///   probability in a single O(n) pass using only a handful of in-place
  ///   swaps — the optimal result that no comparison-based sort can match.
  ///
  /// **Contract:** this function intentionally contains **no sorting or
  /// comparison logic whatsoever**. It only swaps elements at random indices.
  static List<T> fisherYatesShuffle<T>(List<T> items, {Random? random}) {
    final rng = random ?? Random();
    // Copy first so the caller's list is never mutated.
    final result = List<T>.of(items);

    for (var i = result.length - 1; i > 0; i--) {
      // Pick a random index uniformly in [0, i], then swap i with it.
      final j = rng.nextInt(i + 1);
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }

    return result;
  }
}
