import 'package:flutter_test/flutter_test.dart';

import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/core/services/question_bank_service.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';
import 'package:mathalino_student_app/providers/level_provider.dart';
import 'package:mathalino_student_app/widgets/star_rating.dart';

import 'helpers/bank_fixture.dart';

/// Records the arguments the completion screen would persist, without any live
/// Supabase client. Mirrors the offline `_FakeDb extends SupabaseService`
/// pattern used elsewhere in the suite.
class _RecordingSupabase extends SupabaseService {
  _RecordingSupabase() : super();

  Map<String, dynamic>? lastSave;

  @override
  Future<void> recordUsedQuestions({
    required String userId,
    required String lrn,
    required int level,
    required List<String> questionIds,
  }) async {
    // No-op: history writes are irrelevant to these assertions.
  }

  @override
  Future<void> saveLevelCompletion({
    required String userId,
    required String lrn,
    required int level,
    required int nextLevel,
    required bool isGameComplete,
    required List<String> usedQuestions,
    required int score,
    required int maxScore,
    required double accuracyPct,
    required bool isChallenge,
    required String difficulty,
    required String zone,
    String? scoringMode,
    int? attemptNumber,
  }) async {
    lastSave = <String, dynamic>{
      'level': level,
      'score': score,
      'maxScore': maxScore,
      'accuracyPct': accuracyPct,
      'isChallenge': isChallenge,
      'scoringMode': scoringMode,
      'attemptNumber': attemptNumber,
    };
  }
}

class _FakeBankService extends QuestionBankService {
  _FakeBankService(this.bank);
  final List<QuestionModel> bank;
  @override
  Future<List<QuestionModel>> fetchQuestionBank() async => bank;
}

const List<String> _slots = ['A', 'B', 'C', 'D'];
String _correctKey(LevelProvider lp) => lp.currentQuestion!.displayCorrectAnswer;
String _wrongKey(LevelProvider lp) =>
    _slots.firstWhere((k) => k != lp.currentQuestion!.displayCorrectAnswer);

/// Dry-run provider (no DB) for asserting the on-screen getters.
Future<LevelProvider> _startDry(int level) async {
  final lp = LevelProvider(
    questionBank: _FakeBankService(buildBank()),
    dryRun: true,
  );
  await lp.startLevel(
    userId: 'u1',
    lrn: '123456789012',
    level: level,
    usedHistory: const [],
  );
  return lp;
}

/// Live-style provider whose persistence is captured by [_RecordingSupabase].
Future<({LevelProvider lp, _RecordingSupabase db})> _startRecording(
  int level,
) async {
  final db = _RecordingSupabase();
  final lp = LevelProvider(
    questionBank: _FakeBankService(buildBank()),
    supabaseService: db,
  );
  await lp.startLevel(
    userId: 'u1',
    lrn: '123456789012',
    level: level,
    usedHistory: const [],
  );
  return (lp: lp, db: db);
}

/// Non-challenge attempt helper: submit [wrongs] incorrect answers then the
/// correct one so the level completes on attempt (wrongs + 1).
Future<void> _completeAfterWrongAnswers(LevelProvider lp, int wrongs) async {
  final wrong = _wrongKey(lp);
  for (var i = 0; i < wrongs; i++) {
    await lp.submitAnswer(wrong);
  }
  await lp.submitAnswer(_correctKey(lp));
}

void main() {
  group('chanceScoreForAttempts (pure helper)', () {
    const game = GameLogicService();
    test('attempt 1/2/3 map to 3/2/1', () {
      expect(game.chanceScoreForAttempts(1), 3);
      expect(game.chanceScoreForAttempts(2), 2);
      expect(game.chanceScoreForAttempts(3), 1);
    });

    test('result is clamped defensively to 1..3', () {
      expect(game.chanceScoreForAttempts(0), 3);
      expect(game.chanceScoreForAttempts(4), 1);
      expect(game.chanceScoreForAttempts(99), 1);
    });

    test('denominator constant is 3', () {
      expect(GameLogicService.kMaxChances, 3);
    });
  });

  group('chance score maps to the required stars', () {
    test('3/3 -> 3, 2/3 -> 2, 1/3 -> 1 via the shared thresholds', () {
      expect(StarRating.starsForScore(3, 3), 3);
      expect(StarRating.starsForScore(2, 3), 2);
      expect(StarRating.starsForScore(1, 3), 1);
    });

    test('helper score and star agree for every valid attempt', () {
      const game = GameLogicService();
      for (var attempt = 1; attempt <= 3; attempt++) {
        final score = game.chanceScoreForAttempts(attempt);
        expect(StarRating.starsForScore(score, GameLogicService.kMaxChances),
            score);
      }
    });
  });

  group('LevelProvider chance scoring (non-Challenge, dry-run)', () {
    test('correct on first attempt => 3/3', () async {
      final lp = await _startDry(1);
      await _completeAfterWrongAnswers(lp, 0);
      expect(lp.phase, PlayerPhase.levelComplete);
      expect(lp.completedScore, 3);
      expect(lp.completedMax, 3);
    });

    test('correct on second attempt => 2/3', () async {
      final lp = await _startDry(1);
      await _completeAfterWrongAnswers(lp, 1);
      expect(lp.phase, PlayerPhase.levelComplete);
      expect(lp.completedScore, 2);
      expect(lp.completedMax, 3);
    });

    test('correct on third attempt => 1/3', () async {
      final lp = await _startDry(1);
      await _completeAfterWrongAnswers(lp, 2);
      expect(lp.phase, PlayerPhase.levelComplete);
      expect(lp.completedScore, 1);
      expect(lp.completedMax, 3);
    });

    test('three wrong answers => out of hearts, no completion', () async {
      final lp = await _startDry(1);
      final wrong = _wrongKey(lp);
      for (var i = 0; i < 3; i++) {
        await lp.submitAnswer(wrong);
      }
      expect(lp.phase, PlayerPhase.outOfHearts);
      expect(lp.phase, isNot(PlayerPhase.levelComplete));
      expect(lp.score, 0); // no correct answer -> never scored
    });

    test('Try Again resets attempts/score/hearts for a fresh run', () async {
      final lp = await _startDry(1);
      final wrong = _wrongKey(lp);
      for (var i = 0; i < 2; i++) {
        await lp.submitAnswer(wrong); // 2 wrongs, 1 heart left
      }
      expect(lp.attemptedTotal, 2);
      lp.restartLevelForHearts();
      expect(lp.hearts, 3);
      expect(lp.score, 0);
      expect(lp.attemptedTotal, 0);
      expect(lp.phase, PlayerPhase.playing);
      // The fresh run can still earn a perfect 3/3.
      await lp.submitAnswer(_correctKey(lp));
      expect(lp.completedScore, 3);
      expect(lp.completedMax, 3);
    });

    test('applies uniformly across all applicable zone/difficulty variants',
        () async {
      // 1,6,16 Preparation (Zone 1); 21,30 Moderate; 40 Moderate (Multi-Step)
      // (Zone 2); 41,59 Preparation (Zone 3).
      for (final level in [1, 6, 16, 21, 30, 40, 41, 59]) {
        final lp = await _startDry(level);
        expect(lp.isChallengeLevel, isFalse, reason: 'level $level');
        await _completeAfterWrongAnswers(lp, 1); // 2nd attempt
        expect(lp.completedScore, 2, reason: 'level $level');
        expect(lp.completedMax, 3, reason: 'level $level');
      }
    });
  });

  group('Challenge exclusion (levels 5,10,15,20,45,50,55,60)', () {
    test('challenge getters keep raw score/attempted denominator', () async {
      final lp = await _startDry(5); // Hard gate
      expect(lp.isChallengeLevel, isTrue);
      // Enter remediation with one wrong answer (does not complete).
      await lp.submitAnswer(_wrongKey(lp));
      // Attempted is 1 here; chance scoring (fixed 3) must NOT be applied.
      expect(lp.completedMax, isNot(3));
      expect(lp.completedMax, lp.attemptedTotal);
      expect(lp.completedScore, lp.score);
    });
  });

  group('Persisted save arguments (recording SupabaseService)', () {
    test('non-challenge 1st attempt saves 3/3 with CHANCE_OF_3 metadata',
        () async {
      final ctx = await _startRecording(1);
      await _completeAfterWrongAnswers(ctx.lp, 0);
      await Future<void>.delayed(Duration.zero);
      expect(ctx.db.lastSave, isNotNull);
      expect(ctx.db.lastSave!['score'], 3);
      expect(ctx.db.lastSave!['maxScore'], 3);
      expect(ctx.db.lastSave!['accuracyPct'], 100.0);
      expect(ctx.db.lastSave!['isChallenge'], false);
      expect(ctx.db.lastSave!['scoringMode'], 'CHANCE_OF_3');
      expect(ctx.db.lastSave!['attemptNumber'], 1);
    });

    test('non-challenge 2nd attempt saves 2/3 (66.7%) with attempt 2',
        () async {
      final ctx = await _startRecording(1);
      await _completeAfterWrongAnswers(ctx.lp, 1);
      await Future<void>.delayed(Duration.zero);
      expect(ctx.db.lastSave!['score'], 2);
      expect(ctx.db.lastSave!['maxScore'], 3);
      expect(ctx.db.lastSave!['accuracyPct'], 66.7);
      expect(ctx.db.lastSave!['scoringMode'], 'CHANCE_OF_3');
      expect(ctx.db.lastSave!['attemptNumber'], 2);
    });

    test('non-challenge 3rd attempt saves 1/3 (33.3%) with attempt 3',
        () async {
      final ctx = await _startRecording(1);
      await _completeAfterWrongAnswers(ctx.lp, 2);
      await Future<void>.delayed(Duration.zero);
      expect(ctx.db.lastSave!['score'], 1);
      expect(ctx.db.lastSave!['maxScore'], 3);
      expect(ctx.db.lastSave!['accuracyPct'], 33.3);
      expect(ctx.db.lastSave!['scoringMode'], 'CHANCE_OF_3');
      expect(ctx.db.lastSave!['attemptNumber'], 3);
    });

    test('persisted stars equal the displayed chance score', () async {
      final ctx = await _startRecording(1);
      await _completeAfterWrongAnswers(ctx.lp, 1);
      await Future<void>.delayed(Duration.zero);
      final persistedAccuracy = ctx.db.lastSave!['accuracyPct'] as double;
      final persistedStars = StarRating.starsForAccuracy(persistedAccuracy);
      expect(persistedStars, ctx.lp.completedScore);
      expect(persistedStars, StarRating.starsForScore(
            ctx.lp.completedScore, ctx.lp.completedMax,
          ));
    });

    test('out-of-hearts completion never persists', () async {
      final ctx = await _startRecording(1);
      final wrong = _wrongKey(ctx.lp);
      for (var i = 0; i < 3; i++) {
        await ctx.lp.submitAnswer(wrong);
      }
      await Future<void>.delayed(Duration.zero);
      expect(ctx.lp.phase, PlayerPhase.outOfHearts);
      expect(ctx.db.lastSave, isNull);
    });
  });
}
