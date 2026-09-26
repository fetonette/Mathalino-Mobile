import 'package:flutter/foundation.dart';

import '../core/models/post_assessment_result.dart';
import '../core/models/question.dart';
import '../core/models/student_profile.dart';
import '../core/services/post_assessment_service.dart';

/// Provider for managing Post-Assessment state and lifecycle.
class PostAssessmentProvider extends ChangeNotifier {
  final PostAssessmentService _postAssessmentService;

  PostAssessmentProvider({
    PostAssessmentService? postAssessmentService,
  }) : _postAssessmentService =
            postAssessmentService ?? PostAssessmentService();

  // ── State ────────────────────────────────────────────────────────────

  List<Question> _questions = [];
  final List<dynamic> _answers = [];
  int _currentIndex = 0;
  int _levelMilestone = 20;
  String _zoneIdentifier = 'ZONE_1';
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isComplete = false;
  String? _errorMessage;
  PostAssessmentResult? _result;

  // ── Getters ──────────────────────────────────────────────────────────

  List<Question> get questions => _questions;
  List<dynamic> get answers => List.unmodifiable(_answers);
  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  int get levelMilestone => _levelMilestone;
  String get zoneIdentifier => _zoneIdentifier;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isComplete => _isComplete;
  String? get errorMessage => _errorMessage;
  PostAssessmentResult? get result => _result;

  Question? get currentQuestion {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return null;
    return _questions[_currentIndex];
  }

  // ── Public Actions ───────────────────────────────────────────────────

  /// Initializes and loads the post-assessment for a given milestone level.
  Future<void> initializePostAssessment({
    required StudentProfile profile,
    required int levelMilestone,
  }) async {
    _setLoading(true);
    _clearError();

    _levelMilestone = levelMilestone;
    _zoneIdentifier =
        PostAssessmentService.getZoneIdentifierForLevel(levelMilestone) ??
            'ZONE_1';
    final zoneNumber = levelMilestone <= 20 ? 1 : (levelMilestone <= 40 ? 2 : 3);

    try {
      final questions =
          await _postAssessmentService.loadPostAssessmentQuestions(
        zone: zoneNumber,
        contentPool: [profile.assignedCategory],
        usedQuestionsHistory: profile.usedQuestionsHistory,
        limit: 15,
      );

      if (questions.isEmpty) {
        throw Exception('No post-assessment questions available.');
      }

      _questions = questions;
      _answers.clear();
      _currentIndex = 0;
      _isComplete = false;
      _result = null;
    } catch (e) {
      debugPrint('[PostAssessmentProvider] Initialization error: $e');
      _errorMessage = 'Failed to load post-assessment: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Records the answer for the current question and advances.
  ///
  /// Returns `true` when all questions have been answered.
  bool answerQuestion(dynamic answer) {
    if (_currentIndex >= _questions.length) return false;

    if (_answers.length <= _currentIndex) {
      _answers.add(answer);
    } else {
      _answers[_currentIndex] = answer;
    }

    if (_currentIndex < _questions.length - 1) {
      _currentIndex++;
      notifyListeners();
      return false;
    }

    _isComplete = true;
    notifyListeners();
    return true;
  }

  /// Evaluates the post-assessment, computes domain mastery & growth,
  /// and persists profile updates in Firestore.
  Future<PostAssessmentResult> submitPostAssessment({
    required String studentId,
    required StudentProfile profile,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      final evaluatedResult = _postAssessmentService.evaluatePostAssessment(
        levelMilestone: _levelMilestone,
        zoneIdentifier: _zoneIdentifier,
        questions: _questions,
        studentAnswers: _answers,
        preAssessmentPercentage: profile.diagnosticPercentage,
      );

      await _postAssessmentService.finalizeProfileAndPersistResult(
        studentId: studentId,
        currentProfile: profile,
        result: evaluatedResult,
        questions: _questions,
        answers: _answers,
      );

      _result = evaluatedResult;
      notifyListeners();
      return evaluatedResult;
    } catch (e) {
      debugPrint('[PostAssessmentProvider] Submission error: $e');
      _errorMessage = 'Failed to finalize post-assessment: $e';
      rethrow;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Resets the provider state.
  void reset() {
    _questions = [];
    _answers.clear();
    _currentIndex = 0;
    _isComplete = false;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private Helpers ──────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
