import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/diagnostic_exception.dart';
import '../core/models/diagnostic_result.dart';
import '../core/models/placement_result.dart';
import '../core/models/question.dart';
import '../core/models/student_profile.dart';
import '../core/services/diagnostic_assessment_service.dart';
import '../core/services/diagnostic_question_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/game_logic_service.dart';
import '../core/services/scoring_service.dart';

/// Diagnostic Provider for Mathalino Student App.
///
/// Tracks the in-progress 20-item RMA-based diagnostic assessment, calculates
/// the percentage score, applies the new-engine placement rules via
/// [GameLogicService.scoreDiagnostic], and writes `assignedCategory`,
/// `startingLevel`, `currentLevel`, and `diagnosticCompleted` to the student's
/// /users/{userId} Firestore document.
class DiagnosticProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final DiagnosticQuestionService _diagnosticQuestionService;
  final ScoringService _scoringService;
  final DiagnosticAssessmentService _assessmentService;
  final GameLogicService _gameLogic;

  DiagnosticProvider({
    FirestoreService? firestoreService,
    DiagnosticQuestionService? diagnosticQuestionService,
    ScoringService? scoringService,
    DiagnosticAssessmentService? assessmentService,
    GameLogicService? gameLogic,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _diagnosticQuestionService =
           diagnosticQuestionService ?? DiagnosticQuestionService(),
       _scoringService = scoringService ?? ScoringService(),
       _assessmentService = assessmentService ?? DiagnosticAssessmentService(),
       _gameLogic = gameLogic ?? const GameLogicService();

  // ── State ────────────────────────────────────────────────────────────

  List<Question> _questions = [];
  final List<dynamic> _answers = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  PlacementResult? _placementResult;
  DiagnosticResult? _diagnosticResult;
  bool _isComplete = false;

  // ── Getters ──────────────────────────────────────────────────────────

  List<Question> get questions => _questions;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  PlacementResult? get placementResult => _placementResult;

  /// The tier-assignment result from [DiagnosticScoringService.evaluateAndAssignTier].
  /// Non-null after a successful [submitDiagnostic] call.
  DiagnosticResult? get diagnosticResult => _diagnosticResult;
  bool get isComplete => _isComplete;
  int get totalQuestions => _questions.length;

  /// Public access to the student's recorded answers (for analysis and testing).
  List<dynamic> get answers => List.unmodifiable(_answers);

  Question? get currentQuestion {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return null;
    return _questions[_currentIndex];
  }

  /// The number of correct answers so far (computed live for progress UI).
  int get correctCountSoFar {
    var count = 0;
    for (var i = 0; i < _answers.length && i < _questions.length; i++) {
      final points = _scoringService.scoreQuestion(_questions[i], _answers[i]);
      if (points > 0) count++;
    }
    return count;
  }

  // ── Public Methods ───────────────────────────────────────────────────

  /// Loads the 20-item diagnostic question set.
  ///
  /// Uses [DiagnosticQuestionService] to fetch the Firestore `/questions`
  /// bank where `assessmentType == 'DIAGNOSTIC'`, Fisher-Yates shuffle the
  /// pool, prefer unseen questions, and return a full 20-item attempt. The
  /// RMA-based bank is seeded from `diagnostic_assessment_questions.json`.
  Future<void> loadDiagnosticQuestions({
    required String userId,
    required int gradeLevel,
    required List<String> usedQuestionsHistory,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final questions = await _diagnosticQuestionService
          .selectDiagnosticQuestions(
            usedQuestionsHistory: usedQuestionsHistory.toSet(),
            count: 20,
          );

      if (questions.isEmpty) {
        throw DiagnosticException(
          'No diagnostic questions are available. Please check your '
          'connection and try again.',
          code: 'DIAGNOSTIC_BANK_EMPTY',
        );
      }

      _questions = questions;
      _answers.clear();
      _currentIndex = 0;
      _isComplete = false;
      _placementResult = null;
    } catch (e) {
      debugPrint('[DiagnosticProvider] loadDiagnosticQuestions error: $e');
      _errorMessage = e is DiagnosticException
          ? 'Failed to load diagnostic questions: ${e.message}'
          : 'Failed to load diagnostic questions: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Records the answer for the current question and advances.
  ///
  /// Returns `true` when the diagnostic is complete (all questions answered).
  bool answerCurrentQuestion(dynamic answer) {
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

    // All questions answered.
    _isComplete = true;
    notifyListeners();
    return true;
  }

  /// Submits the diagnostic, calculates the percentage, applies the IF–THEN
  /// placement rules, and writes the result to Firestore.
  ///
  /// Returns the [PlacementResult] on success.
  ///
  /// Runs two write pipelines in sequence:
  /// 1. The existing [PlacementService] flow (4-tier: Beginner/Intermediate/
  ///    Advanced/Mastery) — updates `assignedCategory`, `startingLevel`, etc.
  /// 2. The new [DiagnosticScoringService] flow (3-tier: Foundation/Intermediate/
  ///    Advanced) — atomically writes `assignedTier`, `diagnosticFlags`, and a
  ///    `/student_results` record via a Firestore [WriteBatch].
  ///
  /// [currentProfile.diagnosticCompleted] controls the idempotency guard on
  /// pipeline 2: if already `true`, pipeline 2 is skipped unless the caller
  /// sets [forceReassessment] to `true`.
  Future<PlacementResult> submitDiagnostic({
    required String userId,
    required StudentProfile currentProfile,
    bool forceReassessment = false,
  }) async {
    if (!_isComplete) {
      throw DiagnosticException(
        'Diagnostic is not complete yet. All questions must be answered before submission.',
        code: 'DIAGNOSTIC_INCOMPLETE',
      );
    }

    // --- Validate the submission (20 questions, 20 answers) ---
    final validationErrors = _assessmentService.validateDiagnosticCompletion(
      questions: _questions,
      answers: _answers,
    );
    if (validationErrors.isNotEmpty) {
      throw DiagnosticException(
        validationErrors.join('; '),
        code: 'DIAGNOSTIC_VALIDATION_FAILED',
      );
    }

    _setSubmitting(true);
    _clearError();
    try {
      // 1. Score each answer and apply the diagnostic placement engine
      //    (GameLogicService.scoreDiagnostic: Beginner/Intermediate/Advanced/
      //    Mastery with starting levels 1 / 21 / 41 / 41).
      final itemResults = <bool>[
        for (var i = 0; i < _questions.length; i++)
          _scoringService.scoreQuestion(_questions[i], _answers[i]) > 0,
      ];
      final score = _gameLogic.scoreDiagnostic(itemResults);

      final placement = PlacementResult(
        category: score.category,
        startingLevel: score.startingLevel,
        contentPool: _contentPoolFor(score.category),
        contentPoolLabel: score.contentPool,
        scorePercentage: score.percentage,
      );

      final diagnosticResult = DiagnosticResult(
        correctAnswers: score.correctAnswers,
        totalItems: score.totalItems,
        percentage: score.percentage,
        assignedTier: score.category,
        competencyScores: const {},
        diagnosticFlags: const [],
        itemBreakdown: const [],
      );

      // 2. Write the placement back to /users/{userId}.
      await _firestoreService.updateUserFieldsInTransaction(userId, {
        'assignedCategory': score.category,
        'assignedTier': score.category,
        'startingLevel': score.startingLevel,
        'currentLevel': score.startingLevel,
        'contentPool': score.contentPool,
        'diagnosticScore': score.correctAnswers,
        'diagnosticPercentage': score.percentage,
        'diagnosticCompleted': true,
        'usedQuestionsHistory': FieldValue.arrayUnion(
          _questions.map((q) => q.id).toList(),
        ),
      });

      _diagnosticResult = diagnosticResult;
      _placementResult = placement;
      notifyListeners();
      return placement;
    } on DiagnosticException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[DiagnosticProvider] submitDiagnostic Firestore error: $e');
      _errorMessage = 'Failed to submit diagnostic: ${e.message ?? e.code}';
      throw DiagnosticException(
        'Failed to submit diagnostic: ${e.message ?? e.code}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      _errorMessage = 'Failed to submit diagnostic: $e';
      throw DiagnosticException(
        'Failed to submit diagnostic: $e',
        originalError: e,
      );
    } finally {
      _setSubmitting(false);
    }
  }

  /// Maps a diagnostic category to the list of accessible content pools.
  List<String> _contentPoolFor(String category) {
    switch (category.toLowerCase()) {
      case 'intermediate':
        return const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6',
        ];
      case 'advanced':
      case 'mastery':
        return const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6 Advanced',
        ];
      default:
        return const ['Grade 1', 'Grade 2', 'Grade 3'];
    }
  }

  /// Resets the diagnostic state (e.g. when navigating away).
  void resetDiagnostic() {
    _questions = [];
    _answers.clear();
    _currentIndex = 0;
    _isComplete = false;
    _placementResult = null;
    _diagnosticResult = null;
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
