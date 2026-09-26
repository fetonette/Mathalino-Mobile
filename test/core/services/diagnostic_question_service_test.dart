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
  });
}
