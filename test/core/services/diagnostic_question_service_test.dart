import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/services/diagnostic_question_service.dart';

/// Builds a diagnostic-style [Question] with the given [id] and [gradeLevel].
Question _q(String id, {int gradeLevel = 1}) {
  return Question(
    id: id,
    grade: gradeLevel,
    contentDomain: 'Number Sense',
    competencyCode: 'Q-$id',
    competencyText: 'Number Sense',
    cognitiveDomain: 'Knowing',
    type: 'multipleChoice',
    questionText: 'Question $id',
    choices: const ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
    correctAnswer: 'A',
    maxPoints: 1,
  );
}

/// Builds the 40-item bank with ids Q01..Q40 (mirrors the seeded JSON).
List<Question> _buildBank({int count = 40}) {
  return [
    for (var i = 1; i <= count; i++) _q('Q${i.toString().padLeft(2, '0')}'),
  ];
}

void main() {
  const attemptCount = 20;
  final bank = _buildBank();
  final bankIds = bank.map((q) => q.id).toSet();

  group('DiagnosticQuestionService.selectAttemptItems', () {
    test('fresh attempt returns exactly 20 unique questions', () {
      final selected = DiagnosticQuestionService.selectAttemptItems(
        pool: bank,
        usedQuestionsHistory: const {},
        count: attemptCount,
      );

      expect(selected.length, attemptCount);
      expect(selected.map((q) => q.id).toSet().length, attemptCount);
      for (final q in selected) {
        expect(bankIds, contains(q.id));
      }
    });

    test('retake with 10 previously-seen questions still returns 20, '
        'all unseen (unseen pool >= 20)', () {
      const used = {
        'Q01',
        'Q02',
        'Q03',
        'Q04',
        'Q05',
        'Q06',
        'Q07',
        'Q08',
        'Q09',
        'Q10',
      };

      final selected = DiagnosticQuestionService.selectAttemptItems(
        pool: bank,
        usedQuestionsHistory: used,
        count: attemptCount,
      );

      expect(selected.length, attemptCount);
      // 30 unseen remain, so every selected question must be new — no reuse.
      for (final q in selected) {
        expect(used, isNot(contains(q.id)));
      }
    });

    test('retake with 25 previously-seen questions backfills to exactly 20', () {
      final used = {
        for (var i = 1; i <= 25; i++) 'Q${i.toString().padLeft(2, '0')}',
      };

      final selected = DiagnosticQuestionService.selectAttemptItems(
        pool: bank,
        usedQuestionsHistory: used,
        count: attemptCount,
      );

      expect(selected.length, attemptCount);
      // 15 unseen remain → 15 new + 5 backfilled from the previously-used pool.
      final unseenInResult = selected
          .where((q) => !used.contains(q.id))
          .toList();
      final seenInResult = selected.where((q) => used.contains(q.id)).toList();
      expect(unseenInResult.length, 15);
      expect(seenInResult.length, 5);
    });

    test(
      'retake after ALL questions were previously seen still returns 20',
      () {
        final used = bankIds;

        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: bank,
          usedQuestionsHistory: used,
          count: attemptCount,
        );

        expect(selected.length, attemptCount);
        for (final q in selected) {
          expect(used, contains(q.id));
        }
        expect(selected.map((q) => q.id).toSet().length, attemptCount);
      },
    );

    test('never returns duplicates regardless of history size', () {
      for (final usedCount in [0, 5, 10, 20, 30, 40]) {
        final used = {
          for (var i = 1; i <= usedCount; i++)
            'Q${i.toString().padLeft(2, '0')}',
        };
        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: bank,
          usedQuestionsHistory: used,
          count: attemptCount,
        );
        expect(
          selected.length,
          attemptCount,
          reason: 'usedCount=$usedCount must still produce 20 items',
        );
        expect(
          selected.map((q) => q.id).toSet().length,
          attemptCount,
          reason: 'usedCount=$usedCount must produce unique ids',
        );
      }
    });

    group('Grade-based question selection (Grades 1-3)', () {
      /// Realistic 40-item question bank mirroring Supabase/diagnostic_assessment_questions.json
      List<Question> buildRealisticBank() {
        return [
          // Grade 1 (8 items, Easy)
          for (var i = 1; i <= 8; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 1,
              contentDomain: 'Number Sense',
              competencyCode: 'Number Identification',
              competencyText: 'Identify and count numbers 1-10',
              cognitiveDomain: 'Easy',
              type: 'multipleChoice',
              questionText: 'Grade 1 Question Q$i',
              choices: const ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
              correctAnswer: 'A',
              maxPoints: 1,
            ),
          // Grade 2 (8 items: 5 Easy, 3 Medium)
          for (var i = 9; i <= 13; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 2,
              contentDomain: 'Number Sense',
              competencyCode: 'Number & Place Value',
              competencyText: 'Place value tens and ones',
              cognitiveDomain: 'Easy',
              type: 'multipleChoice',
              questionText: 'Grade 2 Easy Question Q$i',
              choices: const ['A. 10', 'B. 20', 'C. 30', 'D. 40'],
              correctAnswer: 'B',
              maxPoints: 1,
            ),
          for (var i = 14; i <= 16; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 2,
              contentDomain: 'Operations',
              competencyCode: 'Multiplication',
              competencyText: 'Repeated addition',
              cognitiveDomain: 'Medium',
              type: 'multipleChoice',
              questionText: 'Grade 2 Medium Question Q$i',
              choices: const ['A. 6', 'B. 8', 'C. 10', 'D. 12'],
              correctAnswer: 'C',
              maxPoints: 1,
            ),
          // Grade 3 (8 items: 1 Easy, 7 Medium)
          Question(
            id: 'Q17',
            grade: 3,
            contentDomain: 'Measurement',
            competencyCode: 'Mass Measurement',
            competencyText: 'Estimate and measure mass',
            cognitiveDomain: 'Easy',
            type: 'multipleChoice',
            questionText: 'Grade 3 Easy Question Q17',
            choices: const ['A. 1kg', 'B. 2kg', 'C. 3kg', 'D. 4kg'],
            correctAnswer: 'A',
            maxPoints: 1,
          ),
          for (var i = 18; i <= 24; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 3,
              contentDomain: 'Operations',
              competencyCode: 'Division',
              competencyText: 'Equal sharing division',
              cognitiveDomain: 'Medium',
              type: 'multipleChoice',
              questionText: 'Grade 3 Medium Question Q$i',
              choices: const ['A. 2', 'B. 3', 'C. 4', 'D. 5'],
              correctAnswer: 'D',
              maxPoints: 1,
            ),
          // Grade 4 (7 items, Medium)
          for (var i = 25; i <= 31; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 4,
              contentDomain: 'Algebra',
              competencyCode: 'Algebraic Representation',
              competencyText: 'Variables and equations',
              cognitiveDomain: 'Medium',
              type: 'multipleChoice',
              questionText: 'Grade 4 Question Q$i',
              choices: const ['A. x', 'B. y', 'C. z', 'D. w'],
              correctAnswer: 'A',
              maxPoints: 1,
            ),
          // Grade 5 (5 items: 1 Medium, 4 Hard)
          for (var i = 32; i <= 36; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 5,
              contentDomain: 'Decimals',
              competencyCode: 'Decimals & Place Value',
              competencyText: 'Decimals to thousandths',
              cognitiveDomain: i == 32 ? 'Medium' : 'Hard',
              type: 'multipleChoice',
              questionText: 'Grade 5 Question Q$i',
              choices: const ['A. 0.1', 'B. 0.01', 'C. 0.001', 'D. 0.0001'],
              correctAnswer: 'C',
              maxPoints: 1,
            ),
          // Grade 6 (4 items, Hard)
          for (var i = 37; i <= 40; i++)
            Question(
              id: 'Q${i.toString().padLeft(2, '0')}',
              grade: 6,
              contentDomain: 'Problem Solving',
              competencyCode: 'Problem Solving',
              competencyText: 'Complex multi-step problems',
              cognitiveDomain: 'Hard',
              type: 'multipleChoice',
              questionText: 'Grade 6 Question Q$i',
              choices: const ['A. 100', 'B. 200', 'C. 300', 'D. 400'],
              correctAnswer: 'B',
              maxPoints: 1,
            ),
        ];
      }

      test('Grade 1 student receives easiest appropriate questions (all Grade 1-3)', () {
        final realisticBank = buildRealisticBank();
        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: realisticBank,
          usedQuestionsHistory: const {},
          gradeLevel: 1,
          count: 20,
        );

        expect(selected.length, 20);
        // Ensure no Grade 4, 5, or 6 questions are given to a Grade 1 student
        for (final q in selected) {
          expect(q.grade, lessThanOrEqualTo(3),
              reason: 'Grade 1 student must not receive grade ${q.grade} question (${q.id})');
        }

        // Verify that all 8 Grade 1 questions are prioritized and included
        final grade1Count = selected.where((q) => q.grade == 1).length;
        expect(grade1Count, 8);

        // Verify that all 8 Grade 2 questions are included
        final grade2Count = selected.where((q) => q.grade == 2).length;
        expect(grade2Count, 8);

        // Remaining 4 questions are from Grade 3 (the easiest available)
        final grade3Count = selected.where((q) => q.grade == 3).length;
        expect(grade3Count, 4);

        // Grade 3 Easy question (Q17) should be prioritized
        expect(selected.any((q) => q.id == 'Q17'), isTrue);

        // Verify no Hard questions are included
        final hardCount = selected.where((q) => q.cognitiveDomain == 'Hard').length;
        expect(hardCount, 0);
      });

      test('Grade 2 student receives easiest appropriate questions (all Grade 1-3)', () {
        final realisticBank = buildRealisticBank();
        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: realisticBank,
          usedQuestionsHistory: const {},
          gradeLevel: 2,
          count: 20,
        );

        expect(selected.length, 20);
        // Ensure no Grade 4, 5, or 6 questions
        for (final q in selected) {
          expect(q.grade, lessThanOrEqualTo(3),
              reason: 'Grade 2 student must not receive grade ${q.grade} question (${q.id})');
        }

        // All 16 Grade 1 & 2 foundational items should be included
        final grade1And2Count = selected.where((q) => q.grade <= 2).length;
        expect(grade1And2Count, 16);

        // 4 Grade 3 questions (including Q17 Easy)
        final grade3Count = selected.where((q) => q.grade == 3).length;
        expect(grade3Count, 4);
        expect(selected.any((q) => q.id == 'Q17'), isTrue);
      });

      test('Grade 3 student receives easiest appropriate questions (all Grade 1-3)', () {
        final realisticBank = buildRealisticBank();
        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: realisticBank,
          usedQuestionsHistory: const {},
          gradeLevel: 3,
          count: 20,
        );

        expect(selected.length, 20);
        for (final q in selected) {
          expect(q.grade, lessThanOrEqualTo(3),
              reason: 'Grade 3 student must not receive grade ${q.grade} question (${q.id})');
        }

        // All 14 Easy questions in the pool must be selected
        final easyCount = selected.where((q) => q.cognitiveDomain == 'Easy').length;
        expect(easyCount, 14);

        // Remaining 6 questions must be Medium
        final mediumCount = selected.where((q) => q.cognitiveDomain == 'Medium').length;
        expect(mediumCount, 6);
      });

      test('Grade 4-6 students retain existing standard selection behavior', () {
        final realisticBank = buildRealisticBank();
        for (final grade in [4, 5, 6]) {
          final selected = DiagnosticQuestionService.selectAttemptItems(
            pool: realisticBank,
            usedQuestionsHistory: const {},
            gradeLevel: grade,
            count: 20,
          );

          expect(selected.length, 20);
          expect(selected.map((q) => q.id).toSet().length, 20);
          // Upper grade students draw across the full pool
          final maxGradeInSelection = selected.map((q) => q.grade).reduce((a, b) => a > b ? a : b);
          expect(maxGradeInSelection, greaterThan(3),
              reason: 'Grade $grade students should have access to standard higher-grade pool items');
        }
      });

      test('All selected questions have valid prompt, choices, and answer key', () {
        final realisticBank = buildRealisticBank();
        for (final grade in [1, 2, 3, 4, 5, 6]) {
          final selected = DiagnosticQuestionService.selectAttemptItems(
            pool: realisticBank,
            usedQuestionsHistory: const {},
            gradeLevel: grade,
            count: 20,
          );

          for (final q in selected) {
            expect(DiagnosticQuestionService.isValidQuestion(q), isTrue);
            expect(q.id.trim(), isNotEmpty);
            expect(q.questionText.trim(), isNotEmpty);
            expect(q.correctAnswer, isNotNull);
            expect(q.choices, isNotNull);
            expect(q.choices!.length, equals(4));
            for (final choice in q.choices!) {
              expect(choice.trim(), isNotEmpty);
            }
          }
        }
      });

      test('Grade 1 retake preserves age-appropriate pool (never leaks to Grade 4-6)', () {
        final realisticBank = buildRealisticBank();
        // First attempt: 20 questions used
        final firstAttempt = DiagnosticQuestionService.selectAttemptItems(
          pool: realisticBank,
          usedQuestionsHistory: const {},
          gradeLevel: 1,
          count: 20,
        );
        final used = firstAttempt.map((q) => q.id).toSet();

        // Second attempt: retake with 20 questions in history
        final secondAttempt = DiagnosticQuestionService.selectAttemptItems(
          pool: realisticBank,
          usedQuestionsHistory: used,
          gradeLevel: 1,
          count: 20,
        );

        expect(secondAttempt.length, 20);
        expect(secondAttempt.map((q) => q.id).toSet().length, 20);

        // Crucial test: retake MUST NOT leak to Grade 4-6
        for (final q in secondAttempt) {
          expect(q.grade, lessThanOrEqualTo(3),
              reason: 'Retake must keep Grade 1 student in Grade 1-3 questions, got grade ${q.grade}');
        }

        // Unseen Grade 3 questions (4 items) are preferred
        final unseenCount = secondAttempt.where((q) => !used.contains(q.id)).length;
        expect(unseenCount, 4);

        // Remaining 16 are safely backfilled from seen Grade 1-3 items
        final seenCount = secondAttempt.where((q) => used.contains(q.id)).length;
        expect(seenCount, 16);
      });

      test('Safe fallback when question bank has fewer than 20 early grade questions', () {
        // Hypothetical small pool: only 10 Grade 1-3 questions, 15 Grade 4-6 questions
        final smallPool = [
          for (var i = 1; i <= 10; i++)
            Question(
              id: 'Early_$i',
              grade: 1,
              contentDomain: 'Number Sense',
              competencyCode: 'Count',
              competencyText: 'Count',
              cognitiveDomain: 'Easy',
              type: 'multipleChoice',
              questionText: 'Early $i',
              choices: const ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
              correctAnswer: 'A',
              maxPoints: 1,
            ),
          for (var i = 11; i <= 25; i++)
            Question(
              id: 'Upper_$i',
              grade: 4,
              contentDomain: 'Algebra',
              competencyCode: 'Algebra',
              competencyText: 'Algebra',
              cognitiveDomain: 'Medium',
              type: 'multipleChoice',
              questionText: 'Upper $i',
              choices: const ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
              correctAnswer: 'A',
              maxPoints: 1,
            ),
        ];

        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: smallPool,
          usedQuestionsHistory: const {},
          gradeLevel: 1,
          count: 20,
        );

        // Always returns exactly 20 questions
        expect(selected.length, 20);
        // Contains all 10 available early questions
        final earlyCount = selected.where((q) => q.grade <= 3).length;
        expect(earlyCount, 10);
        // Backfills 10 from easiest available upper questions
        final upperCount = selected.where((q) => q.grade > 3).length;
        expect(upperCount, 10);
      });

      test('Invalid and corrupt questions are filtered out', () {
        final corruptBank = [
          ...buildRealisticBank(),
          // Question with empty prompt
          const Question(
            id: 'Bad_01',
            grade: 1,
            contentDomain: 'Number Sense',
            competencyCode: 'Count',
            competencyText: 'Count',
            cognitiveDomain: 'Easy',
            type: 'multipleChoice',
            questionText: '   ',
            choices: ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
            correctAnswer: 'A',
          ),
          // Question with null/empty answer
          const Question(
            id: 'Bad_02',
            grade: 1,
            contentDomain: 'Number Sense',
            competencyCode: 'Count',
            competencyText: 'Count',
            cognitiveDomain: 'Easy',
            type: 'multipleChoice',
            questionText: 'What is 1+1?',
            choices: ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
            correctAnswer: '',
          ),
        ];

        final selected = DiagnosticQuestionService.selectAttemptItems(
          pool: corruptBank,
          usedQuestionsHistory: const {},
          gradeLevel: 1,
          count: 20,
        );

        expect(selected.length, 20);
        expect(selected.any((q) => q.id == 'Bad_01'), isFalse);
        expect(selected.any((q) => q.id == 'Bad_02'), isFalse);
      });
    });
  });
}
