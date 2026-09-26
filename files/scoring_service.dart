/// lib/core/services/scoring_service.dart
///
/// Grades StudentAnswers against QuestionModels, and applies the diagnostic
/// percentage/category rules exactly as specified in
/// Mathalino_Rule_Based_Game_Logic_Updated.docx (section 3 / pseudocode §10).

import '../../models/question_model.dart';
import '../../models/assessment_models.dart';

class ScoringService {
  /// Grades a single answer against its question definition.
  GradingResult gradeAnswer({
    required QuestionModel question,
    required StudentAnswer answer,
  }) {
    final isCorrect = _isCorrect(question, answer.rawResponse);
    return GradingResult(
      questionId: question.id,
      competencyCode: question.competencyCode,
      isCorrect: isCorrect,
      pointsAwarded: isCorrect ? question.points : 0,
      pointsPossible: question.points,
      studentAnswer: answer.rawResponse,
      correctAnswerShown: question.acceptableAnswers,
    );
  }

  /// Grades a full attempt (diagnostic, level, or remediation) and returns
  /// the aggregated results.
  List<GradingResult> gradeAttempt({
    required List<QuestionModel> questions,
    required List<StudentAnswer> answers,
  }) {
    final byId = {for (final q in questions) q.id: q};
    return answers
        .where((a) => byId.containsKey(a.questionId))
        .map((a) => gradeAnswer(question: byId[a.questionId]!, answer: a))
        .toList();
  }

  int totalScore(List<GradingResult> results) =>
      results.fold(0, (sum, r) => sum + r.pointsAwarded);

  int totalPossible(List<GradingResult> results) =>
      results.fold(0, (sum, r) => sum + r.pointsPossible);

  /// Percentage = (Correct Answers / Total) * 100
  /// (Game Logic doc §2 — applies to the 20-item Mathalino diagnostic; also
  /// reusable for any fixed-length quiz such as a single RMA task.)
  double percentage(int correctItems, int totalItems) =>
      totalItems == 0 ? 0 : (correctItems / totalItems) * 100;

  /// Diagnostic placement rule — verbatim from Game Logic doc §3 / §10:
  ///   < 50%          -> Beginner       -> Level 1  (Grade 1-3)
  ///   50% to <75%    -> Intermediate   -> Level 21 (Grade 1-6 shuffled)
  ///   75% to <100%   -> Advanced       -> Level 41 (Grade 1-6 advanced)
  ///   = 100%         -> Mastery        -> Level 41 (Grade 1-6 advanced/full)
  StudentCategory categorize(double pct) {
    if (pct >= 100) return StudentCategory.mastery;
    if (pct >= 75) return StudentCategory.advanced;
    if (pct >= 50) return StudentCategory.intermediate;
    return StudentCategory.beginner;
  }

  int startingLevelFor(StudentCategory category) {
    switch (category) {
      case StudentCategory.beginner:
        return 1;
      case StudentCategory.intermediate:
        return 21;
      case StudentCategory.advanced:
      case StudentCategory.mastery:
        return 41;
    }
  }

  // ---------------------------------------------------------------------
  // Answer comparison, per QuestionType.
  // ---------------------------------------------------------------------
  bool _isCorrect(QuestionModel q, dynamic rawResponse) {
    switch (q.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        final selectedId = rawResponse?.toString().trim();
        return q.acceptableAnswers
            .map((a) => a.trim().toLowerCase())
            .contains(selectedId?.toLowerCase());

      case QuestionType.numericInput:
        final submitted = num.tryParse(rawResponse?.toString().trim() ?? '');
        if (submitted == null) return false;
        return q.acceptableAnswers.any((a) {
          final expected = num.tryParse(a);
          return expected != null && expected == submitted;
        });

      case QuestionType.textInput:
      case QuestionType.wordProblem:
        final normalized = _normalize(rawResponse?.toString() ?? '');
        return q.acceptableAnswers
            .map(_normalize)
            .contains(normalized);

      case QuestionType.ordering:
      case QuestionType.patternCompletion:
        final submittedList = (rawResponse is List)
            ? rawResponse.map((e) => _normalize(e.toString())).toList()
            : [_normalize(rawResponse?.toString() ?? '')];
        return q.acceptableAnswers.any((a) {
          final expectedList =
              a.split(',').map((e) => _normalize(e)).toList();
          return _listEquals(expectedList, submittedList);
        });

      case QuestionType.trace:
      case QuestionType.draw:
      case QuestionType.manipulative:
      case QuestionType.oral:
        // Not digitally auto-gradable; excluded from selection pool via
        // isDigitallyPlayable == false. Defensive fallback: never award.
        return false;
    }
  }

  String _normalize(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[₱\s]+'), input.contains(',') ? ',' : ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
