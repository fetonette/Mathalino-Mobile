import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/diagnostic_questions.dart';
import '../models/question.dart';

/// Diagnostic Assessment Service for Mathalino Student App
/// 
/// Provides methods to:
/// - Load diagnostic assessment questions
/// - Map diagnostic data to Question models
/// - Apply placement rules based on performance
/// - Generate diagnostic result reports
class DiagnosticAssessmentService {
  /// Load the 20-item diagnostic assessment as Question objects
  /// 
  /// Returns a list of 20 Question objects ready for presentation to students.
  List<Question> loadDiagnosticQuestions() {
    return diagnosticAssessmentQuestions.map((qData) {
      final choices = (qData['choices'] as List<dynamic>?)?.cast<String>();
      return Question(
        id: qData['id'] as String,
        grade: qData['grade'] as int,
        contentDomain: qData['contentDomain'] as String,
        competencyCode: qData['competencyCode'] as String,
        competencyText: qData['competencyText'] as String,
        cognitiveDomain: qData['cognitiveDomain'] as String,
        type: qData['type'] as String,
        questionText: qData['questionText'] as String,
        choices: choices,
        correctAnswer: qData['correctAnswer'],
        maxPoints: (qData['maxPoints'] ?? 1) as int,
      );
    }).toList();
  }

  /// Get a specific diagnostic question by ID
  Question? getDiagnosticQuestion(String questionId) {
    final qData = diagnosticAssessmentQuestions
        .firstWhere((q) => q['id'] == questionId, orElse: () => {});
    
    if (qData.isEmpty) return null;
    
    final choices = (qData['choices'] as List<dynamic>?)?.cast<String>();
    return Question(
      id: qData['id'] as String,
      grade: qData['grade'] as int,
      contentDomain: qData['contentDomain'] as String,
      competencyCode: qData['competencyCode'] as String,
      competencyText: qData['competencyText'] as String,
      cognitiveDomain: qData['cognitiveDomain'] as String,
      type: qData['type'] as String,
      questionText: qData['questionText'] as String,
      choices: choices,
      correctAnswer: qData['correctAnswer'],
      maxPoints: (qData['maxPoints'] ?? 1) as int,
    );
  }

  /// Get competency description for a competency code
  String getCompetencyDescription(String competencyCode) {
    return competencyDescriptions[competencyCode] ?? 'Unknown competency';
  }

  /// Get placement rule info for a given performance category
  Map<String, dynamic>? getPlacementRuleInfo(String category) {
    switch (category.toLowerCase()) {
      case 'beginner':
        return placementRules['beginner'] as Map<String, dynamic>?;
      case 'intermediate':
        return placementRules['intermediate'] as Map<String, dynamic>?;
      case 'advanced':
        return placementRules['advanced'] as Map<String, dynamic>?;
      case 'mastery':
        return placementRules['mastery'] as Map<String, dynamic>?;
      default:
        return null;
    }
  }

  /// Analyze diagnostic performance and return insights
  /// 
  /// Returns a map containing:
  /// - category: Placement category
  /// - percentage: Score percentage
  /// - strengthCompetencies: List of competencies with 100% accuracy
  /// - weakCompetencies: List of competencies with 0% accuracy
  /// - recommendations: Personalized learning recommendations
  Map<String, dynamic> analyzeDiagnosticPerformance({
    required List<Question> questions,
    required List<dynamic> answers,
    required double scorePercentage,
    required String placementCategory,
  }) {
    if (questions.isEmpty || questions.length != answers.length) {
      return {
        'category': placementCategory,
        'percentage': scorePercentage,
        'strengthCompetencies': <String>[],
        'weakCompetencies': <String>[],
        'recommendations': ['Complete all diagnostic items for detailed analysis'],
      };
    }

    // Analyze performance by competency
    final competencyScores = <String, Map<String, int>>{};

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final competency = q.competencyCode;

      if (!competencyScores.containsKey(competency)) {
        competencyScores[competency] = {'correct': 0, 'total': 0};
      }

      competencyScores[competency]!['total'] =
          (competencyScores[competency]!['total'] ?? 0) + 1;

      // Check if the student's answer for this competency is correct.
      final answer = i < answers.length ? answers[i] : null;
      final acceptedAnswers = _extractAcceptedAnswers(q.correctAnswer);
      if (answer != null && _isAnswerCorrect(answer, acceptedAnswers)) {
        competencyScores[competency]!['correct'] =
            (competencyScores[competency]!['correct'] ?? 0) + 1;
      }
    }

    // Identify strengths and weaknesses
    final strengths = <String>[];
    final weaknesses = <String>[];
    
    for (final entry in competencyScores.entries) {
      final competency = entry.key;
      final score = entry.value;
      final total = score['total'] ?? 1;
      
      if (total > 0) {
        final percentage = ((score['correct'] ?? 0) / total) * 100;
        if (percentage == 100) {
          strengths.add(competency);
        } else if (percentage == 0) {
          weaknesses.add(competency);
        }
      }
    }

    // Generate recommendations
    final recommendations = <String>[];
    
    if (scorePercentage >= 100) {
      recommendations.add('Excellent! You\'ve mastered all diagnostic items.');
      recommendations.add('Start with advanced challenges to accelerate your learning.');
    } else if (scorePercentage >= 75) {
      recommendations.add('Great job! You have a strong foundation.');
      recommendations.add('Focus on refining advanced problem-solving skills.');
      if (weaknesses.isNotEmpty) {
        recommendations.add('Review: ${weaknesses.join(", ")}');
      }
    } else if (scorePercentage >= 50) {
      recommendations.add('Good progress! You\'re building your skills.');
      recommendations.add('Practice more with mixed difficulty problems.');
      if (weaknesses.isNotEmpty) {
        recommendations.add('Work on: ${weaknesses.join(", ")}');
      }
    } else {
      recommendations.add('Keep practicing! You\'re starting your math journey.');
      recommendations.add('Begin with foundational skills and build gradually.');
      if (weaknesses.isNotEmpty) {
        recommendations.add('Focus areas: ${weaknesses.join(", ")}');
      }
    }

    return {
      'category': placementCategory,
      'percentage': scorePercentage,
      'strengthCompetencies': strengths,
      'weakCompetencies': weaknesses,
      'recommendations': recommendations,
    };
  }

  /// Build detailed diagnostic result report for storage
  /// 
  /// Creates a comprehensive breakdown suitable for parent/teacher review
  Map<String, dynamic> buildDiagnosticResultReport({
    required String studentId,
    required String studentName,
    required int gradeLevel,
    required List<Question> questions,
    required List<dynamic> answers,
    required int correctCount,
    required double scorePercentage,
    required String placementCategory,
  }) {
    final itemBreakdown = <Map<String, dynamic>>[];
    
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final answer = i < answers.length ? answers[i] : null;
      final accepted = _extractAcceptedAnswers(q.correctAnswer);
      final isCorrect = answer != null && _isAnswerCorrect(answer, accepted);
      
      itemBreakdown.add({
        'itemNumber': i + 1,
        'questionId': q.id,
        'competencyCode': q.competencyCode,
        'competencyText': q.competencyText,
        'correct': isCorrect,
        'studentAnswer': answer,
        'correctAnswer': q.correctAnswer,
      });
    }

    return {
      'studentId': studentId,
      'studentName': studentName,
      'gradeLevel': gradeLevel,
      'totalItems': questions.length,
      'correctAnswers': correctCount,
      'percentage': scorePercentage,
      'placementCategory': placementCategory,
      'timestamp': FieldValue.serverTimestamp(),
      'itemBreakdown': itemBreakdown,
      'competenciesMastered': itemBreakdown
          .where((item) => item['correct'] == true)
          .map((item) => item['competencyCode'])
          .toSet()
          .toList(),
      'competenciesToDevelop': itemBreakdown
          .where((item) => item['correct'] == false)
          .map((item) => item['competencyCode'])
          .toSet()
          .toList(),
    };
  }

  /// Validate diagnostic assessment data
  /// 
  /// Returns validation errors if any, or empty list if valid
  List<String> validateDiagnosticCompletion({
    required List<Question> questions,
    required List<dynamic> answers,
  }) {
    final errors = <String>[];
    
    if (questions.isEmpty) {
      errors.add('No diagnostic questions loaded');
    }
    
    if (answers.isEmpty) {
      errors.add('No answers submitted');
    }
    
    if (questions.length != 20) {
      errors.add('Expected 20 diagnostic items, got ${questions.length}');
    }
    
    if (questions.length != answers.length) {
      errors.add('Answer count (${answers.length}) does not match question count (${questions.length})');
    }
    
    for (var i = 0; i < answers.length; i++) {
      if (answers[i] == null) {
        errors.add('Question ${i + 1} has no answer');
      }
    }
    
    return errors;
  }

  /// Get recommended content pools for a placement category
  List<String> getContentPoolsForCategory(String category) {
    final rule = getPlacementRuleInfo(category);
    if (rule != null && rule.containsKey('contentPools')) {
      return List<String>.from(rule['contentPools'] as List);
    }
    return ['Grade 1', 'Grade 2', 'Grade 3'];
  }

  // ── Private Helpers ──────────────────────────────────────────────────

  /// Extract `List<String>` of accepted answer forms from String or List.
  List<String> _extractAcceptedAnswers(dynamic correctAnswer) {
    if (correctAnswer == null) return [];

    if (correctAnswer is List) {
      return correctAnswer.map((e) => e.toString()).toList();
    }

    return [correctAnswer.toString()];
  }

  /// Check whether a student's raw answer matches any accepted answer form.
  ///
  /// Uses a normalized (trimmed, case-insensitive) comparison and also
  /// supports choice-letter prefix matching (e.g. "A" vs "A. 21 742").
  bool _isAnswerCorrect(dynamic rawAnswer, List<String> acceptedAnswers) {
    if (rawAnswer == null) return false;
    final String studentStr = rawAnswer.toString().trim();
    if (studentStr.isEmpty) return false;

    for (final accepted in acceptedAnswers) {
      final String acceptedStr = accepted.trim();

      // 1. Direct case-insensitive match.
      if (studentStr.toLowerCase() == acceptedStr.toLowerCase()) {
        return true;
      }

      // 2. Choice letter prefix match (e.g. "A" vs "A. 10").
      if (_matchesChoiceLetterPrefix(studentStr, acceptedStr)) {
        return true;
      }

      // 3. Numeric match (for numericInput / computation types).
      final num? studentNum = num.tryParse(
        studentStr.replaceAll(RegExp(r'\s+'), ''),
      );
      final num? acceptedNum = num.tryParse(
        acceptedStr.replaceAll(RegExp(r'\s+'), ''),
      );
      if (studentNum != null && acceptedNum != null) {
        if ((studentNum - acceptedNum).abs() < 0.0001) {
          return true;
        }
      }
    }

    return false;
  }

  /// Match choice letter prefix e.g. "A" vs "A. 10"
  bool _matchesChoiceLetterPrefix(String a, String b) {
    final String normA = a.toLowerCase();
    final String normB = b.toLowerCase();

    final matchA = RegExp(r'^([a-d])[\.\s]*').firstMatch(normA);
    final matchB = RegExp(r'^([a-d])[\.\s]*').firstMatch(normB);

    if (matchA != null && matchB != null) {
      return matchA.group(1) == matchB.group(1);
    }

    if (normA.length == 1 && RegExp(r'^[a-d]$').hasMatch(normA)) {
      if (normB.startsWith('$normA.') || normB.startsWith('$normA ')) {
        return true;
      }
    }

    if (normB.length == 1 && RegExp(r'^[a-d]$').hasMatch(normB)) {
      if (normA.startsWith('$normB.') || normA.startsWith('$normB ')) {
        return true;
      }
    }

    return false;
  }
}
