import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  QuestionSelectorService();

  /// Selects questions for a given level and content pool.
  Future<List<Question>> selectQuestions({
    required Level level,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
    required int zone,
    String? competencyCode,
    List<String>? excludeQuestionIds,
    int limit = 5,
  }) async {
    try {
      // Build query against the Supabase `questions` table.
      final (gradeStart, gradeEnd) = _gradeBandForZone(zone);
      var query = Supabase.instance.client
          .from('questions')
          .select()
          .gte('grade', gradeStart)
          .lte('grade', gradeEnd);

      // Apply competency filter if specific code or competency-based content pool
      if (competencyCode != null && competencyCode.isNotEmpty) {
        query = query.eq('competency_code', competencyCode);
      }

      final rows = await query.limit(
        limit + usedQuestionsHistory.length + (excludeQuestionIds?.length ?? 0) + 10,
      );

      // Build the exclusion set.
      final excludedIds = <String>{
        ...usedQuestionsHistory,
        ...?excludeQuestionIds,
      };

      final questions = rows
          .map((row) => Question.fromMap(row, row['id']?.toString() ?? ''))
          .where((q) => !excludedIds.contains(q.id))
          .toList();

      questions.shuffle();

      if (questions.isNotEmpty) {
        return questions.take(limit).toList();
      }
    } catch (e) {
      debugPrint('[QuestionSelectorService] Supabase query error, attempting local fallback: $e');
    }

    // Fallback to QuestionRepository (local JSON assets)
    try {
      final (gradeStart, gradeEnd) = _gradeBandForZone(zone);
      final excludedIds = <String>{
        ...usedQuestionsHistory,
        ...?excludeQuestionIds,
      };
      final repo = QuestionRepository();
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
