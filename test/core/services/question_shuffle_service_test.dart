import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/services/question_shuffle_service.dart';

/// Builds a {element → count} histogram used to assert that a shuffled result
/// is a true permutation (same elements, same multiplicities) of the input.
Map<T, int> _counts<T>(Iterable<T> items) {
  final map = <T, int>{};
  for (final item in items) {
    map[item] = (map[item] ?? 0) + 1;
  }
  return map;
}

void main() {
  group('QuestionShuffleService.fisherYatesShuffle', () {
    test('returns a NEW list without mutating the input', () {
      final input = <int>[1, 2, 3, 4, 5];
      final snapshot = List<int>.of(input);

      final result = QuestionShuffleService.fisherYatesShuffle(input);

      expect(identical(result, input), isFalse,
          reason: 'must return a new list, not a reference to the input');
      expect(input, equals(snapshot), reason: 'input must not be mutated');
    });

    test('preserves length and every element exactly once (permutation)',
        () {
      final input = <int>[3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 9];
      final result = QuestionShuffleService.fisherYatesShuffle(input);

      expect(result.length, input.length);
      // Same multiset — nothing added, dropped, or duplicated.
      expect(_counts(result), _counts(input));
    });

    test('does not sort ascending (shuffle is not a sort)', () {
      final input = List<int>.generate(100, (i) => i);
      final result =
          QuestionShuffleService.fisherYatesShuffle(input, random: Random(42));

      // The identity/sorted arrangement would require the astronomically
      // unlikely 1 / 100! chance; a seeded run is deterministic.
      expect(result, isNot(equals(input)));
      expect(result, isNot(equals(<int>[...input]..sort())));
    });

    test('is deterministic for a fixed Random seed', () {
      final input = List<int>.generate(50, (i) => i);

      final first = QuestionShuffleService.fisherYatesShuffle(
        input,
        random: Random(2026),
      );
      final second = QuestionShuffleService.fisherYatesShuffle(
        input,
        random: Random(2026),
      );

      expect(first, equals(second));
    });

    test('produces a different order across draws from a shared Random', () {
      final input = List<int>.generate(40, (i) => i);
      final rng = Random(7);

      final draws = <List<int>>{
        for (var i = 0; i < 5; i++)
          QuestionShuffleService.fisherYatesShuffle(input, random: rng),
      };

      // Multiple independent draws should not all collapse to one order.
      expect(draws.length, greaterThan(1));
    });

    test('handles an empty list', () {
      final input = <String>[];
      final result = QuestionShuffleService.fisherYatesShuffle(input);

      expect(result, isEmpty);
      expect(identical(result, input), isFalse);
    });

    test('handles a single-element list', () {
      final input = <String>['solo'];
      final result = QuestionShuffleService.fisherYatesShuffle(input);

      expect(result, equals(['solo']));
      expect(identical(result, input), isFalse);
    });

    test('works for arbitrary object types (Question-like records)', () {
      final input = ['Q01', 'Q02', 'Q03', 'Q04', 'Q05'];
      final result = QuestionShuffleService.fisherYatesShuffle(input);

      expect(_counts(result), _counts(input));
      expect(result.length, input.length);
    });
  });
}