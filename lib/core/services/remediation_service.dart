import 'package:cloud_firestore/cloud_firestore.dart';
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
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
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
  final FirebaseFirestore? _injectedFirestore;
  final QuestionSelectorService _questionSelector;
  final ScoringService _scoringService;

  RemediationService({
    FirebaseFirestore? firestore,
    QuestionSelectorService? questionSelector,
    ScoringService? scoringService,
  })  : _injectedFirestore = firestore,
        _questionSelector = questionSelector ?? QuestionSelectorService(),
        _scoringService = scoringService ?? ScoringService();

  FirebaseFirestore? _resolvedFirestore;

  /// Lazily resolves Firestore or returns null if Firebase is not initialized.
  FirebaseFirestore? get _db {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      _resolvedFirestore ??= FirebaseFirestore.instance;
      return _resolvedFirestore;
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

    // 2. Write the remediation object to the student's Firestore profile.
    final firestore = _db;
    if (firestore != null) {
      await firestore.collection('users').doc(userId).set({
        'remediation': remediation.toMap(),
      }, SetOptions(merge: true));

      // Dual-write to /student_progress/{userId}
      try {
        await firestore.collection('student_progress').doc(userId).set({
          'remediation': remediation.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[RemediationService] student_progress dual-write error: $e');
      }
    }

    debugPrint('[RemediationService] Started remediation for level $failedLevel '
        'prep range ${range[0]}-${range[1]} competency ${failedQuestion.competencyCode}');

    return remediation;
  }

  /// Loads the current remediation state for a student.
  /// Dual-read: checks /student_progress/{userId} first, falling back to /users/{userId}.
  Future<RemediationState> getRemediationState(String userId) async {
    final firestore = _db;
    if (firestore == null) return RemediationState.inactive();
    try {
      final progressDoc = await firestore.collection('student_progress').doc(userId).get();
      if (progressDoc.exists && progressDoc.data()?['remediation'] != null) {
        return RemediationState.fromMap(
          progressDoc.data()!['remediation'] as Map<String, dynamic>?,
        );
      }
    } catch (e) {
      debugPrint('[RemediationService] getRemediationState student_progress read fallback: $e');
    }

    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return RemediationState.inactive();
    final data = doc.data();
    if (data == null) return RemediationState.inactive();
    return RemediationState.fromMap(data['remediation'] as Map<String, dynamic>?);
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

    final firestore = _db;
    if (firestore != null) {
      // 1. Clear the remediation object and reset studentStatus.
      await firestore.collection('users').doc(userId).update({
        'remediation': FieldValue.delete(),
        'needsTeacherSupport': false,
        'status': 'active',
        'studentStatus': 'active',
      });

      // 2. Unlock the next level.
      await firestore.collection('users').doc(userId).set({
        'levelStatus.$nextLevel': 'unlocked',
        'currentLevel': nextLevel,
      }, SetOptions(merge: true));

      // Dual-write to /student_progress/{userId}
      try {
        await firestore.collection('student_progress').doc(userId).set({
          'remediation': FieldValue.delete(),
          'needsTeacherSupport': false,
          'levelStatusMap.$nextLevel': 'unlocked',
          'currentLevel': nextLevel,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[RemediationService] student_progress completeRemediation error: $e');
      }
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

    final firestore = _db;
    if (firestore != null) {
      await firestore.collection('users').doc(userId).set(userPayload, SetOptions(merge: true));

      // Dual-write to /student_progress/{userId}
      try {
        final progressPayload = <String, dynamic>{
          'remediation': reset.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (needsSupport) {
          progressPayload['needsTeacherSupport'] = true;
        }
        await firestore.collection('student_progress').doc(userId).set(progressPayload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[RemediationService] student_progress repeatFailure error: $e');
      }

      if (needsSupport) {
        // Record support event in student_results
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
          debugPrint('[RemediationService] student_results support alert record error: $e');
        }
      }
    }

    debugPrint('[RemediationService] Repeat failure on level ${remediation.targetLevel}. '
        'Cycle: $nextCycle. NeedsSupport: $needsSupport.');

    return reset;
  }

  /// Persists the current remediation state to Firestore.
  Future<void> updateRemediationState({
    required String userId,
    required RemediationState remediation,
  }) async {
    final firestore = _db;
    if (firestore != null) {
      await firestore.collection('users').doc(userId).set({
        'remediation': remediation.toMap(),
      }, SetOptions(merge: true));

      // Dual-write to /student_progress/{userId}
      try {
        await firestore.collection('student_progress').doc(userId).set({
          'remediation': remediation.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[RemediationService] student_progress updateRemediationState error: $e');
      }
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
    final firestore = _db;
    if (firestore == null) return;

    final zone = _getZoneForLevel(targetLevel);
    final percentage = totalQuestions > 0 ? (score / totalQuestions) * 100.0 : 0.0;
    final status = completionStatus ?? ((score == totalQuestions || percentage >= 80.0) ? 'passed' : 'retry');
    final itemsList = questionResults?.map((e) => e.toMap()).toList();

    await firestore.collection('student_results').add({
      'studentId': userId,
      'userId': userId, // Dual-write alias
      'levelNumber': targetLevel,
      'zone': 'ZONE_$zone',
      'assessmentType': assessmentType,
      'title': 'Remediation Session (Level $targetLevel)',
      'score': score,
      'maxScore': totalQuestions,
      'totalQuestions': totalQuestions, // Dual-write alias
      'percentage': percentage,
      'accuracy': totalQuestions > 0 ? score / totalQuestions : 0.0,
      'completionStatus': status,
      'competencyCode': competencyCode,
      if (itemsList != null) ...{
        'questionResults': itemsList,
        'itemBreakdown': itemsList,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(), // Dual-write alias
    });
  }

  /// Helper to determine the zone (1, 2, or 3) for a given level.
  static int _getZoneForLevel(int level) {
    if (level <= 20) return 1;
    if (level <= 40) return 2;
    return 3;
  }
}