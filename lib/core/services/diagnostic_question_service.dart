// lib/core/services/diagnostic_question_service.dart
//
// Fetches the RMA-based diagnostic question bank from Firestore and selects
// the 20 items that make up a student's diagnostic attempt. This is the single
// source of truth the UI layer calls for diagnostic questions — no question
// content is ever hardcoded in a widget.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../errors/diagnostic_exception.dart';
import '../models/question.dart';
import 'question_shuffle_service.dart';

/// Fetches and selects diagnostic assessment questions for Mathalino.
///
/// Responsibilities:
/// 1. Load the full `/questions` bank where `assessmentType == 'DIAGNOSTIC'`
///    (the 40 items seeded from `diagnostic_assessment_questions.json`) via a
///    typed [withConverter] onto the existing [Question] model.
/// 2. Fisher-Yates shuffle the whole 40-item pool via
///    [QuestionShuffleService.fisherYatesShuffle].
/// 3. Prefer questions the student has never answered ([usedQuestionsHistory])
///    and backfill from a shuffled, previously-used pool only when fewer than
///    the attempt size of unseen items remain, so a retake still yields a full
///    diagnostic.
/// 4. Return exactly [count] (default 20) [Question] objects.
///
/// Every Firestore call is wrapped in try-catch. Failures are re-thrown as
/// [DiagnosticException] — never a raw Firestore error — so the UI layer can
/// present a retry state to the student.
class DiagnosticQuestionService {
  final FirebaseFirestore? _injectedFirestore;

  DiagnosticQuestionService({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  /// Uses the project's named Firestore database `default`, which is where the
  /// diagnostic question bank is seeded (see firebase-import/seed_diagnostic_questions.js
  /// and the shared firebaseConfig.js convention). The implicit `(default)`
  /// database is not provisioned for this project.
  FirebaseFirestore get _firestore =>
      _injectedFirestore ??
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  /// Number of items issued for a single diagnostic attempt.
  static const int defaultAttemptCount = 20;

  /// Selects the [count] questions for a student's diagnostic attempt.
  ///
  /// [usedQuestionsHistory] holds question IDs the student already answered;
  /// unseen questions are preferred, and previously-used questions are only
  /// used as backfill when fewer than [count] unseen items remain.
  ///
  /// Throws [DiagnosticException] if the diagnostic bank is empty or the
  /// Firestore read fails, so the caller can show a retryable state.
  Future<List<Question>> selectDiagnosticQuestions({
    required Set<String> usedQuestionsHistory,
    int count = defaultAttemptCount,
  }) async {
    try {
      final pool = await _fetchDiagnosticBank();

      if (pool.isEmpty) {
        throw DiagnosticException(
          'No diagnostic questions are available right now. '
          'Please check your connection and try again.',
          code: 'DIAGNOSTIC_BANK_EMPTY',
        );
      }

      final selected = selectAttemptItems(
        pool: pool,
        usedQuestionsHistory: usedQuestionsHistory,
        count: count,
      );

      if (selected.length != count) {
        throw DiagnosticException(
          'Not enough unique diagnostic questions are available for this attempt.',
          code: 'DIAGNOSTIC_BANK_INSUFFICIENT',
        );
      }

      debugPrint(
        '[DiagnosticQuestionService] Bank: ${pool.length} items, '
        'selected: ${selected.length}.',
      );
      return selected;
    } on DiagnosticException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[DiagnosticQuestionService] Firestore error: $e');
      throw DiagnosticException(
        'Failed to load diagnostic questions: ${e.message ?? e.code}. '
        'Please check your connection and try again.',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      debugPrint('[DiagnosticQuestionService] Unexpected error: $e');
      throw DiagnosticException(
        'Failed to load diagnostic questions. Please try again.',
        originalError: e,
      );
    }
  }

  /// Pure selection logic (no I/O) — unit-tested for the "exactly [count]
  /// items, even on a retake" guarantee.
  ///
  /// Fisher-Yates shuffles the full [pool], prefers questions not in
  /// [usedQuestionsHistory], and backfills from previously-seen questions only
  /// when fewer than [count] unseen items remain. Because
  /// `pool.length >= count` (the 40-item bank vs a 20-item attempt), this
  /// always returns exactly [count] unique questions.
  @visibleForTesting
  static List<Question> selectAttemptItems({
    required List<Question> pool,
    required Set<String> usedQuestionsHistory,
    required int count,
  }) {
    // Fisher-Yates shuffle the full pool (uses the shared utility).
    final shuffledPool = QuestionShuffleService.fisherYatesShuffle(pool);

    // Prefer unseen questions; keep previously-seen ones for backfill. The
    // shuffled order is preserved within each group, so selection is uniform.
    final unseen = <Question>[];
    final previouslySeen = <Question>[];
    for (final question in shuffledPool) {
      if (usedQuestionsHistory.contains(question.id)) {
        previouslySeen.add(question);
      } else {
        unseen.add(question);
      }
    }

    // Take the first [count] unseen items; backfill from the previously-used
    // pool only when fewer than [count] unseen items remain.
    return <Question>[
      ...unseen.take(count),
      if (unseen.length < count) ...previouslySeen.take(count - unseen.length),
    ];
  }

    /// Fetches the full DIAGNOSTIC bank from `/questions` typed into [Question].
  ///
  /// Only documents whose schema matches the seeded RMA bank are returned —
  /// i.e. those carrying a `questionId` field and a `choices` map (`{A,B,C,D}`).
  /// Legacy diagnostic documents that predate the bank (different field layout,
  /// e.g. a `choices` list) are filtered out here so they never leak into a
  /// student attempt as corrupted/unset fields.
  Future<List<Question>> _fetchDiagnosticBank() async {
    final raw = await _firestore
        .collection('questions')
        .where('assessmentType', isEqualTo: 'DIAGNOSTIC')
        .get();

    final valid = <Question>[];
    final seenQuestionIds = <String>{};
    for (final doc in raw.docs) {
      final data = doc.data();
      // Bank schema guard: must have a `questionId` and a `choices` map.
      final questionId = data['questionId']?.toString();
      final rawChoices = data['choices'];
      const choiceKeys = ['A', 'B', 'C', 'D'];
      final hasValidChoices = rawChoices is Map &&
          rawChoices.length == choiceKeys.length &&
          choiceKeys.every(
            (key) => rawChoices[key]?.toString().trim().isNotEmpty ?? false,
          );
      if (questionId == null ||
          questionId.isEmpty ||
          seenQuestionIds.contains(questionId) ||
          data['prompt']?.toString().trim().isEmpty != false ||
          data['correctAnswer'] == null ||
          !hasValidChoices) {
        continue;
      }
      seenQuestionIds.add(questionId);
      valid.add(_questionFromFirestore(doc, null));
    }
    return valid;
  }

  /// Firestore `fromFirestore` converter for the RMA diagnostic schema.
  ///
  /// Maps the seeded `/questions` document (fields: `questionId`, `gradeLevel`,
  /// `competency`, `difficulty`, `prompt`, `choices` {A,B,C,D}, `correctAnswer`,
  /// `assessmentType`, `zoneEligibility`) onto the app's existing [Question]
  /// model so the rest of the codebase needs no changes.
  Question _questionFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw FormatException(
        'Diagnostic question document ${snapshot.id} contains null data.',
      );
    }

    // choices arrives as a map {A,B,C,D}; render as "A. <text>" … "D. <text>"
    // so both the QuestionCard widget and the choice-letter grading logic work.
    final choices = <String>[];
    final rawChoices = data['choices'];
    if (rawChoices is Map) {
      const keys = ['A', 'B', 'C', 'D'];
      for (final key in keys) {
        final value = rawChoices[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          choices.add('$key. ${value.toString()}');
        }
      }
    }

    final competency = data['competency']?.toString() ?? '';
    final difficulty = data['difficulty']?.toString() ?? 'Knowing';

    return Question(
      id: data['questionId']?.toString() ?? snapshot.id,
      grade: (data['gradeLevel'] ?? 1) as int,
      contentDomain: competency,
      competencyCode: competency,
      competencyText: competency,
      cognitiveDomain: difficulty,
      type: 'multipleChoice',
      questionText: data['prompt']?.toString() ?? '',
      choices: choices.isEmpty ? null : choices,
      correctAnswer: data['correctAnswer'] ?? '',
      maxPoints: 1,
    );
  }
}
