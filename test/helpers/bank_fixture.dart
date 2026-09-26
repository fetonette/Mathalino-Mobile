import 'package:mathalino_student_app/core/models/question_model.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';

/// Whether [level] is a Zone 2 (Intermediate) level.
bool _isZone2(int level) => level >= 21 && level <= 40;

/// Returns the numeric `challengeGroup` for a question at [level], mirroring
/// `tools/question-bank/mathalino_questions_level*.json`:
///   * Zone 1 (1–20): preparation levels link to their 5/10/15/20 gate.
///   * Zone 2 (21–40): always `null` (Intermediate spec removes its gates).
///   * Zone 3 (41–60): preparation levels link forward to their 45/50/55/60
///     gate, and the gate levels carry their own level.
int? _challengeGroupFor(int level) {
  if (level <= 20) {
    if (level <= 5) return 5;
    if (level <= 10) return 10;
    if (level <= 15) return 15;
    return 20;
  }
  if (_isZone2(level)) return null;
  if (level == 45 || level == 50 || level == 55 || level == 60) return level;
  if (level <= 44) return 45;
  if (level <= 49) return 50;
  if (level <= 54) return 55;
  return 60; // 56–59
}

/// Builds a deterministic 300-question combined bank (5 questions per level,
/// Levels 1–60) that mirrors the validated
/// `tools/question-bank/mathalino_questions_level1-20.json`,
/// `mathalino_questions_level21-40.json`, and
/// `mathalino_questions_level41-60.json` schema triple.
///
/// The `difficulty` tag is derived with [GameLogicService.getDifficulty] so the
/// bank satisfies the "difficulty tags match getDifficulty()" invariant: Zone 1
/// and Zone 3 keep their numeric `challengeGroup`, while every Zone 2 question
/// has a null group (no remediation gates in the Intermediate zone).
List<QuestionModel> buildBank() {
  final game = GameLogicService();
  final bank = <QuestionModel>[];
  for (var level = 1; level <= 60; level++) {
    for (var q = 1; q <= 5; q++) {
      final int? group = _challengeGroupFor(level);
      bank.add(QuestionModel(
        questionId: 'L$level-Q$q',
        level: level,
        domain: 'Domain ${level % 4}',
        gradeTag: level <= 20
            ? 'Grade 1-3'
            : (_isZone2(level) ? 'Grade 1-6' : 'Grade 4-6'),
        difficulty: game.getDifficulty(level),
        questionText: 'Question L$level-Q$q text',
        choices: {
          'A': '1',
          'B': '2',
          'C': '3',
          'D': '4',
        },
        correctAnswer: 'B',
        challengeGroup: group,
      ));
    }
  }
  return bank;
}