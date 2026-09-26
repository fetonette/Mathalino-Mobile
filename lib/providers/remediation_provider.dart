import 'package:flutter/foundation.dart';
import '../core/constants/game_rules.dart';
import '../core/models/question.dart';
import '../core/services/remediation_service.dart';
import '../core/services/scoring_service.dart';

/// Enum representing the current phase of an active remediation session.
enum RemediationPhase {
  /// No active remediation.
  none,

  /// Student is answering preparation-range questions.
  preparation,

  /// Student has achieved mastery and is presented with the challenge question.
  challenge,

  /// Student passed the challenge question; remediation is complete.
  completed,

  /// Student failed the challenge question; remediation loops back.
  repeatFailure,

  /// Student has exceeded maximum allowed remediation cycles and requires teacher support.
  needsTeacherSupport,
}

/// Remediation Provider for Mathalino Student App.
///
/// Manages the Failure & Remediation Engine state using the `provider`
/// package (ChangeNotifier pattern), consistent with [LevelProgressProvider].
/// Exposes the current remediation phase, preparation questions, mastery
/// progress, and methods to drive the remediation flow.
class RemediationProvider extends ChangeNotifier {
  final RemediationService _remediationService;
  final ScoringService _scoringService;

  RemediationProvider({
    RemediationService? remediationService,
    ScoringService? scoringService,
  })  : _remediationService = remediationService ?? RemediationService(),
        _scoringService = scoringService ?? ScoringService();

  // --- State ---
  RemediationState _remediation = RemediationState.inactive();
  RemediationPhase _phase = RemediationPhase.none;
  List<Question> _preparationQuestions = [];
  int _currentPrepIndex = 0;
  Question? _challengeQuestion;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Getters ---
  RemediationState get remediation => _remediation;
  RemediationPhase get phase => _phase;
  List<Question> get preparationQuestions => _preparationQuestions;
  int get currentPrepIndex => _currentPrepIndex;
  Question? get challengeQuestion => _challengeQuestion;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRemediationActive => _remediation.active;

  /// Whether the student has achieved mastery and is ready for the challenge.
  bool get hasAchievedMastery =>
      _remediationService.hasAchievedMastery(_remediation);

  /// Whether the remediation has exceeded the max attempts.
  bool get hasExceededMaxAttempts =>
      _remediationService.hasExceededMaxAttempts(_remediation);

  /// The current preparation question being answered, if any.
  Question? get currentPreparationQuestion {
    if (_preparationQuestions.isEmpty) return null;
    if (_currentPrepIndex >= _preparationQuestions.length) return null;
    return _preparationQuestions[_currentPrepIndex];
  }

  /// Running mastery percentage (0.0 - 1.0).
  double get masteryScore => _remediation.masteryScore;

  /// Number of preparation attempts completed.
  int get attemptsInRange => _remediation.attemptsInRange;

  /// Whether the student has exceeded the allowed cycles and needs teacher support.
  bool get needsTeacherSupport => _remediation.needsTeacherSupport;

  /// The current remediation repeat cycle count (1-indexed).
  int get cycleCount => _remediation.cycleCount;

  // --- Public Methods ---

  /// Loads the current remediation state from Firestore for a student.
  Future<void> loadRemediation(String userId) async {
    _setLoading(true);
    try {
      _remediation = await _remediationService.getRemediationState(userId);
      if (_remediation.active) {
        _phase = _remediation.needsTeacherSupport
            ? RemediationPhase.needsTeacherSupport
            : RemediationPhase.preparation;
      } else {
        _phase = RemediationPhase.none;
      }
      _preparationQuestions = [];
      _currentPrepIndex = 0;
      _challengeQuestion = null;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[RemediationProvider] Load error: $e');
      _errorMessage = 'Failed to load remediation state';
    } finally {
      _setLoading(false);
    }
  }

  /// Starts a remediation session after a Hard/Boss level failure.
  Future<void> startRemediation({
    required String userId,
    required int failedLevel,
    required Question failedQuestion,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
  }) async {
    _setLoading(true);
    try {
      _remediation = await _remediationService.startRemediation(
        userId: userId,
        failedLevel: failedLevel,
        failedQuestion: failedQuestion,
        contentPool: contentPool,
        usedQuestionsHistory: usedQuestionsHistory,
      );
      _phase = RemediationPhase.preparation;
      _preparationQuestions = [];
      _currentPrepIndex = 0;
      _challengeQuestion = null;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[RemediationProvider] Start error: $e');
      _errorMessage = 'Failed to start remediation';
    } finally {
      _setLoading(false);
    }
  }

  /// Loads the next batch of preparation questions for the active remediation.
  Future<void> loadPreparationQuestions({
    required String userId,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
  }) async {
    if (!_remediation.active) return;

    _setLoading(true);
    try {
      _preparationQuestions = await _remediationService.getPreparationQuestions(
        userId: userId,
        remediation: _remediation,
        contentPool: contentPool,
        usedQuestionsHistory: usedQuestionsHistory,
      );
      _currentPrepIndex = 0;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[RemediationProvider] Load prep questions error: $e');
      _errorMessage = 'Failed to load preparation questions';
    } finally {
      _setLoading(false);
    }
  }

  /// Answers the current preparation question and updates mastery.
  ///
  /// Returns `true` if the student has achieved mastery and should be
  /// presented with the challenge question.
  Future<bool> answerPreparationQuestion({
    required String userId,
    required dynamic selectedAnswer,
  }) async {
    final question = currentPreparationQuestion;
    if (question == null) return false;

    // 1. Record the answer and update the running mastery.
    _remediation = _remediationService.recordPreparationAnswer(
      question: question,
      selectedAnswer: selectedAnswer,
      remediation: _remediation,
    );

    // 2. Persist the updated remediation state.
    await _remediationService.updateRemediationState(
      userId: userId,
      remediation: _remediation,
    );

    // 3. Record the result in student_results.
    final pointsEarned = _scoringService.scoreQuestion(question, selectedAnswer);
    await _remediationService.recordRemediationResult(
      userId: userId,
      targetLevel: _remediation.targetLevel,
      assessmentType: AssessmentType.challengeRemediation,
      score: pointsEarned > 0 ? 1 : 0,
      totalQuestions: 1,
      competencyCode: question.competencyCode,
    );

    // 4. Advance to the next preparation question.
    if (_currentPrepIndex < _preparationQuestions.length - 1) {
      _currentPrepIndex++;
    }

    // 5. Check mastery / max attempts.
    if (hasAchievedMastery) {
      _phase = RemediationPhase.challenge;
      notifyListeners();
      return true;
    }

    if (hasExceededMaxAttempts) {
      // Loop back: reset attempts and mastery, keep same target level.
      _remediation = await _remediationService.repeatFailure(
        userId: userId,
        remediation: _remediation,
      );
      _phase = _remediation.needsTeacherSupport
          ? RemediationPhase.needsTeacherSupport
          : RemediationPhase.repeatFailure;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return false;
  }

  /// Loads the NEW challenge question for the target level.
  Future<void> loadChallengeQuestion({
    required String userId,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
  }) async {
    if (!_remediation.active) return;

    _setLoading(true);
    try {
      _challengeQuestion = await _remediationService.getChallengeQuestion(
        userId: userId,
        remediation: _remediation,
        contentPool: contentPool,
        usedQuestionsHistory: usedQuestionsHistory,
      );
      _phase = RemediationPhase.challenge;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[RemediationProvider] Load challenge error: $e');
      _errorMessage = 'Failed to load challenge question';
    } finally {
      _setLoading(false);
    }
  }

  /// Answers the challenge question.
  ///
  /// On success, completes the remediation and unlocks the next level.
  /// On failure, loops back to preparation (repeat failure).
  Future<bool> answerChallengeQuestion({
    required String userId,
    required dynamic selectedAnswer,
  }) async {
    final question = _challengeQuestion;
    if (question == null) return false;

    final pointsEarned = _scoringService.scoreQuestion(question, selectedAnswer);
    final isCorrect = pointsEarned > 0;

    // Record the challenge result.
    await _remediationService.recordRemediationResult(
      userId: userId,
      targetLevel: _remediation.targetLevel,
      assessmentType: AssessmentType.challengeRemediation,
      score: isCorrect ? 1 : 0,
      totalQuestions: 1,
      competencyCode: question.competencyCode,
    );

    if (isCorrect) {
      // Success: complete remediation and unlock next level.
      await _remediationService.completeRemediation(
        userId: userId,
        remediation: _remediation,
      );
      _remediation = RemediationState.inactive();
      _phase = RemediationPhase.completed;
      _challengeQuestion = null;
      notifyListeners();
      return true;
    } else {
      // Failure: loop back to preparation or escalate to teacher support.
      _remediation = await _remediationService.repeatFailure(
        userId: userId,
        remediation: _remediation,
      );
      _phase = _remediation.needsTeacherSupport
          ? RemediationPhase.needsTeacherSupport
          : RemediationPhase.repeatFailure;
      _challengeQuestion = null;
      notifyListeners();
      return false;
    }
  }

  /// Clears the remediation state locally (e.g. after navigating away).
  void clearRemediation() {
    _remediation = RemediationState.inactive();
    _phase = RemediationPhase.none;
    _preparationQuestions = [];
    _currentPrepIndex = 0;
    _challengeQuestion = null;
    _errorMessage = null;
    notifyListeners();
  }

  // --- Private Helpers ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}