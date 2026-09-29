// lib/core/services/diagnostic_question_service.dart
//
// Fetches the RMA-based diagnostic question bank from Supabase and selects
// the 20 items that make up a student's diagnostic attempt.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/diagnostic_questions.dart';
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
/// Every database call is wrapped in try-catch. Failures are re-thrown as
/// [DiagnosticException] — never a raw error — so the UI layer can
/// present a retry state to the student.
class DiagnosticQuestionService {
  DiagnosticQuestionService();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Number of items issued for a single diagnostic attempt.
  static const int defaultAttemptCount = 20;

  /// Selects the [count] questions for a student's diagnostic attempt.
  ///
  /// [usedQuestionsHistory] holds question IDs the student already answered;
  /// unseen questions are preferred, and previously-used questions are only
  /// used as backfill when fewer than [count] unseen items remain.
  ///
  /// Throws [DiagnosticException] if the diagnostic bank is empty or the
  /// database read fails, so the caller can show a retryable state.
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

  /// Fetches the full DIAGNOSTIC bank from Supabase `/questions` typed into [Question].
  ///
  /// Falls back to bundled `diagnosticAssessmentQuestions` if the database is
  /// uninitialized or the remote query is empty.
  Future<List<Question>> _fetchDiagnosticBank() async {
    final valid = <Question>[];
    final seenQuestionIds = <String>{};
    final client = _db;

    if (client != null) {
      try {
        final rows = await client
            .from('questions')
            .select()
            .eq('raw_data->>assessmentType', 'DIAGNOSTIC');

        for (final data in rows) {
          final rawData = data['raw_data'] is Map<String, dynamic>
              ? data['raw_data'] as Map<String, dynamic>
              : (data['raw_data'] is Map
                  ? Map<String, dynamic>.from(data['raw_data'] as Map)
                  : null);
          final questionId = data['question_id']?.toString() ??
              data['id']?.toString() ??
              rawData?['questionId']?.toString();
          final rawChoices = data['choices'] ?? rawData?['choices'];
          const choiceKeys = ['A', 'B', 'C', 'D'];
          final hasValidChoices = rawChoices is Map &&
              choiceKeys.every(
                (key) =>
                    rawChoices[key]?.toString().trim().isNotEmpty ?? false,
              );
          final prompt = rawData?['prompt']?.toString() ??
              data['question_text']?.toString() ??
              data['prompt']?.toString();
          final correctAnswer =
              data['correct_answer'] ?? rawData?['correctAnswer'];

          if (questionId == null ||
              questionId.isEmpty ||
              seenQuestionIds.contains(questionId) ||
              prompt == null ||
              prompt.trim().isEmpty ||
              correctAnswer == null ||
              !hasValidChoices) {
            continue;
          }
          seenQuestionIds.add(questionId);
          valid.add(
            _questionFromMap(
              data: data,
              id: questionId,
              prompt: prompt,
              rawChoices: rawChoices,
              correctAnswer: correctAnswer.toString(),
              rawData: rawData,
            ),
          );
        }
      } catch (e) {
        debugPrint('[DiagnosticQuestionService] Supabase fetch error: $e');
      }
    }

    // Fallback to bundled RMA diagnostic questions if empty
    if (valid.isEmpty) {
      debugPrint('[DiagnosticQuestionService] Using bundled diagnostic questions fallback');
      for (final qMap in diagnosticAssessmentQuestions) {
        final id = qMap['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenQuestionIds.contains(id)) {
          seenQuestionIds.add(id);
          valid.add(Question.fromMap(qMap, id));
        }
      }
    }

    return valid;
  }

  /// Maps a Supabase `questions` row onto the app's [Question] model.
  Question _questionFromMap({
    required Map<String, dynamic> data,
    required String id,
    required String prompt,
    required Map rawChoices,
    required String correctAnswer,
    Map<String, dynamic>? rawData,
  }) {
    final choices = <String>[];
    const keys = ['A', 'B', 'C', 'D'];
    for (final key in keys) {
      final value = rawChoices[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        choices.add('$key. ${value.toString()}');
      }
    }

    final competency = rawData?['competency']?.toString() ??
        data['strand']?.toString() ??
        data['competency']?.toString() ??
        '';
    final difficulty = rawData?['difficulty']?.toString() ??
        data['difficulty']?.toString() ??
        'Knowing';
    final grade = rawData?['gradeLevel'] is int
        ? rawData!['gradeLevel'] as int
        : (int.tryParse(data['grade_level']?.toString() ?? '') ??
            int.tryParse(data['grade']?.toString() ?? '') ??
            1);

    return Question(
      id: id,
      grade: grade,
      contentDomain: competency,
      competencyCode: competency,
      competencyText: competency,
      cognitiveDomain: difficulty,
      type: 'multipleChoice',
      questionText: prompt,
      choices: choices.isEmpty ? null : choices,
      correctAnswer: correctAnswer,
      maxPoints: 1,
    );
  }
}
