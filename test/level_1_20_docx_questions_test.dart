import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/core/services/question_bank_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mathalino Levels 1–20 Docx Questions Integration QA', () {
    late List<QuestionModel> bank;
    final gameLogic = const GameLogicService();

    setUpAll(() async {
      final service = QuestionBankService();
      bank = await service.fetchQuestionBank();
    });

    test('Total bank size is exactly 300 questions across Levels 1–60', () {
      expect(bank.length, 300);
      expect(bank.map((q) => q.questionId).toSet().length, 300);
    });

    test('Levels 1–20 have exactly 100 questions with 5 questions per level', () {
      final zone1 = bank.where((q) => q.level >= 1 && q.level <= 20).toList();
      expect(zone1.length, 100);

      for (var lvl = 1; lvl <= 20; lvl++) {
        final levelQuestions = zone1.where((q) => q.level == lvl).toList();
        expect(levelQuestions.length, 5,
            reason: 'Level $lvl must contain exactly 5 questions');

        final expectedIds = List.generate(5, (i) => 'L$lvl-Q${i + 1}');
        final actualIds = levelQuestions.map((q) => q.questionId).toList();
        expect(actualIds, containsAll(expectedIds));
      }
    });

    test('Every question has non-empty question text and valid choices A, B, C, D', () {
      final zone1 = bank.where((q) => q.level >= 1 && q.level <= 20).toList();
      for (final q in zone1) {
        expect(q.questionText.trim().isNotEmpty, isTrue,
            reason: '${q.questionId} has empty question text');
        expect(q.choices.keys.toSet(), {'A', 'B', 'C', 'D'},
            reason: '${q.questionId} does not have choices A, B, C, D');
        for (final entry in q.choices.entries) {
          expect(entry.value.trim().isNotEmpty, isTrue,
              reason: '${q.questionId} choice ${entry.key} is empty');
        }
      }
    });

    test('Every question has a valid correct answer matching choices', () {
      final zone1 = bank.where((q) => q.level >= 1 && q.level <= 20).toList();
      for (final q in zone1) {
        expect(['A', 'B', 'C', 'D'], contains(q.correctAnswer),
            reason: '${q.questionId} correct answer is not A, B, C, or D');
        expect(q.choices.containsKey(q.correctAnswer), isTrue,
            reason: '${q.questionId} correct answer ${q.correctAnswer} is not in choices');
        expect(q.isCorrect(q.correctAnswer), isTrue);
        expect(q.isCorrect(q.choices[q.correctAnswer]), isTrue);
      }
    });

    test('Difficulty and challenge_group follow curriculum rules', () {
      for (var lvl = 1; lvl <= 20; lvl++) {
        final questions = bank.where((q) => q.level == lvl).toList();
        final expectedDiff = gameLogic.getDifficulty(lvl);
        final expectedCg = (lvl <= 5)
            ? 5
            : (lvl <= 10)
                ? 10
                : (lvl <= 15)
                    ? 15
                    : 20;

        for (final q in questions) {
          expect(q.difficulty, expectedDiff,
              reason: '${q.questionId} difficulty mismatch');
          expect(q.challengeGroup, expectedCg,
              reason: '${q.questionId} challenge_group mismatch');
          expect(q.gradeTag, 'Grade 1-3');
        }
      }
    });

    test('All referenced image assets exist on disk', () {
      final zone1 = bank.where((q) => q.level >= 1 && q.level <= 20).toList();
      var withImageCount = 0;

      for (final q in zone1) {
        if (q.imagePath != null && q.imagePath!.isNotEmpty) {
          withImageCount++;
          final file = File(q.imagePath!);
          expect(file.existsSync(), isTrue,
              reason: 'Asset image does not exist: ${q.imagePath} for ${q.questionId}');
        }
      }

      expect(withImageCount, 62,
          reason: 'Expected 62 visual questions to have associated image assets');
    });

    test('GameLogicService can select questions for all levels 1–20 without null', () {
      for (var lvl = 1; lvl <= 20; lvl++) {
        final q = gameLogic.selectQuestion(
          bank,
          level: lvl,
          usedQuestionsHistory: const [],
        );
        expect(q, isNotNull, reason: 'Level $lvl failed to select a question');
        expect(q!.level, lvl);
      }
    });

    test('Choice shuffling preserves correct answer identification', () {
      final zone1 = bank.where((q) => q.level >= 1 && q.level <= 20).toList();
      for (final q in zone1) {
        final shuffled = q.withShuffledChoices();
        expect(shuffled.isCorrect(shuffled.displayCorrectAnswer), isTrue);
        expect(shuffled.isCorrect(q.correctAnswerValue), isTrue);
      }
    });

    test('Levels 21–60 remain completely unaffected', () {
      for (var lvl = 21; lvl <= 60; lvl++) {
        final count = bank.where((q) => q.level == lvl).length;
        expect(count, 5,
            reason: 'Level $lvl (Zone 2 or 3) must still have 5 questions');
      }
    });
  });
}
