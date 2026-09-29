
/// Tier constants for the three-tier diagnostic placement system.
///
/// Rule I  : S <  50  → Foundation
/// Rule II : S <= 79  → Intermediate
/// Rule III: S >= 80  → Advanced
abstract class DiagnosticTier {
  static const String foundation = 'Foundation';
  static const String intermediate = 'Intermediate';
  static const String advanced = 'Advanced';
}

/// A single item in the per-question breakdown stored alongside the result.
class DiagnosticItemBreakdown {
  final int itemNumber;
  final String questionId;
  final String? questionText;
  final String competencyCode;
  final String competencyTag; // human-readable, e.g. 'Number Sense'
  final String? contentDomain;
  final String? cognitiveDomain;
  final String? difficulty;
  final bool isCorrect;
  final dynamic studentAnswer;
  final String? correctAnswer;

  const DiagnosticItemBreakdown({
    required this.itemNumber,
    required this.questionId,
    this.questionText,
    required this.competencyCode,
    required this.competencyTag,
    this.contentDomain,
    this.cognitiveDomain,
    this.difficulty,
    required this.isCorrect,
    required this.studentAnswer,
    this.correctAnswer,
  });

  Map<String, dynamic> toMap() => {
        'itemNumber': itemNumber,
        'questionId': questionId,
        if (questionText != null) 'questionText': questionText,
        'competencyCode': competencyCode,
        'competencyTag': competencyTag,
        'contentDomain': contentDomain ?? competencyTag,
        if (cognitiveDomain != null) 'cognitiveDomain': cognitiveDomain,
        if (difficulty != null) 'difficulty': difficulty,
        'isCorrect': isCorrect,
        'correct': isCorrect, // backward-compat alias
        'studentAnswer': studentAnswer?.toString() ?? '',
        'selectedAnswer': studentAnswer?.toString() ?? '', // normalized alias
        if (correctAnswer != null) 'correctAnswer': correctAnswer,
        'pointsEarned': isCorrect ? 1 : 0,
        'maxPoints': 1,
      };
}

/// Computed output of [DiagnosticScoringService.evaluateAndAssignTier].
///
/// Encapsulates the three-tier placement outcome, raw score data, per-competency
/// breakdown, and the "Needs Attention" flags written to Firestore for teachers.
class DiagnosticResult {
  /// Total number of correct answers (0..N).
  final int correctAnswers;

  /// Total number of items in the diagnostic (N). Must be > 0.
  final int totalItems;

  /// Overall percentage score — `(correctAnswers / totalItems) * 100`.
  final double percentage;

  /// Assigned tier: one of [DiagnosticTier.foundation], [DiagnosticTier.intermediate],
  /// or [DiagnosticTier.advanced].
  final String assignedTier;

  /// Per-competency correctness ratio, keyed by the competency *tag* (human-readable
  /// string, e.g. `'Number Sense'`). Value is `correct / total` for that tag (0.0–1.0).
  final Map<String, double> competencyScores;

  /// Competency tags where the per-competency score fell below the "Needs Attention"
  /// threshold (default 50%). Only populated for [DiagnosticTier.foundation] students;
  /// empty list for Intermediate and Advanced. Teacher-visible only.
  final List<String> diagnosticFlags;

  /// Full per-item breakdown for the [/student_results] document.
  final List<DiagnosticItemBreakdown> itemBreakdown;

  /// Timestamp set on successful write.
  final DateTime? diagnosticTimestamp;

  const DiagnosticResult({
    required this.correctAnswers,
    required this.totalItems,
    required this.percentage,
    required this.assignedTier,
    required this.competencyScores,
    required this.diagnosticFlags,
    required this.itemBreakdown,
    this.diagnosticTimestamp,
  });

  /// Accessible content pool list based on assigned tier
  List<String> get contentPool {
    switch (assignedTier) {
      case DiagnosticTier.intermediate:
        return const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6'
        ];
      case DiagnosticTier.advanced:
        return const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6 Advanced'
        ];
      default:
        return const ['Grade 1', 'Grade 2', 'Grade 3'];
    }
  }

  /// Label for content pool
  String get contentPoolLabel {
    switch (assignedTier) {
      case DiagnosticTier.intermediate:
        return 'Grade 1-6 Shuffled';
      case DiagnosticTier.advanced:
        return 'Grade 1-6 Advanced';
      default:
        return 'Grade 1-3';
    }
  }

  /// The starting map node that corresponds to the assigned tier.
  ///
  /// Foundation → Level 1, Intermediate → Level 21, Advanced → Level 41.
  int get startingLevel {
    switch (assignedTier) {
      case DiagnosticTier.intermediate:
        return 21;
      case DiagnosticTier.advanced:
        return 41;
      default:
        return 1;
    }
  }

  /// Convenience: true if the student was flagged for at least one "Needs Attention"
  /// competency (only relevant for Foundation tier).
  bool get hasNeedsAttentionFlags => diagnosticFlags.isNotEmpty;

  /// Math domain performance breakdown for reporting dashboards.
  Map<String, Map<String, dynamic>> get mathDomainPerformance {
    final map = <String, Map<String, dynamic>>{};
    for (final item in itemBreakdown) {
      final domain = item.contentDomain ?? item.competencyTag;
      if (domain.isEmpty) continue;
      final existing = map[domain] ?? {'correct': 0, 'total': 0, 'accuracyPct': 0};
      final newCorrect = (existing['correct'] as int) + (item.isCorrect ? 1 : 0);
      final newTotal = (existing['total'] as int) + 1;
      map[domain] = {
        'correct': newCorrect,
        'total': newTotal,
        'accuracyPct': ((newCorrect / newTotal) * 100).round(),
      };
    }
    return map;
  }

  /// Cognitive domain performance breakdown (Knowing, Applying, Reasoning).
  Map<String, Map<String, dynamic>> get cognitiveDomainPerformance {
    final map = <String, Map<String, dynamic>>{};
    for (final item in itemBreakdown) {
      final cog = item.cognitiveDomain;
      if (cog == null || cog.isEmpty) continue;
      final existing = map[cog] ?? {'correct': 0, 'total': 0, 'accuracyPct': 0};
      final newCorrect = (existing['correct'] as int) + (item.isCorrect ? 1 : 0);
      final newTotal = (existing['total'] as int) + 1;
      map[cog] = {
        'correct': newCorrect,
        'total': newTotal,
        'accuracyPct': ((newCorrect / newTotal) * 100).round(),
      };
    }
    return map;
  }

  /// Serialises the result to a Firestore-compatible map for the
  /// `/student_results/{resultId}` document.
  Map<String, dynamic> toStudentResultMap() {
    final itemsList = itemBreakdown.map((e) => e.toMap()).toList();
    final mathPerf = mathDomainPerformance;
    final cogPerf = cognitiveDomainPerformance;

    return {
      'assessmentType': 'DIAGNOSTIC',
      'title': 'RMA Diagnostic Assessment',
      'score': correctAnswers,
      'maxScore': totalItems,
      'totalQuestions': totalItems, // Dual-write alias
      'percentage': percentage,
      'accuracy': totalItems > 0 ? correctAnswers / totalItems : 0.0,
      'completionStatus': 'completed',
      'attemptNumber': 1,
      'assignedTier': assignedTier,
      'startingLevel': startingLevel,
      'contentPool': contentPoolLabel,
      'competencyScores': competencyScores,
      'diagnosticFlags': diagnosticFlags,
      if (mathPerf.isNotEmpty) ...{
        'mathDomainPerformance': mathPerf,
        'domainPerformances': mathPerf, // Dashboard alias
      },
      if (cogPerf.isNotEmpty) 'cognitiveDomainPerformance': cogPerf,
      'questionResults': itemsList,
      'itemBreakdown': itemsList, // Dual-write alias
      'timestamp': DateTime.now().toIso8601String(),
      'completedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Serialises the fields that get merged into `/users/{userId}`.
  Map<String, dynamic> toUserProfileFields() => {
        'assignedTier': assignedTier,
        'assignedCategory': assignedTier,
        'startingLevel': startingLevel,
        'currentLevel': startingLevel,
        'contentPool': contentPoolLabel,
        'diagnosticScore': correctAnswers,
        'diagnosticPercentage': percentage,
        'diagnosticCompleted': true,
        'diagnosticFlags': diagnosticFlags,
        'diagnosticTimestamp': DateTime.now().toIso8601String(),
        'diagnosticCompletedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  String toString() =>
      'DiagnosticResult(tier: $assignedTier, score: $correctAnswers/$totalItems '
      '(${percentage.toStringAsFixed(1)}%), startingLevel: $startingLevel, flags: $diagnosticFlags)';
}
