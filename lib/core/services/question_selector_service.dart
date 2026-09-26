import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'question_repository.dart';

/// Question Selector Service for Mathalino Student App.
///
/// Responsible for querying the Firestore `/questions` collection and
/// returning a curated list of [Question] objects based on the current
/// level, content pool (competency codes), and the student's question
/// history. Also supports remediation-specific filtering by competency
/// code and explicit question exclusions.
class QuestionSelectorService {
  final FirebaseFirestore? _injectedFirestore;

  QuestionSelectorService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore? _resolvedFirestore;

  FirebaseFirestore? get _db {
    if (_injectedFirestore != null) return _injectedFirestore;
    try {
      _resolvedFirestore ??= FirebaseFirestore.instance;
      return _resolvedFirestore;
    } catch (_) {
      return null;
    }
  }

  /// Selects questions for a given level and content pool.
  ///
  /// [level] - The current level being played (contains difficulty + levelNumber).
  /// [contentPool] - List of competency codes or content domains to filter by.
  /// [usedQuestionsHistory] - Question IDs already answered by the student (excluded).
  /// [zone] - Zone number (1, 2, or 3) used to infer grade band.
  /// [competencyCode] - Optional specific competency code filter (used in remediation).
  /// [excludeQuestionIds] - Optional additional question IDs to exclude (e.g. the
  ///   previously failed question during remediation challenge).
  /// [limit] - Maximum number of questions to return.
  Future<List<Question>> selectQuestions({
    required Level level,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
    required int zone,
    String? competencyCode,
    List<String>? excludeQuestionIds,
    int limit = 5,
  }) async {
    final firestore = _db;
    if (firestore != null) {
      try {
        // Build the base query against the /questions collection.
        Query query = firestore.collection('questions');

      // 1. Filter by grade band derived from the zone.
      final (gradeStart, gradeEnd) = _gradeBandForZone(zone);
      query = query.where('grade', isGreaterThanOrEqualTo: gradeStart);
      query = query.where('grade', isLessThanOrEqualTo: gradeEnd);

      // 2. Filter by specific competency code if provided (e.g. remediation).
      if (competencyCode != null && competencyCode.isNotEmpty) {
        query = query.where('competencyCode', isEqualTo: competencyCode);
      } else if (contentPool.isNotEmpty) {
        // Only apply whereIn if contentPool contains actual competency codes (not grade labels)
        final isCompetencyList = contentPool.every((c) => !c.toLowerCase().startsWith('grade '));
        if (isCompetencyList && contentPool.length <= 10) {
          query = query.where('competencyCode', whereIn: contentPool);
        }
      }

      // 3. Apply limit (fetch a bit more to allow for exclusions).
      query = query.limit(limit + usedQuestionsHistory.length + (excludeQuestionIds?.length ?? 0) + 10);

      final snapshot = await query.get();

      // 4. Build the exclusion set.
      final excludedIds = <String>{
        ...usedQuestionsHistory,
        ...?excludeQuestionIds,
      };

      // 5. Filter out used/excluded questions and map to Question objects.
      final questions = snapshot.docs
          .map((doc) => Question.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((q) => !excludedIds.contains(q.id))
          .toList();

      // 6. Shuffle to randomize selection order.
      questions.shuffle();

      if (questions.isNotEmpty) {
        return questions.take(limit).toList();
      }
    } catch (e) {
      debugPrint('[QuestionSelectorService] Firestore query error, attempting local fallback: $e');
    }
  }

    // 7. Fallback to QuestionRepository if Firestore query returns empty or fails
    try {
      final (gradeStart, gradeEnd) = _gradeBandForZone(zone);
      final excludedIds = <String>{
        ...usedQuestionsHistory,
        ...?excludeQuestionIds,
      };
      final repo = QuestionRepository(firestore: _injectedFirestore);
      return await repo.selectLevelQuestions(
        minGrade: gradeStart,
        maxGrade: gradeEnd,
        competencyCodes: competencyCode != null ? [competencyCode] : null,
        excludeQuestionIds: excludedIds,
        count: limit,
      );
    } catch (e) {
      debugPrint('[QuestionSelectorService] Fallback error: $e');
      return [];
    }
  }

  /// Returns the grade band [start, end] for a given zone.
  ///
  /// Zone 1: Grades 1-3, Zone 2: Grades 4-6, Zone 3: Grades 7-10.
  (int, int) _gradeBandForZone(int zone) {
    switch (zone) {
      case 1:
        return (1, 3);
      case 2:
        return (4, 6);
      case 3:
        return (7, 10);
      default:
        return (1, 10);
    }
  }
}

/// Lightweight Level descriptor used by [QuestionSelectorService].
///
/// Shared by both the standard gameplay flow and the remediation engine.
class Level {
  final String difficulty;
  final int levelNumber;

  Level({required this.difficulty, required this.levelNumber});
}
