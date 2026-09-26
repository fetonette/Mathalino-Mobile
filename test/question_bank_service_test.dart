import 'package:flutter_test/flutter_test.dart';

import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/core/services/question_bank_service.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';

/// Regression coverage for the "No available question" bug in the Advanced
/// Zone (Levels 41–60).
///
/// Root cause: `QuestionBankService.fetchQuestionBank` used to return only
/// whatever Firestore had. When Firestore's `question_bank` collection was
/// empty, unreachable, or only partially uploaded (e.g. Zones 1–2 but not
/// Zone 3), the in-memory bank had no entries for Levels 41–60, so
/// `GameLogicService.selectQuestion(level: 41..60)` returned `null` and the
/// game surfaced "No available question".
///
/// Fix: `fetchQuestionBank` now always **composites** the authoritative
/// Firestore bank with the bundled local assets (which contain all 300
/// questions, Levels 1–60) so every zone is always present. These tests
/// exercise that behaviour through the real service/provider path. In a unit
/// test there is no initialised Firebase app, so the Firestore read throws and
/// the service falls back to the bundled assets — reproducing both the
/// "Firestore unavailable" and "Firestore partially populated" cases.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuestionBankService — cross-zone availability', () {
    test('composites the full 300-question bank (all three zones)', () async {
      final service = QuestionBankService();
      final bank = await service.fetchQuestionBank();

      expect(bank.length, 300, reason: 'Expected all 100 questions per zone × 3');
      expect(bank.map((q) => q.questionId).toSet().length, 300,
          reason: 'Every question_id must be unique after compositing');
    });

    test('every level 1–60 has exactly 5 questions', () async {
      final service = QuestionBankService();
      final bank = await service.fetchQuestionBank();

      for (var level = 1; level <= 60; level++) {
        final count = bank.where((q) => q.level == level).length;
        expect(count, 5, reason: 'Level $level should have exactly 5 questions');
      }
    });

    test('levels 41, 45, 50, 55 and 60 are all selectable (no empty pools)',
        () async {
      final service = QuestionBankService();
      final bank = await service.fetchQuestionBank();
      final game = GameLogicService();

      for (final level in [41, 45, 50, 55, 60]) {
        final pool = bank.where((q) => q.level == level).toList();
        expect(pool.length, 5, reason: 'Level $level pool should have 5 questions');

        final q = game.selectQuestion(
          bank,
          level: level,
          usedQuestionsHistory: const [],
        );
        expect(q, isNotNull, reason: 'Level $level must have an available question');
        expect(q!.level, level);
      }
    });
  });

  group('LevelProvider startLevel — Zone 3 (Levels 41–60)', () {
    for (final level in [41, 45, 50, 55, 60]) {
      test('startLevel($level) reaches the playing phase with a question',
          () async {
        // dryRun avoids any profile writes; the default QuestionBankService
        // inside the provider loads the full bank via the bundled assets.
        final provider = LevelProvider(dryRun: true);
        await provider.startLevel(
          userId: 'u1',
          level: level,
          usedHistory: const [],
        );

        expect(provider.phase, PlayerPhase.playing,
            reason: 'Level $level should load, not go to levelFailed');
        expect(provider.currentQuestion, isNotNull);
        expect(provider.currentQuestion!.level, level);
      });
    }
  });
}