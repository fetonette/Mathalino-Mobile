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
    int? gradeLevel,
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
        gradeLevel: gradeLevel,
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
        'gradeLevel: $gradeLevel, '
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
  /// For students in Grade 1, 2, or 3:
  /// - Automatically prioritizes the easiest and most age-appropriate questions
  ///   based on difficulty ('Easy' / 'Knowing' first), grade level (on-grade/foundational
  ///   first), and core foundational skills (Number Identification, Counting, Basic Addition/Subtraction).
  /// - Backfills safely if fewer items exist in early grades, and prefers unseen
  ///   items on retakes while staying strictly within the age-appropriate pool.
  ///
  /// For students in Grades 4–6 (or unassigned/null):
  /// - Preserves the standard uniform shuffle selection across the full diagnostic bank.
  ///
  /// Always returns exactly [count] unique questions with valid choices and answer keys.
  @visibleForTesting
  static List<Question> selectAttemptItems({
    required List<Question> pool,
    required Set<String> usedQuestionsHistory,
    int? gradeLevel,
    int count = defaultAttemptCount,
  }) {
    // 1. Sanitize pool: discard any corrupted/invalid question entries
    final validPool = pool.where(isValidQuestion).toList();

    // 2. Route based on student grade level:
    // Grades 1–3: Prioritize easiest & age-appropriate questions
    if (gradeLevel != null && gradeLevel >= 1 && gradeLevel <= 3) {
      return _selectGradeAppropriateAttempt(
        pool: validPool,
        studentGrade: gradeLevel,
        usedQuestionsHistory: usedQuestionsHistory,
        count: count,
      );
    }

    // Grades 4–6 or unspecified: existing standard selection logic
    return _selectStandardAttempt(
      pool: validPool,
      usedQuestionsHistory: usedQuestionsHistory,
      count: count,
    );
  }

  /// Standard diagnostic question selection (used for Grades 4–6).
  /// Uniform Fisher-Yates shuffle across the full bank with unseen preference.
  static List<Question> _selectStandardAttempt({
    required List<Question> pool,
    required Set<String> usedQuestionsHistory,
    required int count,
  }) {
    final shuffledPool = QuestionShuffleService.fisherYatesShuffle(pool);

    final unseen = <Question>[];
    final previouslySeen = <Question>[];
    for (final question in shuffledPool) {
      if (usedQuestionsHistory.contains(question.id)) {
        previouslySeen.add(question);
      } else {
        unseen.add(question);
      }
    }

    return <Question>[
      ...unseen.take(count),
      if (unseen.length < count) ...previouslySeen.take(count - unseen.length),
    ];
  }

  /// Grade-adapted diagnostic question selection for Grades 1–3.
  ///
  /// Prioritizes questions based on:
  /// 1. Grade appropriateness:
  ///    - Grade 1: Grade 1 (on-level) -> Grade 2 -> Grade 3 -> Grade 4+ (fallback only)
  ///    - Grade 2: Grades 1 & 2 (foundational/on-level) -> Grade 3 -> Grade 4+ (fallback only)
  ///    - Grade 3: Grades 1–3 (foundational/on-level) -> Grade 4+ (fallback only)
  /// 2. Difficulty: Easy/Knowing (1) -> Medium/Understanding (2) -> Hard/Applying (3) -> Analyzing (4)
  /// 3. Competency: Foundational Number Sense -> Basic Operations -> Early Concepts -> Advanced
  ///
  /// For retakes, unseen questions within the age-appropriate pool are preferred,
  /// backfilling from seen questions within the same age-appropriate pool so lower-grade
  /// students never receive upper-grade questions.
  static List<Question> _selectGradeAppropriateAttempt({
    required List<Question> pool,
    required int studentGrade,
    required Set<String> usedQuestionsHistory,
    required int count,
  }) {
    // Initial shuffle ensures variety among items having equivalent priority score
    final shuffledPool = QuestionShuffleService.fisherYatesShuffle(pool);

    // Split into age-appropriate early grades (Grades 1–3) and higher grades (Grades 4+)
    final appropriatePool = shuffledPool.where((q) => q.grade <= 3).toList();
    final fallbackPool = shuffledPool.where((q) => q.grade > 3).toList();

    // Sort helper using easeScore
    int compareByEase(Question a, Question b) {
      final scoreA = _easeScore(a, studentGrade);
      final scoreB = _easeScore(b, studentGrade);
      return scoreA.compareTo(scoreB);
    }

    final selected = <Question>[];

    // Primary selection from age-appropriate pool (Grades 1–3)
    final unseenAppropriate = appropriatePool
        .where((q) => !usedQuestionsHistory.contains(q.id))
        .toList()
      ..sort(compareByEase);

    final seenAppropriate = appropriatePool
        .where((q) => usedQuestionsHistory.contains(q.id))
        .toList()
      ..sort(compareByEase);

    // 1. Take unseen appropriate questions first
    selected.addAll(unseenAppropriate.take(count));

    // 2. If needed, backfill from seen appropriate questions
    if (selected.length < count) {
      final needed = count - selected.length;
      selected.addAll(seenAppropriate.take(needed));
    }

    // 3. Safety fallback: only if the question bank itself has fewer than [count]
    // questions marked for Grades 1–3, backfill from the easiest available higher-grade items.
    if (selected.length < count) {
      final unseenFallback = fallbackPool
          .where((q) => !usedQuestionsHistory.contains(q.id))
          .toList()
        ..sort(compareByEase);

      final seenFallback = fallbackPool
          .where((q) => usedQuestionsHistory.contains(q.id))
          .toList()
        ..sort(compareByEase);

      final neededUnseen = count - selected.length;
      selected.addAll(unseenFallback.take(neededUnseen));

      if (selected.length < count) {
        final neededSeen = count - selected.length;
        selected.addAll(seenFallback.take(neededSeen));
      }
    }

    // Preserve randomization of presentation order in the assessment
    return QuestionShuffleService.fisherYatesShuffle(selected);
  }

  /// Validates that a question has complete and non-empty prompt, answer, and choices.
  static bool isValidQuestion(Question q) {
    if (q.id.trim().isEmpty) return false;
    if (q.questionText.trim().isEmpty) return false;
    if (q.correctAnswer == null) return false;
    final ansStr = q.correctAnswer.toString().trim();
    if (ansStr.isEmpty) return false;
    if (q.choices != null) {
      if (q.choices!.isEmpty) return false;
      for (final c in q.choices!) {
        if (c.trim().isEmpty) return false;
      }
    }
    return true;
  }

  /// Numeric rank for difficulty: Easy/Knowing (1) is easiest; Hard/Applying (3) is hardest.
  static int _difficultyRank(Question q) {
    final d = q.cognitiveDomain.toLowerCase().trim();
    if (d == 'easy' || d == 'knowing') return 1;
    if (d == 'medium' || d == 'understanding') return 2;
    if (d == 'hard' || d == 'applying') return 3;
    if (d == 'analyzing') return 4;
    return 2;
  }

  /// Numeric rank for competency: foundational number sense & counting first.
  static int _competencyRank(Question q) {
    final text = '${q.competencyCode} ${q.contentDomain} ${q.competencyText} ${q.questionText}'.toLowerCase();
    // Foundational number sense / counting / recognition / discrimination
    if (text.contains('identification') ||
        text.contains('count') ||
        text.contains('number sense') ||
        text.contains('m1ns') ||
        text.contains('place value') ||
        text.contains('discrimination')) {
      return 1;
    }
    // Basic operations: addition & subtraction
    if (text.contains('addition') ||
        text.contains('subtraction') ||
        text.contains('m2op') ||
        text.contains('add ') ||
        text.contains('subtract')) {
      return 2;
    }
    // Patterns, geometry, measurement, time, mass
    if (text.contains('pattern') ||
        text.contains('geometry') ||
        text.contains('measurement') ||
        text.contains('time') ||
        text.contains('mass')) {
      return 3;
    }
    // Fractions, multiplication, division
    if (text.contains('fraction') ||
        text.contains('multiplication') ||
        text.contains('multiply') ||
        text.contains('division') ||
        text.contains('divide') ||
        text.contains('m3op')) {
      return 4;
    }
    return 5;
  }

  /// Grade appropriateness tier relative to student grade.
  static int _gradeAppropriatenessTier(Question q, int studentGrade) {
    if (studentGrade == 1) {
      if (q.grade == 1) return 1; // Grade 1: on-level
      if (q.grade == 2) return 2; // Grade 2: next step
      if (q.grade == 3) return 3; // Grade 3: upper foundational
      return 4 + q.grade; // Grade 4+: upper grades (fallback only)
    } else if (studentGrade == 2) {
      if (q.grade <= 2) return 1; // Grades 1 & 2: foundational & on-level
      if (q.grade == 3) return 2; // Grade 3: next step
      return 4 + q.grade; // Grade 4+: upper grades (fallback only)
    } else {
      // studentGrade == 3
      if (q.grade <= 3) return 1; // Grades 1–3: foundational & on-level
      return 4 + q.grade; // Grade 4+: upper grades (fallback only)
    }
  }

  /// Composite ease score (lower is easier / more age-appropriate).
  static int _easeScore(Question q, int studentGrade) {
    final tier = _gradeAppropriatenessTier(q, studentGrade);
    final diff = _difficultyRank(q);
    final comp = _competencyRank(q);
    final qGrade = q.grade;
    return (tier * 1000) + (diff * 100) + (comp * 10) + qGrade;
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
