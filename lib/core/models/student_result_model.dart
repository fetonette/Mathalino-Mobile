
/// Represents a single question's result in an assessment or gameplay attempt.
class QuestionResultItem {
  final int itemNumber;
  final String questionId;
  final String? questionText;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int pointsEarned;
  final int maxPoints;
  final String contentDomain;
  final String? cognitiveDomain;
  final String? difficulty;
  final String competencyCode;
  final int? timeSpentSeconds;

  const QuestionResultItem({
    required this.itemNumber,
    required this.questionId,
    this.questionText,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.pointsEarned = 1,
    this.maxPoints = 1,
    required this.contentDomain,
    this.cognitiveDomain,
    this.difficulty,
    required this.competencyCode,
    this.timeSpentSeconds,
  });

  factory QuestionResultItem.fromMap(Map<String, dynamic> map) {
    final correctBool = (map['isCorrect'] ?? map['correct'] ?? false) as bool;
    final points = (map['pointsEarned'] ?? (correctBool ? 1 : 0)) as int;
    final maxPts = (map['maxPoints'] ?? 1) as int;

    return QuestionResultItem(
      itemNumber: (map['itemNumber'] ?? 1) as int,
      questionId: map['questionId']?.toString() ?? '',
      questionText: map['questionText']?.toString(),
      selectedAnswer: map['selectedAnswer']?.toString() ??
          map['studentAnswer']?.toString() ??
          '',
      correctAnswer: map['correctAnswer']?.toString() ?? '',
      isCorrect: correctBool,
      pointsEarned: points,
      maxPoints: maxPts,
      contentDomain: map['contentDomain']?.toString() ??
          map['competencyTag']?.toString() ??
          '',
      cognitiveDomain: map['cognitiveDomain']?.toString(),
      difficulty: map['difficulty']?.toString(),
      competencyCode: map['competencyCode']?.toString() ?? '',
      timeSpentSeconds: (map['timeSpentSeconds'] ?? map['timeSpent']) as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemNumber': itemNumber,
        'questionId': questionId,
        if (questionText != null) 'questionText': questionText,
        'selectedAnswer': selectedAnswer,
        'studentAnswer': selectedAnswer, // Backward-compat alias
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'correct': isCorrect, // Backward-compat alias
        'pointsEarned': pointsEarned,
        'maxPoints': maxPoints,
        'contentDomain': contentDomain,
        if (cognitiveDomain != null) 'cognitiveDomain': cognitiveDomain,
        if (difficulty != null) 'difficulty': difficulty,
        'competencyCode': competencyCode,
        if (timeSpentSeconds != null) 'timeSpentSeconds': timeSpentSeconds,
      };
}

/// Student Result Model representing /student_results/{resultId} documents.
///
/// Designed to support:
/// - Teacher Progress Reports & item-level audit
/// - Parent Progress Reports (domain mastery & simplified metrics)
/// - DepEd RMA Diagnostic Assessment profiling
/// - Math Domain & Cognitive Domain performance analytics
/// - Remediation tracking & level progression
class StudentResult {
  final String resultId;
  final String studentId;
  final String? userId; // Backward-compat alias
  final String? lrn;
  final String? assessmentId;
  final String assessmentType;
  final String? title;
  final int score;
  final int maxScore;
  final double percentage;
  final String completionStatus;
  final int attemptNumber;
  final int? durationSeconds;

  // Level & progression context
  final int? levelNumber;
  final String? zone;
  final String? difficulty;

  // DepEd RMA & Diagnostic metrics
  final String? assignedTier;
  final int? startingLevel;
  final Map<String, dynamic>? rmaProficiency;
  final List<String>? diagnosticFlags;

  // Domain performance rollups (keyed by domain name -> {correct, total, accuracyPct})
  final Map<String, Map<String, dynamic>>? mathDomainPerformance;
  final Map<String, Map<String, dynamic>>? cognitiveDomainPerformance;

  // Normalized item breakdown
  final List<QuestionResultItem>? questionResults;
  final dynamic rawItemBreakdown;

  // Competency mastery & remediation
  final String? competencyCode;
  final List<String>? targetCompetencies;
  final List<String>? competenciesMastered;
  final List<String>? competenciesToDevelop;
  final double? growthPercentage;

  // Gamification & metadata
  final int? xpAwarded;
  final int? coinsAwarded;
  final Map<String, dynamic>? metadata;
  final DateTime? timestamp;
  final DateTime? completedAt;

  const StudentResult({
    required this.resultId,
    required this.studentId,
    this.userId,
    this.lrn,
    this.assessmentId,
    required this.assessmentType,
    this.title,
    required this.score,
    required this.maxScore,
    required this.percentage,
    this.completionStatus = 'completed',
    this.attemptNumber = 1,
    this.durationSeconds,
    this.levelNumber,
    this.zone,
    this.difficulty,
    this.assignedTier,
    this.startingLevel,
    this.rmaProficiency,
    this.diagnosticFlags,
    this.mathDomainPerformance,
    this.cognitiveDomainPerformance,
    this.questionResults,
    dynamic itemBreakdown,
    dynamic rawItemBreakdown,
    this.competencyCode,
    this.targetCompetencies,
    this.competenciesMastered,
    this.competenciesToDevelop,
    this.growthPercentage,
    this.xpAwarded,
    this.coinsAwarded,
    this.metadata,
    this.timestamp,
    this.completedAt,
  }) : rawItemBreakdown = itemBreakdown ?? rawItemBreakdown;

  /// Backward-compatible getter for legacy code reading `itemBreakdown`.
  dynamic get itemBreakdown =>
      rawItemBreakdown ?? questionResults?.map((e) => e.toMap()).toList();


  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return null; }
  }


  factory StudentResult.fromMap(Map<String, dynamic> map, String resultId) {
    final sId =
        map['studentId']?.toString() ?? map['userId']?.toString() ?? '';
    final uId = map['userId']?.toString() ?? sId;
    final sc = (map['score'] ?? map['correctCount'] ?? 0) as int;
    final maxSc = (map['maxScore'] ?? map['totalQuestions'] ?? 0) as int;
    final rawPct = map['percentage'] ??
        (maxSc > 0 ? (sc / maxSc * 100.0) : (map['accuracy'] != null ? (map['accuracy'] as num).toDouble() * 100.0 : 0.0));
    final pct = (rawPct as num).toDouble();

    // Parse questionResults / itemBreakdown
    List<QuestionResultItem>? parsedItems;
    final rawItems = map['questionResults'] ?? map['itemBreakdown'];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map<String, dynamic>>()
          .map((m) => QuestionResultItem.fromMap(m))
          .toList();
    } else if (rawItems is Map) {
      // Post-assessment service historically keyed itemBreakdown by questionId
      final list = <QuestionResultItem>[];
      rawItems.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          list.add(QuestionResultItem.fromMap(v));
        }
      });
      list.sort((a, b) => a.itemNumber.compareTo(b.itemNumber));
      parsedItems = list;
    }

    // Parse domain rollups
    Map<String, Map<String, dynamic>>? mathDomains;
    final rawMathDom = map['mathDomainPerformance'] ?? map['domainPerformances'];
    if (rawMathDom is Map) {
      mathDomains = {};
      rawMathDom.forEach((k, v) {
        if (v is Map) {
          mathDomains![k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    Map<String, Map<String, dynamic>>? cogDomains;
    final rawCogDom = map['cognitiveDomainPerformance'];
    if (rawCogDom is Map) {
      cogDomains = {};
      rawCogDom.forEach((k, v) {
        if (v is Map) {
          cogDomains![k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    final ts = _parseDateTime(map['timestamp'] ?? map['completedAt']);

    return StudentResult(
      resultId: resultId,
      studentId: sId,
      userId: uId,
      lrn: map['lrn']?.toString(),
      assessmentId: map['assessmentId']?.toString(),
      assessmentType: map['assessmentType']?.toString() ?? '',
      title: map['title']?.toString(),
      score: sc,
      maxScore: maxSc,
      percentage: pct,
      completionStatus: map['completionStatus']?.toString() ?? 'completed',
      attemptNumber: (map['attemptNumber'] ?? 1) as int,
      durationSeconds: (map['durationSeconds'] ?? map['timeSpent']) as int?,
      levelNumber: map['levelNumber'] as int?,
      zone: map['zone']?.toString(),
      difficulty: map['difficulty']?.toString(),
      assignedTier: map['assignedTier']?.toString(),
      startingLevel: map['startingLevel'] as int?,
      rmaProficiency: map['rmaProficiency'] is Map<String, dynamic>
          ? map['rmaProficiency'] as Map<String, dynamic>
          : null,
      diagnosticFlags: map['diagnosticFlags'] is List
          ? List<String>.from(map['diagnosticFlags'] as List)
          : null,
      mathDomainPerformance: mathDomains,
      cognitiveDomainPerformance: cogDomains,
      questionResults: parsedItems,
      rawItemBreakdown: map['itemBreakdown'],
      competencyCode: map['competencyCode']?.toString(),
      targetCompetencies: map['targetCompetencies'] is List
          ? List<String>.from(map['targetCompetencies'] as List)
          : null,
      competenciesMastered: map['competenciesMastered'] is List
          ? List<String>.from(map['competenciesMastered'] as List)
          : null,
      competenciesToDevelop: map['competenciesToDevelop'] is List
          ? List<String>.from(map['competenciesToDevelop'] as List)
          : null,
      growthPercentage: (map['growthPercentage'] as num?)?.toDouble(),
      xpAwarded: (map['xpAwarded'] ?? map['xpEarned']) as int?,
      coinsAwarded: (map['coinsAwarded'] ?? map['coinsEarned']) as int?,
      metadata: map['metadata'] is Map<String, dynamic>
          ? map['metadata'] as Map<String, dynamic>
          : null,
      timestamp: ts,
      completedAt: ts,
    );
  }

  /// Alias kept for backward compat; delegates to [fromMap].
  static StudentResult fromFirestoreData(
          Map<String, dynamic> data, String id) =>
      StudentResult.fromMap(data, id);


  Map<String, dynamic> toMap() {
    final itemsList =
        questionResults?.map((e) => e.toMap()).toList() ?? rawItemBreakdown;

    return {
      'studentId': studentId,
      'userId': userId ?? studentId, // Dual-write for backward compatibility
      if (lrn != null) 'lrn': lrn,
      if (assessmentId != null) 'assessmentId': assessmentId,
      'assessmentType': assessmentType,
      if (title != null) 'title': title,
      'score': score,
      'maxScore': maxScore,
      'totalQuestions': maxScore, // Dual-write alias
      'percentage': percentage,
      'accuracy': maxScore > 0 ? score / maxScore : 0.0, // Dashboard support
      'completionStatus': completionStatus,
      'attemptNumber': attemptNumber,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (levelNumber != null) 'levelNumber': levelNumber,
      if (zone != null) 'zone': zone,
      if (difficulty != null) 'difficulty': difficulty,
      if (assignedTier != null) 'assignedTier': assignedTier,
      if (startingLevel != null) 'startingLevel': startingLevel,
      if (rmaProficiency != null) 'rmaProficiency': rmaProficiency,
      if (diagnosticFlags != null) 'diagnosticFlags': diagnosticFlags,
      if (mathDomainPerformance != null) ...{
        'mathDomainPerformance': mathDomainPerformance,
        'domainPerformances': mathDomainPerformance, // Dashboard alias
      },
      if (cognitiveDomainPerformance != null)
        'cognitiveDomainPerformance': cognitiveDomainPerformance,
      if (itemsList != null) ...{
        'questionResults': itemsList,
        'itemBreakdown': itemsList, // Dual-write for backward compatibility
      },
      if (competencyCode != null) 'competencyCode': competencyCode,
      if (targetCompetencies != null) 'targetCompetencies': targetCompetencies,
      if (competenciesMastered != null)
        'competenciesMastered': competenciesMastered,
      if (competenciesToDevelop != null)
        'competenciesToDevelop': competenciesToDevelop,
      if (growthPercentage != null) 'growthPercentage': growthPercentage,
      if (xpAwarded != null) 'xpAwarded': xpAwarded,
      if (coinsAwarded != null) 'coinsAwarded': coinsAwarded,
      if (metadata != null) 'metadata': metadata,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      'completedAt': (completedAt ?? DateTime.now()).toIso8601String(),
    };
  }
}