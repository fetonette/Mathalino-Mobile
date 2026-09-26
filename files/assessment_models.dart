/// lib/models/assessment_models.dart
///
/// Models for a student's answers, grading results, an assessment attempt
/// (diagnostic / level-practice / remediation), and cross-session progress.
/// Mirrors the /student_results and /users Firestore collections already
/// defined in the Mathalino architecture doc.

import 'question_model.dart';

enum AssessmentType { diagnostic, levelPractice, challengeRemediation }

enum StudentCategory { beginner, intermediate, advanced, mastery }

/// A single raw response captured from the UI before grading.
class StudentAnswer {
  final String questionId;
  final dynamic rawResponse; // String, List<String>, or choice id depending on type
  final int? timeTakenSeconds;

  const StudentAnswer({
    required this.questionId,
    required this.rawResponse,
    this.timeTakenSeconds,
  });

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'rawResponse': rawResponse,
        if (timeTakenSeconds != null) 'timeTakenSeconds': timeTakenSeconds,
      };
}

/// Result of grading a single StudentAnswer against its QuestionModel.
class GradingResult {
  final String questionId;
  final String competencyCode;
  final bool isCorrect;
  final int pointsAwarded;
  final int pointsPossible;
  final dynamic studentAnswer;
  final List<String> correctAnswerShown;

  const GradingResult({
    required this.questionId,
    required this.competencyCode,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.pointsPossible,
    required this.studentAnswer,
    required this.correctAnswerShown,
  });

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'competencyCode': competencyCode,
        'isCorrect': isCorrect,
        'pointsAwarded': pointsAwarded,
        'pointsPossible': pointsPossible,
        'studentAnswer': studentAnswer,
        'correctAnswerShown': correctAnswerShown,
      };
}

/// A completed (or in-progress) attempt at a diagnostic, a level, or a
/// remediation cycle. Maps directly onto /student_results/{resultId}.
class AssessmentAttempt {
  final String resultId;
  final String studentId;
  final AssessmentType assessmentType;
  final int? levelNumber; // null for diagnostic
  final List<QuestionModel> questionsServed;
  final List<StudentAnswer> answers;
  final List<GradingResult> itemBreakdown;
  final int score;
  final int maxScore;
  final DateTime timestamp;

  const AssessmentAttempt({
    required this.resultId,
    required this.studentId,
    required this.assessmentType,
    this.levelNumber,
    required this.questionsServed,
    required this.answers,
    required this.itemBreakdown,
    required this.score,
    required this.maxScore,
    required this.timestamp,
  });

  double get percentage => maxScore == 0 ? 0 : (score / maxScore) * 100;

  Map<String, dynamic> toJson() => {
        'resultId': resultId,
        'studentId': studentId,
        'assessmentType': assessmentType.name.toUpperCase(),
        if (levelNumber != null) 'levelNumber': levelNumber,
        'itemBreakdown': itemBreakdown.map((e) => e.toJson()).toList(),
        'score': score,
        'maxScore': maxScore,
        'percentage': percentage,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Per-competency running mastery stat, used for the "Needs Attention" rule
/// (Game Logic doc §7) and for remediation targeting.
class CompetencyMastery {
  final String competencyCode;
  final int correct;
  final int attempts;
  final DateTime? lastAttempt;

  const CompetencyMastery({
    required this.competencyCode,
    required this.correct,
    required this.attempts,
    this.lastAttempt,
  });

  double get masteryRate => attempts == 0 ? 0 : correct / attempts;
  bool get needsAttention => attempts >= 3 && masteryRate < 0.5;

  factory CompetencyMastery.fromJson(String code, Map<String, dynamic> json) =>
      CompetencyMastery(
        competencyCode: code,
        correct: json['correct'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? 0,
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.tryParse(json['lastAttempt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'attempts': attempts,
        if (lastAttempt != null) 'lastAttempt': lastAttempt!.toIso8601String(),
      };
}

/// Mirrors /users/{userId} fields relevant to content/progression (does not
/// duplicate auth/profile fields already defined in the architecture doc).
class StudentProgress {
  final String uid;
  final StudentCategory assignedCategory;
  final int currentLevel;
  final int startingLevel;
  final Set<String> usedQuestionsHistory;
  final Map<String, CompetencyMastery> competencyMastery;
  final bool diagnosticCompleted;

  const StudentProgress({
    required this.uid,
    required this.assignedCategory,
    required this.currentLevel,
    required this.startingLevel,
    required this.usedQuestionsHistory,
    required this.competencyMastery,
    required this.diagnosticCompleted,
  });

  factory StudentProgress.fromJson(String uid, Map<String, dynamic> json) {
    final masteryJson =
        (json['competencyMastery'] as Map<String, dynamic>?) ?? {};
    return StudentProgress(
      uid: uid,
      assignedCategory: StudentCategory.values.firstWhere(
        (c) => c.name.toLowerCase() ==
            (json['assignedCategory'] as String? ?? 'beginner').toLowerCase(),
        orElse: () => StudentCategory.beginner,
      ),
      currentLevel: json['currentLevel'] as int? ?? 1,
      startingLevel: json['startingLevel'] as int? ?? 1,
      usedQuestionsHistory:
          ((json['usedQuestionsHistory'] as List<dynamic>? ?? []))
              .map((e) => e.toString())
              .toSet(),
      competencyMastery: masteryJson.map(
        (code, v) => MapEntry(
            code, CompetencyMastery.fromJson(code, v as Map<String, dynamic>)),
      ),
      diagnosticCompleted: json['diagnosticCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'assignedCategory': assignedCategory.name,
        'currentLevel': currentLevel,
        'startingLevel': startingLevel,
        'usedQuestionsHistory': usedQuestionsHistory.toList(),
        'competencyMastery':
            competencyMastery.map((code, m) => MapEntry(code, m.toJson())),
        'diagnosticCompleted': diagnosticCompleted,
      };
}
