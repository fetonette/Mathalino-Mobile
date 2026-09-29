import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../constants/game_rules.dart';
import '../models/question.dart';
import '../models/student_result_model.dart';
import 'question_selector_service.dart';
import 'scoring_service.dart';

/// Represents the current state of an active remediation session.
class RemediationState {
  final bool active;
  final int targetLevel;
  final int preparationStart;
  final int preparationEnd;
  final String? failedQuestionId;
  final String? competencyCode;
  final int attemptsInRange;
  final double masteryScore;

  /// Ordered list (oldest → newest) of correctness flags for the most recent
  /// preparation answers. Used to compute the running mastery as a sliding
  /// window of size [kMasteryWindowSize]. Only the last [kMasteryWindowSize]
  /// entries are persisted.
  final List<bool> recentAnswerCorrectness;

  /// Number of remediation repeat cycles attempted for this target level.
  /// Starts at 1. Incremented on each repeat failure.
  final int cycleCount;

  /// Whether the student has reached the maximum allowed remediation cycles
  /// without passing, requiring teacher intervention.
  final bool needsTeacherSupport;

  /// Reason for needing teacher support, if applicable.
  final String? supportReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RemediationState({
    required this.active,
    required this.targetLevel,
    required this.preparationStart,
    required this.preparationEnd,
    this.failedQuestionId,
    this.competencyCode,
    this.attemptsInRange = 0,
    this.masteryScore = 0.0,
    this.recentAnswerCorrectness = const [],
    this.cycleCount = 1,
    this.needsTeacherSupport = false,
    this.supportReason,
    this.createdAt,
    this.updatedAt,
  });

  factory RemediationState.inactive() {
    return const RemediationState(
      active: false,
      targetLevel: 0,
      preparationStart: 0,
      preparationEnd: 0,
      cycleCount: 0,
      needsTeacherSupport: false,
    );
  }

  /// Builds a [RemediationState] from a Firestore `remediation` map.
  factory RemediationState.fromMap(Map<String, dynamic>? map) {
    if (map == null || map['active'] != true) {
      return RemediationState.inactive();
    }

    final range = map['preparationRange'];
    int start = 1;
    int end = 1;
    if (range is List && range.length >= 2) {
      start = (range[0] as num).toInt();
      end = (range[1] as num).toInt();
    }

    final recent = map['recentAnswerCorrectness'];
    final recentCorrectness = <bool>[];
    if (recent is List) {
      recentCorrectness.addAll(recent.map((e) => e == true));
    }

    final createdAtRaw = map['createdAt'];
    final updatedAtRaw = map['updatedAt'];

    return RemediationState(
      active: map['active'] == true,
      targetLevel: (map['targetLevel'] ?? 0) as int,
      preparationStart: start,
      preparationEnd: end,
      failedQuestionId: map['failedQuestionId']?.toString(),
      competencyCode: map['competencyCode']?.toString(),
      attemptsInRange: (map['attemptsInRange'] ?? 0) as int,
      masteryScore: (map['masteryScore'] ?? 0.0) as double,
      recentAnswerCorrectness: recentCorrectness,
      cycleCount: (map['cycleCount'] ?? 1) as int,
      needsTeacherSupport: map['needsTeacherSupport'] == true,
      supportReason: map['supportReason']?.toString(),
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
      updatedAt: updatedAtRaw is String ? DateTime.tryParse(updatedAtRaw) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'active': active,
      'targetLevel': targetLevel,
      'preparationRange': [preparationStart, preparationEnd],
      'failedQuestionId': failedQuestionId,
      'competencyCode': competencyCode,
      'attemptsInRange': attemptsInRange,
      'masteryScore': masteryScore,
      'recentAnswerCorrectness': recentAnswerCorrectness,
      'cycleCount': cycleCount,
      'needsTeacherSupport': needsTeacherSupport,
      if (supportReason != null) 'supportReason': supportReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  RemediationState copyWith({
    bool? active,
    int? targetLevel,
    int? preparationStart,
    int? preparationEnd,
    String? failedQuestionId,
    String? competencyCode,
    int? attemptsInRange,
    double? masteryScore,
    List<bool>? recentAnswerCorrectness,
    int? cycleCount,
    bool? needsTeacherSupport,
    String? supportReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RemediationState(
      active: active ?? this.active,
      targetLevel: targetLevel ?? this.targetLevel,
      preparationStart: preparationStart ?? this.preparationStart,
      preparationEnd: preparationEnd ?? this.preparationEnd,
      failedQuestionId: failedQuestionId ?? this.failedQuestionId,
      competencyCode: competencyCode ?? this.competencyCode,
      attemptsInRange: attemptsInRange ?? this.attemptsInRange,
      masteryScore: masteryScore ?? this.masteryScore,
      recentAnswerCorrectness:
          recentAnswerCorrectness ?? this.recentAnswerCorrectness,
      cycleCount: cycleCount ?? this.cycleCount,
      needsTeacherSupport: needsTeacherSupport ?? this.needsTeacherSupport,
      supportReason: supportReason ?? this.supportReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Failure & Remediation Engine for Mathalino Student App.
///
/// Implements the full remediation flow:
/// 1. On Hard/Boss level failure, determines the preparation range and
///    writes a `remediation` object to the student's Firestore profile.
/// 2. While active, delegates question selection to [QuestionSelectorService],
///    filtered to the failed question's competency code and excluding
///    `usedQuestionsHistory`.
/// 3. Tracks a running mastery percentage across remediation attempts,
///    comparing against [kMasteryThreshold].
/// 4. Once the threshold is met, selects a NEW question for the target level
///    (excluding the previously failed question ID) and presents it.
/// 5. On success, clears the remediation object and unlocks `targetLevel + 1`.
class RemediationService {
  final QuestionSelectorService _questionSelector;
  final ScoringService _scoringService;

  RemediationService({
    QuestionSelectorService? questionSelector,
    ScoringService? scoringService,
  })  : _questionSelector = questionSelector ?? QuestionSelectorService(),
        _scoringService = scoringService ?? ScoringService();

  /// Lazily resolves SupabaseClient or returns null if not initialized.
  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Starts a remediation session after a Hard/Boss level failure.
  ///
  /// [userId] - The authenticated student's UID.
  /// [failedLevel] - The Hard/Boss level that was failed.
  /// [failedQuestion] - The question the student failed on (used to derive
  ///   the competency code for remediation filtering).
  /// [contentPool] - The student's assigned content pool (competency codes).
  /// [usedQuestionsHistory] - Question IDs already answered by the student.
  ///
  /// Returns the newly-created [RemediationState].
  Future<RemediationState> startRemediation({
    required String userId,
    required int failedLevel,
    required Question failedQuestion,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
  }) async {
    // 1. Determine the preparation range from the failed level.
    final range = getPreparationRangeForLevel(failedLevel);
    final now = DateTime.now();

    final remediation = RemediationState(
      active: true,
      targetLevel: failedLevel,
      preparationStart: range[0],
      preparationEnd: range[1],
      failedQuestionId: failedQuestion.id,
      competencyCode: failedQuestion.competencyCode,
      attemptsInRange: 0,
      masteryScore: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    // 2. Write the remediation object to the student's Supabase progress.
    final db = _db;
    if (db != null) {
      await db.from('student_progress').update({
        'remediation': remediation.toMap(),
        'remediation_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', userId);
    }

    debugPrint('[RemediationService] Started remediation for level $failedLevel '
        'prep range ${range[0]}-${range[1]} competency ${failedQuestion.competencyCode}');

    return remediation;
  }

  /// Loads the current remediation state for a student from `student_progress`.
  Future<RemediationState> getRemediationState(String userId) async {
    final db = _db;
    if (db == null) return RemediationState.inactive();
    try {
      final row = await db
          .from('student_progress')
          .select('remediation')
          .eq('uid', userId)
          .maybeSingle();
      return RemediationState.fromMap(
        row?['remediation'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('[RemediationService] getRemediationState error: $e');
      return RemediationState.inactive();
    }
  }

  /// Fetches a batch of preparation questions for the active remediation.
  ///
  /// Delegates to [QuestionSelectorService], filtered to the failed question's
  /// competency code and excluding the student's `usedQuestionsHistory`.
  /// The grade band is derived from the middle of the preparation range.
  Future<List<Question>> getPreparationQuestions({
    required String userId,
    required RemediationState remediation,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
    int limit = kRemediationPrepQuestionCount,
  }) async {
    if (!remediation.active) return [];

    // Derive the grade band from the middle of the preparation range so that
    // the selected questions stay within [preparationStart, preparationEnd].
    final prepLevel = remediation.preparationStart +
        ((remediation.preparationEnd - remediation.preparationStart) ~/ 2);
    final safePrepLevel = prepLevel.clamp(1, 60);

    final questions = await _questionSelector.selectQuestions(
      level: Level(difficulty: 'preparation', levelNumber: safePrepLevel),
      contentPool: contentPool,
      usedQuestionsHistory: usedQuestionsHistory,
      zone: _getZoneForLevel(safePrepLevel),
      competencyCode: remediation.competencyCode,
      limit: limit,
    );

    return questions;
  }

  /// Records a preparation answer and updates the running mastery score.
  ///
  /// [question] - The preparation question that was answered.
  /// [selectedAnswer] - The student's raw answer.
  /// [remediation] - The current remediation state (before this answer).
  ///
  /// Returns the updated [RemediationState] with new `attemptsInRange`,
  /// `masteryScore`, and the sliding-window correctness history. The caller
  /// is responsible for persisting via [updateRemediationState].
  RemediationState recordPreparationAnswer({
    required Question question,
    required dynamic selectedAnswer,
    required RemediationState remediation,
  }) {
    final pointsEarned = _scoringService.scoreQuestion(question, selectedAnswer);
    final isCorrect = pointsEarned > 0;

    // Append to the sliding window and trim to the most recent
    // kMasteryWindowSize answers.
    final window = <bool>[...remediation.recentAnswerCorrectness, isCorrect];
    if (window.length > kMasteryWindowSize) {
      window.removeRange(0, window.length - kMasteryWindowSize);
    }

    // Running mastery is the fraction correct within the current window.
    final newMastery = window.isEmpty
        ? 0.0
        : window.where((correct) => correct).length / window.length;

    return remediation.copyWith(
      attemptsInRange: remediation.attemptsInRange + 1,
      masteryScore: newMastery,
      recentAnswerCorrectness: window,
      updatedAt: DateTime.now(),
    );
  }

  /// Determines whether the student has achieved mastery and is ready for
  /// the challenge (retry) question.
  ///
  /// Mastery requires at least [kMinPrepAttempts] preparation answers and a
  /// running mastery percentage (within the sliding window of
  /// [kMasteryWindowSize] most-recent answers) at or above [kMasteryThreshold].
  bool hasAchievedMastery(RemediationState remediation) {
    if (remediation.attemptsInRange < kMinPrepAttempts) return false;
    return remediation.masteryScore >= kMasteryThreshold;
  }

  /// Determines whether the remediation has exceeded the max attempts and
  /// should loop back (repeat failure).
  bool hasExceededMaxAttempts(RemediationState remediation) {
    return remediation.attemptsInRange >= kMaxPrepAttempts;
  }

  /// Fetches a NEW challenge question for the target level.
  ///
  /// Excludes the previously failed question ID and the student's
  /// `usedQuestionsHistory`.
  Future<Question?> getChallengeQuestion({
    required String userId,
    required RemediationState remediation,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
  }) async {
    if (!remediation.active) return null;

    // Exclude the previously failed question ID explicitly (not just as part
    // of usedQuestionsHistory), so a brand-new challenge question is selected.
    final failedId = remediation.failedQuestionId;

    final questions = await _questionSelector.selectQuestions(
      level: Level(difficulty: 'challenge', levelNumber: remediation.targetLevel),
      contentPool: contentPool,
      usedQuestionsHistory: usedQuestionsHistory,
      zone: _getZoneForLevel(remediation.targetLevel),
      excludeQuestionIds: failedId == null ? null : [failedId],
      limit: kRemediationChallengeQuestionCount,
    );

    if (questions.isEmpty) return null;
    return questions.first;
  }

  /// Completes the remediation successfully.
  ///
  /// Clears the `remediation` object from the student's Firestore profile and
  /// unlocks `targetLevel + 1` by updating `levelStatus`. Also clears any
  /// `needsTeacherSupport` flags if active.
  Future<void> completeRemediation({
    required String userId,
    required RemediationState remediation,
  }) async {
    final targetLevel = remediation.targetLevel;
    final nextLevel = (targetLevel + 1).clamp(1, 60);

    final db = _db;
    if (db != null) {
      final now = DateTime.now().toIso8601String();
      // Read current level_status_map and merge on student_progress
      final currentRow = await db
          .from('student_progress')
          .select('level_status_map')
          .eq('uid', userId)
          .maybeSingle();
      final existingMap = Map<String, dynamic>.from(
        currentRow?['level_status_map'] as Map? ?? {},
      );
      existingMap[targetLevel.toString()] = 'completed';
      existingMap[nextLevel.toString()] = 'unlocked';

      await db.from('student_progress').update({
        'remediation': null,
        'remediation_active': false,
        'current_level': nextLevel,
        'level_status_map': existingMap,
        'updated_at': now,
      }).eq('uid', userId);
    }

    debugPrint('[RemediationService] Remediation complete for level $targetLevel. '
        'Unlocked level $nextLevel.');
  }

  /// Handles a repeat failure on the challenge question or exceeding preparation attempts.
  ///
  /// Increments the remediation [cycleCount]. If the student reaches or exceeds
  /// [kMaxRemediationCycles], triggers the [needsTeacherSupport] state instead of
  /// looping endlessly, and records an alert audit in `student_results`.
  Future<RemediationState> repeatFailure({
    required String userId,
    required RemediationState remediation,
    String? reason,
  }) async {
    final nextCycle = remediation.cycleCount + 1;
    final bool needsSupport = nextCycle > kMaxRemediationCycles;
    final String? finalReason = reason ??
        (needsSupport
            ? 'Struggling with Level ${remediation.targetLevel} after $kMaxRemediationCycles remediation cycles'
            : null);

    final reset = remediation.copyWith(
      attemptsInRange: 0,
      masteryScore: 0.0,
      cycleCount: nextCycle,
      needsTeacherSupport: needsSupport,
      supportReason: finalReason,
      recentAnswerCorrectness: const [],
      updatedAt: DateTime.now(),
    );

    final userPayload = <String, dynamic>{
      'remediation': reset.toMap(),
    };
    if (needsSupport) {
      userPayload['needsTeacherSupport'] = true;
      userPayload['status'] = 'needs_support';
      userPayload['studentStatus'] = 'needs_support';
    }

    final db = _db;
    if (db != null) {
      final now = DateTime.now().toIso8601String();
      await db.from('student_progress').update({
        'remediation': reset.toMap(),
        'remediation_active': reset.active,
        'updated_at': now,
      }).eq('uid', userId);

      if (needsSupport) {
        try {
          await recordRemediationResult(
            userId: userId,
            targetLevel: remediation.targetLevel,
            assessmentType: AssessmentType.remediationSupportNeeded,
            score: 0,
            totalQuestions: 1,
            competencyCode: remediation.competencyCode ?? '',
            completionStatus: 'needs_support',
          );
        } catch (e) {
          debugPrint('[RemediationService] support alert record error: $e');
        }
      }
    }

    debugPrint('[RemediationService] Repeat failure on level ${remediation.targetLevel}. '
        'Cycle: $nextCycle. NeedsSupport: $needsSupport.');

    return reset;
  }

  /// Persists the current remediation state to student_progress.
  Future<void> updateRemediationState({
    required String userId,
    required RemediationState remediation,
  }) async {
    final db = _db;
    if (db != null) {
      await db.from('student_progress').update({
        'remediation': remediation.toMap(),
        'remediation_active': remediation.active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', userId);
    }
  }

  /// Writes a remediation result to the `student_results` collection.
  Future<void> recordRemediationResult({
    required String userId,
    required int targetLevel,
    required String assessmentType,
    required int score,
    required int totalQuestions,
    required String competencyCode,
    List<QuestionResultItem>? questionResults,
    String? completionStatus,
  }) async {
    final db = _db;
    if (db == null) return;

    final zone = _getZoneForLevel(targetLevel);
    final percentage = totalQuestions > 0 ? (score / totalQuestions) * 100.0 : 0.0;
    final status = completionStatus ?? ((score == totalQuestions || percentage >= 80.0) ? 'passed' : 'retry');
    final itemsList = questionResults?.map((e) => e.toMap()).toList();

    String lrn = '';
    try {
      final u = await db.from('users').select('lrn').eq('id', userId).maybeSingle();
      lrn = u?['lrn']?.toString() ?? '';
    } catch (_) {}

    await db.from('student_results').insert({
      'student_uid': userId,
      if (lrn.isNotEmpty) 'lrn': lrn,
      'level_number': targetLevel,
      'zone': 'ZONE_$zone',
      'assessment_type': assessmentType,
      'score': score,
      'max_score': totalQuestions,
      'percentage': percentage,
      'accuracy': totalQuestions > 0 ? score / totalQuestions : 0.0,
      'result_data': {
        'studentId': userId,
        'title': 'Remediation Session (Level $targetLevel)',
        'completionStatus': status,
        'competencyCode': competencyCode,
        'questionResults': ?itemsList,
      },
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Helper to determine the zone (1, 2, or 3) for a given level.
  static int _getZoneForLevel(int level) {
    if (level <= 20) return 1;
    if (level <= 40) return 2;
    return 3;
  }
}