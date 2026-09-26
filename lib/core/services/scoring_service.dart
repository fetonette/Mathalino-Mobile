import '../models/question.dart';

/// Scoring Service for Mathalino Student App
/// Evaluates student answers against Question specifications and return points earned.
class ScoringService {
  /// Score a single Question against a student's raw answer
  /// Returns points earned (0 to question.maxPoints)
  int scoreQuestion(Question question, dynamic rawAnswer) {
    if (rawAnswer == null) return 0;

    final String type = question.type;

    switch (type) {
      case 'multipleChoice':
      case 'trueFalse':
        return _scoreChoiceOrTrueFalse(question, rawAnswer);

      case 'numericInput':
        return _scoreNumericInput(question, rawAnswer);

      case 'computation':
        return _scoreComputation(question, rawAnswer);

      default:
        return _scoreExactMatch(question, rawAnswer);
    }
  }

  /// Score multipleChoice and trueFalse types against correctAnswer
  /// Supports String or `List<String>` of accepted forms
  int _scoreChoiceOrTrueFalse(Question question, dynamic rawAnswer) {
    final String cleanStudentAns = rawAnswer.toString().trim();
    if (cleanStudentAns.isEmpty) return 0;

    final dynamic correct = question.correctAnswer;
    final List<String> acceptedAnswers = _extractAcceptedAnswers(correct);

    for (final accepted in acceptedAnswers) {
      final String cleanAccepted = accepted.trim();
      
      // 1. Direct case-insensitive match
      if (cleanStudentAns.toLowerCase() == cleanAccepted.toLowerCase()) {
        return question.maxPoints;
      }

      // 2. Letter prefix match (e.g. "A" vs "A. 21 742" or "A. 21 742" vs "A")
      if (_matchesChoiceLetterPrefix(cleanStudentAns, cleanAccepted)) {
        return question.maxPoints;
      }
    }

    return 0;
  }

  /// Score numericInput by stripping whitespace and parsing as num
  int _scoreNumericInput(Question question, dynamic rawAnswer) {
    final String studentStr = rawAnswer.toString().replaceAll(RegExp(r'\s+'), '').trim();
    if (studentStr.isEmpty) return 0;

    final num? studentNum = num.tryParse(studentStr);

    final dynamic correct = question.correctAnswer;
    final List<String> acceptedAnswers = _extractAcceptedAnswers(correct);

    for (final accepted in acceptedAnswers) {
      final String acceptedStr = accepted.replaceAll(RegExp(r'\s+'), '').trim();
      final num? acceptedNum = num.tryParse(acceptedStr);

      if (studentNum != null && acceptedNum != null) {
        if ((studentNum - acceptedNum).abs() < 0.0001) {
          return question.maxPoints;
        }
      } else if (studentStr.toLowerCase() == acceptedStr.toLowerCase()) {
        return question.maxPoints;
      }
    }

    return 0;
  }

  /// Score computation items
  /// Performs exact-match check against correctAnswer for now
  int _scoreComputation(Question question, dynamic rawAnswer) {
    // TODO: Full rubric-based partial credit is a future enhancement
    return _scoreExactMatch(question, rawAnswer);
  }

  /// Helper exact-match comparison
  int _scoreExactMatch(Question question, dynamic rawAnswer) {
    final String cleanStudentAns = rawAnswer.toString().trim().toLowerCase();
    if (cleanStudentAns.isEmpty) return 0;

    final List<String> acceptedAnswers = _extractAcceptedAnswers(question.correctAnswer);

    for (final accepted in acceptedAnswers) {
      if (cleanStudentAns == accepted.trim().toLowerCase()) {
        return question.maxPoints;
      }
    }

    return 0;
  }

  /// Extract `List<String>` of accepted forms from String or List
  List<String> _extractAcceptedAnswers(dynamic correctAnswer) {
    if (correctAnswer == null) return [];

    if (correctAnswer is List) {
      return correctAnswer.map((e) => e.toString()).toList();
    }

    return [correctAnswer.toString()];
  }

  /// Match choice letter prefix e.g. "A" vs "A. 21 742"
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
