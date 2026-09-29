import 'package:flutter/foundation.dart';

import '../errors/diagnostic_exception.dart';
import '../models/diagnostic_result.dart';
import '../models/question.dart';
import 'supabase_service.dart';

/// Threshold below which a per-competency score is flagged as "Needs Attention".
/// Only applied for Foundation-tier students (Rule I). Teacher-visible only.
const double _kNeedsAttentionThreshold = 0.50;

/// Implements the four-step diagnostic tier-assignment algorithm described in
/// the Mathalino Implementation Prompt.
///
/// ### Algorithm summary
/// 1. **Data intake** — receives answers (`R`) and the question list (`K`).
/// 2. **Score calculation** — counts correct answers per item and per competency,
///    computes `S = (correct / N) * 100`.
/// 3. **Ruleset application** — assigns one of three mutually exclusive tiers:
///    - Rule I  : `S < 50`        → Foundation  (Level 1)
///    - Rule II : `50 <= S <= 79` → Intermediate (Level 21)
///    - Rule III: `S >= 80`       → Advanced     (Level 41)
///    Additionally flags competencies with per-score < 50% for Rule I students.
/// 4. **Supabase write** — persists normalized assessment and progress data
///    guarded by an idempotency check.
///
/// Usage:
/// ```dart
/// final service = DiagnosticScoringService();
/// final result = await service.evaluateAndAssignTier(
///   userId: uid,
///   questions: diagnosticQuestions,
///   answers: studentAnswers,
///   isAlreadyCompleted: profile.diagnosticCompleted,
/// );
/// ```
class DiagnosticScoringService {
  final SupabaseService _supabaseService;

  DiagnosticScoringService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService();

  // ── Public API ───────────────────────────────────────────────────────

  /// Evaluates the student's answers, determines their tier, and atomically
  /// persists the result to Supabase.
  ///
  /// **Parameters**
  /// - [userId] — the Supabase Auth UID of the student.
  /// - [questions] — the ordered list of N diagnostic [Question] objects
  ///   (answer key `K`). Must be non-empty.
  /// - [answers] — the student's submitted answers, one entry per question
  ///   in the same order. Must have `answers.length == questions.length`.
  /// - [isAlreadyCompleted] — when `true`, the call is a no-op unless
  ///   [forceReassessment] is also `true`, preventing silent overwrites.
  /// - [forceReassessment] — set to `true` to explicitly re-run the assessment
  ///   even if `diagnosticCompleted` is already `true` in the student's profile.
  ///
  /// **Returns** the computed [DiagnosticResult].
  ///
  /// **Throws** [DiagnosticException] for validation failures or database
  /// errors, with a user-friendly [DiagnosticException.message] and an optional
  /// [DiagnosticException.code].
  Future<DiagnosticResult> evaluateAndAssignTier({
    required String userId,
    required List<Question> questions,
    required List<dynamic> answers,
    bool isAlreadyCompleted = false,
    bool forceReassessment = false,
  }) async {
    // ── Idempotency guard ─────────────────────────────────────────────
    if (isAlreadyCompleted && !forceReassessment) {
      throw DiagnosticException(
        'Diagnostic already completed. Pass forceReassessment: true to override.',
        code: 'DIAGNOSTIC_ALREADY_COMPLETED',
      );
    }

    // ── Step 1: Data Intake / Validation ─────────────────────────────
    final n = questions.length;

    if (n == 0) {
      throw DiagnosticException(
        'Cannot evaluate: question list is empty (N = 0 would cause divide-by-zero).',
        code: 'DIAGNOSTIC_EMPTY_QUESTIONS',
      );
    }

    if (answers.length != n) {
      throw DiagnosticException(
        'Answer count (${answers.length}) does not match question count ($n). '
        'All questions must be answered before submission.',
        code: 'DIAGNOSTIC_ANSWER_COUNT_MISMATCH',
      );
    }

    if (userId.isEmpty) {
      throw DiagnosticException(
        'userId must not be empty.',
        code: 'DIAGNOSTIC_INVALID_USER',
      );
    }

    // ── Step 2: Score Calculation ─────────────────────────────────────
    final scoreData = _calculateScores(questions, answers);
    final correctAnswers = scoreData.correctAnswers;
    final double percentage = (correctAnswers / n) * 100.0;
    final itemBreakdown = scoreData.itemBreakdown;
    final competencyScores = scoreData.competencyScores; // tag → ratio 0.0–1.0

    // ── Step 3: Ruleset Application ───────────────────────────────────
    final assignedTier = _applyRuleset(percentage);
    final diagnosticFlags = _computeFlags(assignedTier, competencyScores);

    final result = DiagnosticResult(
      correctAnswers: correctAnswers,
      totalItems: n,
      percentage: percentage,
      assignedTier: assignedTier,
      competencyScores: competencyScores,
      diagnosticFlags: diagnosticFlags,
      itemBreakdown: itemBreakdown,
    );

    // ── Step 4: Persist to Supabase ────────────────────────────────
    await _persistResult(
      userId: userId,
      questions: questions,
      result: result,
    );

    debugPrint(
      '[DiagnosticScoringService] evaluateAndAssignTier: $result',
    );

    return result;
  }

  // ── Step 2 helpers ───────────────────────────────────────────────────

  /// Scores all N answers and accumulates per-competency counts.
  _ScoreData _calculateScores(List<Question> questions, List<dynamic> answers) {
    var correctAnswers = 0;

    // Competency tag → {correct, total}
    final Map<String, _CompetencyCount> competencyCounts = {};
    final List<DiagnosticItemBreakdown> itemBreakdown = [];

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = answers[i];

      final bool isCorrect = _isAnswerCorrect(question, answer);
      if (isCorrect) correctAnswers++;

      // Accumulate per-competency counts using the contentDomain as the
      // human-readable "competency tag" (e.g. 'Number Sense', 'Operations').
      final tag = question.contentDomain.isNotEmpty
          ? question.contentDomain
          : question.competencyCode;

      competencyCounts.putIfAbsent(tag, () => _CompetencyCount());
      competencyCounts[tag]!.total++;
      if (isCorrect) competencyCounts[tag]!.correct++;

      itemBreakdown.add(DiagnosticItemBreakdown(
        itemNumber: i + 1,
        questionId: question.id,
        questionText: question.questionText,
        competencyCode: question.competencyCode,
        competencyTag: tag,
        contentDomain: question.contentDomain.isNotEmpty ? question.contentDomain : tag,
        cognitiveDomain: question.cognitiveDomain,
        isCorrect: isCorrect,
        studentAnswer: answer,
        correctAnswer: question.correctAnswer?.toString(),
      ));
    }

    // Convert counts to ratios (0.0–1.0).
    final Map<String, double> competencyScores = {
      for (final entry in competencyCounts.entries)
        entry.key: entry.value.total > 0
            ? entry.value.correct / entry.value.total
            : 0.0,
    };

    return _ScoreData(
      correctAnswers: correctAnswers,
      competencyScores: competencyScores,
      itemBreakdown: itemBreakdown,
    );
  }

  /// Returns true if the student's [answer] is correct for [question].
  ///
  /// Supports String and `List<String>` correctAnswer with case-insensitive,
  /// whitespace-trimmed comparison.
  bool _isAnswerCorrect(Question question, dynamic answer) {
    if (answer == null) return false;

    final String studentStr = answer.toString().trim().toLowerCase();
    if (studentStr.isEmpty) return false;

    final dynamic correct = question.correctAnswer;

    final List<String> accepted = correct is List
        ? correct.map((e) => e.toString().trim().toLowerCase()).toList()
        : [correct.toString().trim().toLowerCase()];

    for (final acc in accepted) {
      if (studentStr == acc) return true;

      // Choice-letter prefix match (e.g. 'a' vs 'a. option text')
      if (_matchesLetterPrefix(studentStr, acc)) return true;

      // Numeric equality with tolerance (for numericInput / computation)
      final sNum = num.tryParse(studentStr);
      final aNum = num.tryParse(acc);
      if (sNum != null && aNum != null && (sNum - aNum).abs() < 0.0001) {
        return true;
      }
    }

    return false;
  }

  bool _matchesLetterPrefix(String a, String b) {
    final rePrefix = RegExp(r'^([a-d])[\.\s]*');
    final mA = rePrefix.firstMatch(a);
    final mB = rePrefix.firstMatch(b);
    if (mA != null && mB != null) return mA.group(1) == mB.group(1);
    if (a.length == 1 && RegExp(r'^[a-d]$').hasMatch(a)) {
      return b.startsWith('$a.') || b.startsWith('$a ');
    }
    if (b.length == 1 && RegExp(r'^[a-d]$').hasMatch(b)) {
      return a.startsWith('$b.') || a.startsWith('$b ');
    }
    return false;
  }

  // ── Step 3 helpers ───────────────────────────────────────────────────

  /// Applies the three mutually exclusive, ordered rules to [S].
  ///
  /// Score boundaries are **inclusive** as specified:
  /// - Rule I  : S <  50.0        → Foundation  (Level 1)
  /// - Rule II : 50.0 <= S < 80.0 → Intermediate (Level 21)
  /// - Rule III: S >= 80.0        → Advanced     (Level 41)
  String _applyRuleset(double s) {
    if (s < 50.0) return DiagnosticTier.foundation;
    if (s < 80.0) return DiagnosticTier.intermediate;
    return DiagnosticTier.advanced;
  }

  /// Computes the "Needs Attention" flags for Rule I (Foundation) students.
  ///
  /// For each competency tag where `correct/total < 50%`, the tag is added
  /// to the flags list. Returns an empty list for Intermediate and Advanced.
  List<String> _computeFlags(
    String tier,
    Map<String, double> competencyScores,
  ) {
    if (tier != DiagnosticTier.foundation) return const [];

    return [
      for (final entry in competencyScores.entries)
        if (entry.value < _kNeedsAttentionThreshold) entry.key,
    ];
  }

  // ── Step 4 helpers ───────────────────────────────────────────────────

  /// Persists diagnostic placement and assessment records to Supabase:
  /// - Updates `student_progress` and `student_assessments`.
  /// - Creates a new row in `student_results` with full breakdown.
  Future<void> _persistResult({
    required String userId,
    required List<Question> questions,
    required DiagnosticResult result,
  }) async {
    try {
      final questionIds = questions.map((q) => q.id).toList();

      await _supabaseService.saveDiagnosticPlacement(
        userId: userId,
        lrn: '',
        category: result.assignedTier,
        startingLevel: result.startingLevel,
        contentPool: result.contentPoolLabel,
        score: result.correctAnswers,
        percentage: result.percentage,
        usedQuestions: questionIds,
        diagnosticResult: result,
      );

      debugPrint('[DiagnosticScoringService] _persistResult: writes complete for $userId');
    } catch (e, st) {
      debugPrint('[DiagnosticScoringService] _persistResult error: $e\n$st');
      throw DiagnosticException(
        'Failed to save diagnostic result. Please try again.',
        originalError: e,
      );
    }
  }
}

/// Private data carrier returned by [_calculateScores].
class _ScoreData {
  final int correctAnswers;
  final Map<String, double> competencyScores;
  final List<DiagnosticItemBreakdown> itemBreakdown;

  _ScoreData({
    required this.correctAnswers,
    required this.competencyScores,
    required this.itemBreakdown,
  });
}

/// Mutable accumulator for per-competency correct/total counts.
class _CompetencyCount {
  int correct = 0;
  int total = 0;
}
