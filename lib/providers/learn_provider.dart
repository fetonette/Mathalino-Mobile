import 'package:flutter/foundation.dart';
import '../core/models/learn_content_models.dart';
import '../core/models/student_profile.dart';
import '../core/services/learn_content_service.dart';

/// State management for the Learn section backed dynamically by Supabase.
class LearnProvider extends ChangeNotifier {
  final LearnContentService _service;

  List<TeacherPublishedModule> _publishedModules = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Legacy fields preserved for backward compatibility
  GradeLearnContent? _currentGradeContent;
  LearnContentPackage? _fullPackage;
  int? _loadedGradeLevel;

  LearnProvider({LearnContentService? service})
      : _service = service ?? LearnContentService() {
    _currentGradeContent = _service.getGradeSync(1);
    _loadedGradeLevel = 1;
  }

  List<TeacherPublishedModule> get publishedModules => _publishedModules;
  bool get hasPublishedModules => _publishedModules.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Legacy getters
  GradeLearnContent? get currentGradeContent => _currentGradeContent;
  LearnContentPackage? get fullPackage => _fullPackage;
  int? get loadedGradeLevel => _loadedGradeLevel;

  /// Loads published modules created by the authenticated student's assigned teacher(s).
  ///
  /// CRITICAL:
  /// - NO fallback to bundled Learn JSON or static curriculum categories.
  /// - Enforces teacher-ownership and enrollment via Supabase RLS.
  /// - Filters out empty modules (modules with 0 published lessons).
  /// - Distinguishes between empty state and network/auth errors.
  Future<void> loadPublishedModules({bool force = false}) async {
    if (_isInitialized && !force && _errorMessage == null && _publishedModules.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final modules = await _service.fetchPublishedTeacherModules();
      _publishedModules = List.unmodifiable(modules);
      _errorMessage = null;
      _isInitialized = true;
    } catch (e) {
      debugPrint('[LearnProvider] loadPublishedModules error: $e');
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        _errorMessage = 'Network connection failed. Please check your internet and retry.';
      } else if (msg.contains('JWT') || msg.contains('session') || msg.contains('authenticated')) {
        _errorMessage = 'Session expired. Please log in again to see your lessons.';
      } else {
        _errorMessage = 'Could not load your teacher’s lessons. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches published lessons for a specific module from Supabase.
  Future<List<PublishedLessonSummary>> fetchModuleLessons(String moduleId) async {
    return await _service.fetchPublishedModuleLessons(moduleId);
  }

  /// Fetches the published 11-part lesson sequence for a specific lesson from Supabase.
  Future<PublishedLessonDetail> fetchLessonDetail(String lessonId) async {
    return await _service.fetchPublishedLessonDetail(lessonId);
  }

  /// Refreshes the dynamic published modules from Supabase.
  Future<void> refreshPublishedModules() async {
    await loadPublishedModules(force: true);
  }

  /// Legacy loadForStudent preserved for backward compatibility if called elsewhere.
  Future<void> loadForStudent(StudentProfile? profile) async {
    await loadPublishedModules();
  }

  /// Finds a legacy module by key or name (Number Sense, Operations, Fractions, Geometry)
  LearnModule? findModule(String moduleKey) {
    return _currentGradeContent?.getModule(moduleKey);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 8: INTERACTIVE PRACTICE STATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  List<StudentPracticeQuestion>? _currentPracticeQuestions;
  bool _isPracticeLoading = false;
  String? _practiceError;
  int _currentQuestionIndex = 0;
  String? _selectedOption;
  bool _isCheckingAnswer = false;
  bool _isHintRevealed = false;
  bool _isSessionFinished = false;
  StudentPracticeAnswerResult? _lastAnswerResult;
  final Map<String, int> _questionAttempts = {};
  final Set<String> _completedQuestions = {};

  List<StudentPracticeQuestion>? get currentPracticeQuestions => _currentPracticeQuestions;
  bool get isPracticeLoading => _isPracticeLoading;
  String? get practiceError => _practiceError;
  int get currentQuestionIndex => _currentQuestionIndex;
  String? get selectedOption => _selectedOption;
  bool get isCheckingAnswer => _isCheckingAnswer;
  bool get isHintRevealed => _isHintRevealed;
  StudentPracticeAnswerResult? get lastAnswerResult => _lastAnswerResult;
  int get completedQuestionsCount => _completedQuestions.length;
  bool get isPracticeCompleted => _isSessionFinished;

  StudentPracticeQuestion? get currentQuestion {
    if (_currentPracticeQuestions == null || _currentPracticeQuestions!.isEmpty) {
      return null;
    }
    if (_currentQuestionIndex >= 0 && _currentQuestionIndex < _currentPracticeQuestions!.length) {
      return _currentPracticeQuestions![_currentQuestionIndex];
    }
    return null;
  }

  /// Loads the 5 practice questions for a published lesson.
  Future<void> loadPracticeForLesson(String lessonId) async {
    _isPracticeLoading = true;
    _practiceError = null;
    _currentPracticeQuestions = null;
    _currentQuestionIndex = 0;
    _selectedOption = null;
    _isCheckingAnswer = false;
    _isHintRevealed = false;
    _isSessionFinished = false;
    _lastAnswerResult = null;
    _questionAttempts.clear();
    _completedQuestions.clear();
    notifyListeners();

    try {
      final questions = await _service.fetchStudentPracticeQuestions(lessonId);
      _currentPracticeQuestions = List.unmodifiable(questions);
      _practiceError = null;
    } catch (e) {
      debugPrint('[LearnProvider] loadPracticeForLesson error: $e');
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        _practiceError = 'Network error. Please check your connection and retry.';
      } else if (msg.contains('not authorized') || msg.contains('enroll')) {
        _practiceError = 'You are not authorized to practice this lesson.';
      } else {
        _practiceError = 'Practice questions are currently unavailable for this lesson.';
      }
    } finally {
      _isPracticeLoading = false;
      notifyListeners();
    }
  }

  /// Selects an option for the current question.
  void selectOption(String option) {
    if (_isCheckingAnswer || (_lastAnswerResult?.isCorrect ?? false)) return;
    _selectedOption = option;
    notifyListeners();
  }

  /// Toggles visibility of the current question's hint.
  void toggleHint() {
    _isHintRevealed = !_isHintRevealed;
    notifyListeners();
  }

  /// Submits the selected option to the secure backend RPC for verification.
  Future<StudentPracticeAnswerResult?> submitAnswer(String lessonId) async {
    final question = currentQuestion;
    if (question == null || _selectedOption == null || _isCheckingAnswer) {
      return null;
    }

    _isCheckingAnswer = true;
    notifyListeners();

    try {
      final result = await _service.checkPracticeAnswer(
        lessonId: lessonId,
        questionId: question.id,
        selectedOption: _selectedOption!,
      );

      _lastAnswerResult = result;
      _questionAttempts[question.id] = (_questionAttempts[question.id] ?? 0) + 1;

      if (result.isCorrect) {
        _completedQuestions.add(question.id);
        // Non-blocking progress recording
        _service.recordPracticeProgress(
          lessonId: lessonId,
          questionsAttempted: _completedQuestions.length,
          isCompleted: _completedQuestions.length == (_currentPracticeQuestions?.length ?? 5),
        );
      }

      return result;
    } catch (e) {
      debugPrint('[LearnProvider] submitAnswer error: $e');
      _lastAnswerResult = StudentPracticeAnswerResult(
        isCorrect: false,
        feedback: 'Unable to check answer right now. Please check your connection and try again.',
        questionId: question.id,
      );
      return _lastAnswerResult;
    } finally {
      _isCheckingAnswer = false;
      notifyListeners();
    }
  }

  /// Resets selection and feedback for retry without deducting lives or score penalties.
  void retryCurrentQuestion() {
    _selectedOption = null;
    _lastAnswerResult = null;
    notifyListeners();
  }

  /// Advances to the next question in the 5-question sequence, or finishes the practice session.
  void nextQuestion(String lessonId) {
    if (_currentPracticeQuestions == null) return;
    if (_currentQuestionIndex < _currentPracticeQuestions!.length - 1) {
      _currentQuestionIndex++;
      _selectedOption = null;
      _lastAnswerResult = null;
      _isHintRevealed = false;
      notifyListeners();
    } else {
      _isSessionFinished = true;
      notifyListeners();
    }
  }

  /// Restarts the practice session from question 1.
  void resetPracticeSession() {
    _currentQuestionIndex = 0;
    _selectedOption = null;
    _lastAnswerResult = null;
    _isHintRevealed = false;
    _isSessionFinished = false;
    _questionAttempts.clear();
    _completedQuestions.clear();
    notifyListeners();
  }
}

