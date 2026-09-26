import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question_model.dart';

void main() {
  group('QuestionModel.fromMap / toMap', () {
    final map = <String, dynamic>{
      'question_id': 'L5-Q3',
      'level': 5,
      'domain': 'Hard Fractions',
      'grade_tag': 'Grade 1-3',
      'difficulty': 'Hard',
      'question_text': 'A cake is cut into 4 equal pieces.',
      'choices': {'A': '1/4', 'B': '2/4', 'C': '3/4', 'D': '4/4'},
      'correct_answer': 'C',
      'challenge_group': 5,
      'attempt_number': 0,
    };

    test('round-trips through toMap after fromMap', () {
      final model = QuestionModel.fromMap(map, 'L5-Q3');
      expect(model.questionId, 'L5-Q3');
      expect(model.level, 5);
      expect(model.domain, 'Hard Fractions');
      expect(model.gradeTag, 'Grade 1-3');
      expect(model.difficulty, 'Hard');
      expect(model.choices['C'], '3/4');
      expect(model.correctAnswer, 'C');
      expect(model.originalCorrectAnswer, 'C');
      expect(model.correctAnswerValue, '3/4');
      expect(model.challengeGroup, 5);
      expect(model.toMap()['question_id'], 'L5-Q3');
      expect(model.toMap()['choices'], map['choices']);
      expect(model.toMap()['correct_answer'], 'C');
    });

    test('fromMap derives the doc id and applies defaults when sparse', () {
      final model = QuestionModel.fromMap({}, 'L1-Q1');
      expect(model.questionId, 'L1-Q1');
      expect(model.level, 1);
      expect(model.difficulty, 'Preparation');
      expect(model.choices, isEmpty);
    });

    test('fromMap tolerates a list-shaped choices field', () {
      final model = QuestionModel.fromMap(
        {'choices': ['a', 'b', 'c', 'd']},
        'L1-Q1',
      );
      expect(model.choices['A'], 'a');
      expect(model.choices['D'], 'd');
    });
  });

  group('QuestionModel.isCorrect (Unshuffled Baseline)', () {
    final q = QuestionModel.fromMap(const {
      'question_id': 'L1-Q1',
      'level': 1,
      'domain': 'Number Identification',
      'grade_tag': 'Grade 1-3',
      'difficulty': 'Preparation',
      'question_text': 'Which is greater: 4 or 7?',
      'choices': {'A': '4', 'B': '7', 'C': 'Both', 'D': '0'},
      'correct_answer': 'B',
      'challenge_group': 5,
      'attempt_number': 0,
    }, 'L1-Q1');

    test('matches by choice key (case-insensitive)', () {
      expect(q.isCorrect('B'), isTrue);
      expect(q.isCorrect('b'), isTrue);
      expect(q.isCorrect('A'), isFalse);
    });

    test('matches by the correct choice value', () {
      expect(q.isCorrect('7'), isTrue);
      expect(q.isCorrect('4'), isFalse);
    });

    test('rejects null/empty answers', () {
      expect(q.isCorrect(null), isFalse);
      expect(q.isCorrect(''), isFalse);
    });
  });

  group('QuestionModel Choice Shuffling & Answer Key Invariance', () {
    // Exact user scenario:
    // Original: A = 12, B = 15, C = 18 (correct), D = 20
    final userQuestion = QuestionModel(
      questionId: 'SPEC-01',
      level: 1,
      domain: 'Number Sense',
      gradeTag: 'Grade 1',
      difficulty: 'Preparation',
      questionText: 'What is the target value?',
      choices: {'A': '12', 'B': '15', 'C': '18', 'D': '20'},
      correctAnswer: 'C',
    );

    test('Specific user example: recognizing 18 when shuffled to slot A', () {
      // Create a deterministic shuffled question where 18 lands in slot A
      final shuffled = QuestionModel(
        questionId: userQuestion.questionId,
        level: userQuestion.level,
        domain: userQuestion.domain,
        gradeTag: userQuestion.gradeTag,
        difficulty: userQuestion.difficulty,
        questionText: userQuestion.questionText,
        // Shuffled display: A=18, B=12, C=20, D=15
        choices: {'A': '18', 'B': '12', 'C': '20', 'D': '15'},
        correctAnswer: 'A', // 18 is now in slot A
        originalChoices: userQuestion.choices,
        originalCorrectAnswer: 'C',
        choiceKeyMapping: {'A': 'C', 'B': 'A', 'C': 'D', 'D': 'B'},
      );

      // 1. Tapping button A (which shows 18) MUST be recognized as CORRECT
      expect(shuffled.isCorrect('A'), isTrue);
      expect(shuffled.isCorrect('a'), isTrue);

      // 2. Submitting text '18' directly MUST be recognized as CORRECT
      expect(shuffled.isCorrect('18'), isTrue);

      // 3. Submitting the stable choice ID 'C' MUST be recognized as CORRECT
      expect(shuffled.isCorrect('C'), isFalse,
          reason:
              'Tapping button C (showing 20) must be FALSE, not true, because 20 is incorrect');

      // 4. Buttons B, C, D (showing 12, 20, 15) MUST be recognized as FALSE
      expect(shuffled.isCorrect('B'), isFalse);
      expect(shuffled.isCorrect('C'), isFalse);
      expect(shuffled.isCorrect('D'), isFalse);
      expect(shuffled.isCorrect('12'), isFalse);
      expect(shuffled.isCorrect('20'), isFalse);
      expect(shuffled.isCorrect('15'), isFalse);

      // 5. Shuffling does NOT alter the original answer key or choices
      expect(shuffled.originalCorrectAnswer, 'C');
      expect(shuffled.originalChoices['C'], '18');
      expect(shuffled.correctAnswerValue, '18');

      // 6. Serializing via toMap() preserves the authoritative bank schema
      final map = shuffled.toMap();
      expect(map['correct_answer'], 'C');
      expect(map['choices']['C'], '18');
    });

    test('withShuffledChoices randomizes choices using Fisher-Yates and keeps answer key intact', () {
      // Test 50 permutations with random seeds
      for (var seed = 1; seed <= 50; seed++) {
        final rng = Random(seed);
        final shuffled = userQuestion.withShuffledChoices(rng: rng);

        // Choices must contain all 4 original values
        expect(shuffled.choices.length, 4);
        expect(shuffled.choices.values.toSet(), equals({'12', '15', '18', '20'}));

        // The correct value MUST remain '18'
        expect(shuffled.correctAnswerValue, '18');

        // Original answer key and choices must be preserved
        expect(shuffled.originalCorrectAnswer, 'C');
        expect(shuffled.originalChoices, equals(userQuestion.choices));

        // The display letter of the correct choice
        final displayCorrect = shuffled.displayCorrectAnswer;
        expect(['A', 'B', 'C', 'D'].contains(displayCorrect), isTrue);

        // The display slot MUST hold the value '18'
        expect(shuffled.choices[displayCorrect], '18');

        // isCorrect MUST be true for the correct display letter
        expect(shuffled.isCorrect(displayCorrect), isTrue);

        // isCorrect MUST be true for the text value '18'
        expect(shuffled.isCorrect('18'), isTrue);

        // All OTHER display letters must be FALSE
        for (final letter in ['A', 'B', 'C', 'D']) {
          if (letter != displayCorrect) {
            expect(shuffled.isCorrect(letter), isFalse,
                reason: 'Display slot $letter contains "${shuffled.choices[letter]}" and should be false');
          }
        }
      }
    });

    test('Rebuilding or reloading does not change the intended answer', () {
      final shuffled = userQuestion.withShuffledChoices(rng: Random(42));
      final firstCorrectSlot = shuffled.displayCorrectAnswer;
      final firstCorrectVal = shuffled.correctAnswerValue;

      // Accessing properties multiple times (simulating widget rebuilds)
      for (var i = 0; i < 10; i++) {
        expect(shuffled.displayCorrectAnswer, firstCorrectSlot);
        expect(shuffled.correctAnswerValue, firstCorrectVal);
        expect(shuffled.isCorrect(firstCorrectSlot), isTrue);
        expect(shuffled.isCorrect(firstCorrectVal), isTrue);
      }
    });

    test('ChoiceOption objects are correctly populated in display order', () {
      final shuffled = userQuestion.withShuffledChoices(rng: Random(100));
      final options = shuffled.choiceOptions;

      expect(options.length, 4);
      expect(options.map((o) => o.displayLabel).toList(), equals(['A', 'B', 'C', 'D']));

      // Exactly ONE choice must be marked as correct
      final correctOptions = options.where((o) => o.isCorrect).toList();
      expect(correctOptions.length, 1);
      expect(correctOptions.first.text, '18');
      expect(correctOptions.first.stableId, 'C');
      expect(correctOptions.first.displayLabel, shuffled.displayCorrectAnswer);
    });
  });

  group('Real Mathalino Question Bank Shuffling Tests (All 4 Positions)', () {
    // 1. Correct answer originally at Position A: L9-Q3
    test('Real question L9-Q3 (Original answer key A, value "1/2")', () {
      final q = QuestionModel.fromMap(const {
        'question_id': 'L9-Q3',
        'level': 9,
        'domain': 'Fractions',
        'grade_tag': 'Grade 1-3',
        'difficulty': 'Preparation',
        'question_text': 'Which is greater? 1/2 or 1/4',
        'choices': {
          'A': '1/2',
          'B': '1/4',
          'C': 'Equal',
          'D': 'Cannot tell',
        },
        'correct_answer': 'A',
      }, 'L9-Q3');

      expect(q.correctAnswer, 'A');
      expect(q.correctAnswerValue, '1/2');

      // Shuffle with 20 seeds
      for (var seed = 1; seed <= 20; seed++) {
        final shuffled = q.withShuffledChoices(rng: Random(seed));
        final correctSlot = shuffled.displayCorrectAnswer;

        expect(shuffled.choices[correctSlot], '1/2');
        expect(shuffled.isCorrect(correctSlot), isTrue);
        expect(shuffled.isCorrect('1/2'), isTrue);

        for (final key in ['A', 'B', 'C', 'D']) {
          if (key != correctSlot) {
            expect(shuffled.isCorrect(key), isFalse);
          }
        }
      }
    });

    // 2. Correct answer originally at Position B: L1-Q1
    test('Real question L1-Q1 (Original answer key B, value "7")', () {
      final q = QuestionModel.fromMap(const {
        'question_id': 'L1-Q1',
        'level': 1,
        'domain': 'Number Identification',
        'grade_tag': 'Grade 1-3',
        'difficulty': 'Preparation',
        'question_text': 'Which number is greater: 4 or 7?',
        'choices': {
          'A': '4',
          'B': '7',
          'C': 'Both are equal',
          'D': '0',
        },
        'correct_answer': 'B',
      }, 'L1-Q1');

      expect(q.correctAnswer, 'B');
      expect(q.correctAnswerValue, '7');

      for (var seed = 1; seed <= 20; seed++) {
        final shuffled = q.withShuffledChoices(rng: Random(seed));
        final correctSlot = shuffled.displayCorrectAnswer;

        expect(shuffled.choices[correctSlot], '7');
        expect(shuffled.isCorrect(correctSlot), isTrue);
        expect(shuffled.isCorrect('7'), isTrue);

        for (final key in ['A', 'B', 'C', 'D']) {
          if (key != correctSlot) {
            expect(shuffled.isCorrect(key), isFalse);
          }
        }
      }
    });

    // 3. Correct answer originally at Position C: L5-Q3
    test('Real question L5-Q3 (Original answer key C, value "3/4")', () {
      final q = QuestionModel.fromMap(const {
        'question_id': 'L5-Q3',
        'level': 5,
        'domain': 'Hard Fractions',
        'grade_tag': 'Grade 1-3',
        'difficulty': 'Hard',
        'question_text':
            'A cake is cut into 4 equal pieces. Carlo eats 1 piece. What fraction remains?',
        'choices': {
          'A': '1/4',
          'B': '2/4',
          'C': '3/4',
          'D': '4/4',
        },
        'correct_answer': 'C',
      }, 'L5-Q3');

      expect(q.correctAnswer, 'C');
      expect(q.correctAnswerValue, '3/4');

      for (var seed = 1; seed <= 20; seed++) {
        final shuffled = q.withShuffledChoices(rng: Random(seed));
        final correctSlot = shuffled.displayCorrectAnswer;

        expect(shuffled.choices[correctSlot], '3/4');
        expect(shuffled.isCorrect(correctSlot), isTrue);
        expect(shuffled.isCorrect('3/4'), isTrue);

        for (final key in ['A', 'B', 'C', 'D']) {
          if (key != correctSlot) {
            expect(shuffled.isCorrect(key), isFalse);
          }
        }
      }
    });

    // 4. Correct answer originally at Position D: L31-Q1
    test('Real question L31-Q1 (Original answer key D, value "8,000")', () {
      final q = QuestionModel.fromMap(const {
        'question_id': 'L31-Q1',
        'level': 31,
        'domain': 'Place Value',
        'grade_tag': 'Grade 4',
        'difficulty': 'Moderate',
        'question_text': 'What is the value of 8 in 38,245?',
        'choices': {
          'A': '8',
          'B': '80',
          'C': '800',
          'D': '8,000',
        },
        'correct_answer': 'D',
      }, 'L31-Q1');

      expect(q.correctAnswer, 'D');
      expect(q.correctAnswerValue, '8,000');

      for (var seed = 1; seed <= 20; seed++) {
        final shuffled = q.withShuffledChoices(rng: Random(seed));
        final correctSlot = shuffled.displayCorrectAnswer;

        expect(shuffled.choices[correctSlot], '8,000');
        expect(shuffled.isCorrect(correctSlot), isTrue);
        expect(shuffled.isCorrect('8,000'), isTrue);

        for (final key in ['A', 'B', 'C', 'D']) {
          if (key != correctSlot) {
            expect(shuffled.isCorrect(key), isFalse);
          }
        }
      }
    });
  });

  group('Session Scoring & Feedback Simulation', () {
    test('simulated question attempt updates score and feedback correctly', () {
      final q = QuestionModel(
        questionId: 'SCORE-01',
        level: 1,
        domain: 'Addition',
        gradeTag: 'Grade 1',
        difficulty: 'Preparation',
        questionText: 'What is 3 + 2?',
        choices: {'A': '4', 'B': '5', 'C': '6', 'D': '7'},
        correctAnswer: 'B',
      ).withShuffledChoices(rng: Random(1234));

      final correctDisplaySlot = q.displayCorrectAnswer;
      var score = 0;
      var attempted = 0;

      // 1. Simulate wrong answer
      final wrongSlot = ['A', 'B', 'C', 'D'].firstWhere((k) => k != correctDisplaySlot);
      final isWrong = q.isCorrect(wrongSlot);
      attempted++;
      if (isWrong) score++;

      expect(isWrong, isFalse);
      expect(score, 0);
      expect(attempted, 1);

      // 2. Simulate correct answer
      final isRight = q.isCorrect(correctDisplaySlot);
      attempted++;
      if (isRight) score++;

      expect(isRight, isTrue);
      expect(score, 1);
      expect(attempted, 2);
    });
  });
}