import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/models/question_model.dart';
import '../core/services/game_logic_service.dart';
import '../core/services/question_bank_service.dart';

/// The phase of the current Beginner Zone level session.
enum PlayerPhase {
  idle,
  loading,

  /// Showing a question for a non-remediation situation (a normal/single
  /// level question or the initial challenge question).
  playing,

  /// Student is answering preparation-range questions during remediation.
  remediationPrep,

  /// Student has reached mastery and is answering a NEW challenge question.
  challengeRetry,

  /// Level was completed (next level unlocked).
  levelComplete,

  /// The entire 60-level game was completed (Level 60 passed). The UI shows an
  /// "Adventure Complete" screen instead of routing to a non-existent
  /// Level 61.
  adventureComplete,

  /// No eligible question could be resolved for the level.
  levelFailed,

  /// Student has exceeded maximum allowed remediation cycles and requires teacher support.
  needsTeacherSupport,
}

/// Drives a single level session on the Adventure Map for Zones 1–3
/// (Levels 1–60) using the new [QuestionBankService] + [GameLogicService]
/// engine.
///
/// Behaviour mirrors `tools/question-bank/gameLogic.js`:
///   * On entering a level, one eligible question is selected via
///     [GameLogicService.selectQuestion] (Fisher-Yates), honouring the
///     student's `usedQuestionsHistory`.
///   * Non-challenge (Preparation / Moderate) levels advance on a correct
///     answer; wrong answers repeat the same question (standard retry).
///   * Challenge levels resolve via [GameLogicService.resolveChallengeAttempt].
///     A failure starts the remediation loop: the student practises NEW
///     questions from the preparation range until mastery (75%,
///     [GameLogicService.isMasteryMet]), then receives a NEW challenge
///     question via [GameLogicService.selectNewChallengeQuestion].
///   * The Intermediate zone (Levels 21–40) has NO challenge levels, so no
///     remediation loop can ever start there.
class LevelProvider extends ChangeNotifier {
  final GameLogicService _gameLogic;
  final QuestionBankService _questionBank;

    /// When true, Firestore writes are skipped (used by unit tests).
  final bool _dryRun;

  /// Minimum number of preparation-range attempts required before the
  /// mastery threshold is evaluated. A single correct answer (100%) should
  /// not by itself satisfy remediation — the student must engage with at
  /// least this many practice questions so the remediation range has been
  /// meaningfully exercised. (The `isMasteryMet` function itself is left
  /// unchanged to match the reference `gameLogic.js` contract.)
  static const int _minRemediationAttempts = 4;

  LevelProvider({
    GameLogicService? gameLogic,
    QuestionBankService? questionBank,
    this._dryRun = false,
  })  : _gameLogic = gameLogic ?? const GameLogicService(),
        _questionBank = questionBank ?? QuestionBankService();

  /// Injected Firestore for persistence (only used when !_dryRun).
  FirebaseFirestore? _firestore;

  void attachFirestore(FirebaseFirestore firestore) => _firestore = firestore;

  // ── Session state ────────────────────────────────────────────────────
  String _userId = '';
  int _level = 1;
  PlayerPhase _phase = PlayerPhase.idle;
  bool _isLoading = false;
  String? _error;

  QuestionModel? _currentQuestion;
  List<QuestionModel> _bank = const [];
  List<String> _usedHistory = const [];

  // Remediation (challenge failures only).
  List<int> _preparationRange = const [];
  int _correctPrep = 0;
  int _attemptedPrep = 0;
  String? _failedChallengeId;
  int _remediationCycleCount = 1;
  bool _needsTeacherSupport = false;

  // Answer-feedback + session scoring.
  QuestionModel? _lastAnsweredQuestion;
  bool? _lastCorrect;
  dynamic _lastSelected;
  bool _feedbackPending = false;
  int _score = 0; // number of correct answers in this level session
  int _attemptedTotal = 0; // number of answered questions in this session

  // ── Getters ──────────────────────────────────────────────────────────
  String get userId => _userId;
  int get level => _level;
  PlayerPhase get phase => _phase;
  bool get isLoading => _isLoading;
  String get difficulty => _gameLogic.getDifficulty(_level);
  bool get isChallengeLevel => _gameLogic.isChallengeLevel(_level);
  int get remediationCycleCount => _remediationCycleCount;
  bool get needsTeacherSupport => _needsTeacherSupport;
  String? get error => _error;
  QuestionModel? get currentQuestion => _currentQuestion;

  /// True once the final-boss (Level 60) has been completed. The UI should
  /// show the "Adventure Complete" screen rather than a next-level transition.
  bool get isGameComplete =>
      _level == kFinalBossLevel && _phase == PlayerPhase.adventureComplete;
  List<int> get preparationRange => _preparationRange;
  int get correctPrep => _correctPrep;
  int get attemptedPrep => _attemptedPrep;
  double get masteryPercentage =>
      _attemptedPrep == 0 ? 0.0 : (_correctPrep / _attemptedPrep) * 100;
  bool get inRemediation =>
      _phase == PlayerPhase.remediationPrep ||
      _phase == PlayerPhase.challengeRetry;

  // ── Answer-feedback + session scoring getters ──────────────────────
  /// True immediately after an answer until the student acknowledges it.
  bool get feedbackPending => _feedbackPending;

  /// The question that was just answered (used to render feedback).
  QuestionModel? get lastAnsweredQuestion => _lastAnsweredQuestion;

  /// Whether the most recent answer was correct (null before any answer).
  bool? get lastCorrect => _lastCorrect;

  /// The choice key/label the student most recently selected.
  dynamic get lastSelected => _lastSelected;

  /// Number of correct answers in the current level session.
  int get score => _score;

  /// Total number of questions answered in the current level session.
  int get attemptedTotal => _attemptedTotal;

  /// Begins a level session for [level]. [usedHistory] is the student's
  /// existing `usedQuestionsHistory` from their profile. [seedBank] may be
  /// supplied in tests to avoid a Firestore round-trip.
  Future<void> startLevel({
    required String userId,
    required int level,
    required List<String> usedHistory,
    List<QuestionModel>? seedBank,
  }) async {
    _userId = userId;
    _level = level;
    _usedHistory = List.of(usedHistory);
    _preparationRange = const [];
    _correctPrep = 0;
    _attemptedPrep = 0;
    _failedChallengeId = null;
    _remediationCycleCount = 1;
    _needsTeacherSupport = false;
    _lastAnsweredQuestion = null;
    _lastCorrect = null;
    _lastSelected = null;
    _feedbackPending = false;
    _score = 0;
    _attemptedTotal = 0;
    _isLoading = true;
    notifyListeners();
    try {
      _bank = seedBank ?? await _questionBank.fetchQuestionBank();
      final q = _gameLogic.selectQuestion(
        _bank,
        level: level,
        usedQuestionsHistory: _usedHistory,
      );
      _currentQuestion = q?.withShuffledChoices();
      _phase = q == null ? PlayerPhase.levelFailed : PlayerPhase.playing;
      _error = q == null ? 'No available question for level $level.' : null;
    } catch (e) {
      _error = 'Failed to load level: $e';
      _phase = PlayerPhase.levelFailed;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// The single entry point the screen uses when an answer is submitted.
  Future<void> submitAnswer(dynamic selected) async {
    switch (_phase) {
      case PlayerPhase.remediationPrep:
        return submitPrepAnswer(selected);
      case PlayerPhase.challengeRetry:
        return submitRetryAnswer(selected);
      case PlayerPhase.playing:
        return submitPlayingAnswer(selected);
      default:
        return;
    }
  }

  // ── Answer handling ──────────────────────────────────────────────────

  /// Handles an answer while in [PlayerPhase.playing] (normal level question
  /// or the initial challenge question).
  Future<void> submitPlayingAnswer(dynamic selected) async {
    final q = _currentQuestion;
    if (q == null) return;
    final isCorrect = _recordAnswerFeedback(q, selected);
    _usedHistory = [..._usedHistory, q.questionId];

    // A wrong answer on a non-challenge level re-presents the question.
    // On a challenge level, failing initiates the remediation loop!
    if (!isCorrect) {
      if (_gameLogic.isChallengeLevel(_level)) {
        _failedChallengeId = q.questionId;
        await _startRemediation();
        return;
      }
      notifyListeners();
      return;
    }

    if (!_gameLogic.isChallengeLevel(_level)) {
      // Preparation level: a single CORRECT answer completes the level.
      _phase = PlayerPhase.levelComplete;
      notifyListeners();
      unawaited(_persistHistory());
      return;
    }

    // Challenge level passed — resolve and advance.
    _gameLogic.resolveChallengeAttempt(level: _level, isCorrect: true);
    _phase = _level == kFinalBossLevel
        ? PlayerPhase.adventureComplete
        : PlayerPhase.levelComplete;
    unawaited(_persistComplete());
    notifyListeners();
  }

  /// Enters (or re-enters) the remediation preparation loop for the current
  /// [_level]. Resets mastery counters, derives the preparation range from
  /// [GameLogicService.getPreparationRange], and picks the first prep question.
  ///
  /// Called both on the initial challenge failure ([submitPlayingAnswer]) and
  /// when the student fails the retry challenge ([submitRetryAnswer]), so the
  /// entire remediation cycle can repeat as many times as needed per §13.7.
  Future<void> _startRemediation() async {
    try {
      final prep = _gameLogic.getPreparationRange(_level);
      _preparationRange = prep.range;
      _correctPrep = 0;
      _attemptedPrep = 0;
      await _pickPrepQuestion();
    } catch (e) {
      // getPreparationRange throws for levels that have no gate (e.g. Zone 2).
      // This should not normally happen because isChallengeLevel guards all
      // call sites, but we log and surface the error defensively.
      debugPrint('[LevelProvider] _startRemediation error for level $_level: $e');
      _error = 'Cannot start remediation for level $_level: $e';
      _phase = PlayerPhase.levelFailed;
      notifyListeners();
    }
  }

/// Records the last answer's correctness and updates the session score.
  /// Returns whether the answer was correct so callers can branch on it.
  bool _recordAnswerFeedback(QuestionModel q, dynamic selected) {
    final correct = q.isCorrect(selected);
    _lastAnsweredQuestion = q;
    _lastSelected = selected;
    _lastCorrect = correct;
    _feedbackPending = true;
    _attemptedTotal += 1;
    if (correct) _score += 1;
    return correct;
  }

  /// Called when the student acknowledges the answer feedback. Clears the
  /// pending-feedback record so the underlying next state (level complete,
  /// next remediation question, challenge retry, …) is revealed.
  void dismissFeedback() {
    _lastAnsweredQuestion = null;
    _lastCorrect = null;
    _lastSelected = null;
    _feedbackPending = false;
    notifyListeners();
  }
  Future<void> _pickPrepQuestion() async {
    final q = _gameLogic.selectRemediationQuestion(
      _bank,
      preparationRange: _preparationRange,
      usedQuestionsHistory: _usedHistory,
    );
    _currentQuestion = q?.withShuffledChoices();
    _phase = q == null ? PlayerPhase.levelFailed : PlayerPhase.remediationPrep;
    notifyListeners();
  }

  /// Submits a preparation-range answer. A correct answer advances; an
  /// incorrect answer repeats the SAME question (never advancing) until the
  /// student answers correctly.
  Future<void> submitPrepAnswer(dynamic selected) async {
    final q = _currentQuestion;
    if (q == null) return;
    final isCorrect = _recordAnswerFeedback(q, selected);

    // Wrong answer: do not count/advance — repeat the same question.
    if (!isCorrect) {
      notifyListeners();
      return;
    }

    // Correct answer: this prep question counts toward mastery, then we move
    // to a NEW prep question (or, once mastered, a NEW challenge question).
    _usedHistory = [..._usedHistory, q.questionId];
    _correctPrep += 1;
    _attemptedPrep += 1;

    // Fire-and-forget the history write so a slow network call never freezes
    // the remediation flow.
    unawaited(_persistHistory());

    if (_attemptedPrep >= _minRemediationAttempts &&
        _gameLogic.isMasteryMet(_correctPrep, _attemptedPrep)) {
      final retry = _gameLogic.selectNewChallengeQuestion(
        _bank,
        level: _level,
        excludeQuestionId: _failedChallengeId ?? '',
        usedQuestionsHistory: _usedHistory,
      );
      _currentQuestion = retry?.withShuffledChoices();
      _phase =
          retry == null ? PlayerPhase.levelFailed : PlayerPhase.challengeRetry;
      notifyListeners();
      return;
    }

    // Exceeded maximum preparation attempts (10) without achieving 75% mastery:
    if (_attemptedPrep >= 10) {
      _remediationCycleCount += 1;
      if (_remediationCycleCount > 3) {
        _needsTeacherSupport = true;
        _phase = PlayerPhase.needsTeacherSupport;
        notifyListeners();
        unawaited(_persistTeacherSupport());
        return;
      }
      await _startRemediation();
      return;
    }

    await _pickPrepQuestion();
  }

  /// Submits the challenge retry answer after remediation mastery.
  ///
  /// * Correct  → level complete (next level unlocked).
  /// * Incorrect → loops back to the preparation range with NEW questions
  ///   per Spec §13.7 ("repeat remediation cycle"). The failed retry question
  ///   ID is added to [_usedHistory] so it is excluded from future selections.
  Future<void> submitRetryAnswer(dynamic selected) async {
    final q = _currentQuestion;
    if (q == null) return;
    final isCorrect = _recordAnswerFeedback(q, selected);
    _usedHistory = [..._usedHistory, q.questionId];

    if (!isCorrect) {
      // ── Spec §13.7: "repeat remediation cycle" ─────────────────────────
      // Increment cycle count. If cycle count exceeds limit (3 cycles),
      // transition to Needs Teacher Support instead of looping endlessly.
      _remediationCycleCount += 1;
      if (_remediationCycleCount > 3) {
        _needsTeacherSupport = true;
        _phase = PlayerPhase.needsTeacherSupport;
        notifyListeners();
        unawaited(_persistTeacherSupport());
        return;
      }
      await _startRemediation();
      return;
    }

    _phase = _level == kFinalBossLevel
        ? PlayerPhase.adventureComplete
        : PlayerPhase.levelComplete;
    notifyListeners();
    unawaited(_persistHistory());
    unawaited(_persistComplete());
  }

      // ── Persistence (skipped in dry-run / tests) ─────────────────────────

  /// Public error setter so the UI can surface failures from async callbacks.
  void setError(String message) {
    _error = message;
    _phase = PlayerPhase.levelFailed;
    notifyListeners();
  }

  Future<void> _persistHistory() async {
    if (_dryRun) return;
    try {
      await _firestore?.collection('users').doc(_userId).update({
        'usedQuestionsHistory': FieldValue.arrayUnion(_usedHistory),
      });

      // Dual-write to /student_progress/{uid}
      await _firestore?.collection('student_progress').doc(_userId).set({
        'usedQuestionsHistory': FieldValue.arrayUnion(_usedHistory),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LevelProvider] persistHistory error: $e');
    }
  }

  /// Builds the Firestore merge payload written when the current level is
  /// completed.
  ///
  /// For Levels 1–59 it marks the completed level `completed` and unlocks the
  /// next. For Level 60 (final boss) it keeps `currentLevel` at 60, marks
  /// Level 60 `completed`, and records the `ZONE_3` milestone so the Adventure
  /// Map shows the fully-completed state (without this, `getLevelState` would
  /// keep rendering Level 60 as an unfinished challenge).
  @visibleForTesting
  Map<String, dynamic> buildCompletePayload() {
    final isGameComplete = _level == kFinalBossLevel;
    // The level just completed must be marked 'completed' — otherwise the
    // Adventure Map's getLevelState() sees an 'unlocked' status on a boss
    // level and renders it as an unfinished challenge forever. (Levels 1-59
    // were only masked because currentLevel advances past them; Level 60 can
    // never advance, so this is the only record that marks it finished.)
    final data = <String, dynamic>{
      'levelStatus.$_level': 'completed',
      'needsTeacherSupport': false,
      'status': 'active',
      'studentStatus': 'active',
      'remediation': FieldValue.delete(),
      'usedQuestionsHistory': FieldValue.arrayUnion(_usedHistory),
    };
    if (isGameComplete) {
      // Final boss: keep currentLevel clamped at 60 and record the milestone.
      data['currentLevel'] = kFinalBossLevel;
      data['current'] = kFinalBossLevel;
      data['completedZones'] = FieldValue.arrayUnion(['ZONE_3']);
    } else {
      final next = _level + 1;
      data['currentLevel'] = next;
      data['current'] = next;
      data['levelStatus.$next'] = 'unlocked';
    }
    return data;
  }

  Future<void> _persistComplete() async {
    if (_dryRun) return;
    try {
      final userRef = _firestore?.collection('users').doc(_userId);
      if (userRef == null) return;

      final payload = buildCompletePayload();

      // 1. Update the student profile (currentLevel, levelStatus, zones) on /users/{uid}.
      await userRef.set(
        payload,
        SetOptions(merge: true),
      );

      // 1b. Dual-write to /student_progress/{uid}
      try {
        await _firestore?.collection('student_progress').doc(_userId).set(
          {
            ...payload,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (err) {
        debugPrint('[LevelProvider] student_progress dual-write error: $err');
      }

      // 2. Write a per-level result record so the teacher dashboard's Progress
      //    Report view can show a real activity timeline and accuracy history.
      //    Path: /users/{uid}/levelResults/{auto-id}
      final zone = _level <= 20
          ? 'ZONE_1'
          : _level <= 40
              ? 'ZONE_2'
              : 'ZONE_3';
      final accuracyPct = _attemptedTotal > 0
          ? double.parse(
              (_score / _attemptedTotal * 100).toStringAsFixed(1))
          : 0.0;

      await userRef.collection('levelResults').add({
        'levelNumber':    _level,
        'zone':           zone,
        'isChallenge':    _gameLogic.isChallengeLevel(_level),
        'score':          _score,
        'totalQuestions': _attemptedTotal,
        'accuracyPct':    accuracyPct,
        'completedAt':    FieldValue.serverTimestamp(),
      });

      // 3. Write a unified record to /student_results
      final isChallenge = _gameLogic.isChallengeLevel(_level);
      final assessmentType = isChallenge ? 'LEVEL_CHALLENGE' : 'LEVEL_PRACTICE';
      final title = isChallenge ? 'Level $_level Challenge' : 'Level $_level Practice';

      await _firestore?.collection('student_results').add({
        'studentId':       _userId,
        'userId':          _userId, // Dual-write alias
        'assessmentType':  assessmentType,
        'title':           title,
        'levelNumber':     _level,
        'zone':            zone,
        'difficulty':      difficulty,
        'score':           _score,
        'maxScore':        _attemptedTotal,
        'totalQuestions':  _attemptedTotal, // Dual-write alias
        'percentage':      accuracyPct,
        'accuracy':        _attemptedTotal > 0 ? _score / _attemptedTotal : 0.0,
        'completionStatus':'completed',
        'attemptNumber':   1,
        'timestamp':       FieldValue.serverTimestamp(),
        'completedAt':     FieldValue.serverTimestamp(), // Dual-write alias
      });
    } catch (e) {
      debugPrint('[LevelProvider] persistComplete error: $e');
    }
  }

  /// Persists the Needs Teacher Support escalation state to Firestore.
  Future<void> _persistTeacherSupport() async {
    if (_dryRun) return;
    try {
      final userRef = _firestore?.collection('users').doc(_userId);
      if (userRef == null) return;

      final payload = <String, dynamic>{
        'needsTeacherSupport': true,
        'status': 'needs_support',
        'studentStatus': 'needs_support',
        'remediation': {
          'active': true,
          'targetLevel': _level,
          'cycleCount': _remediationCycleCount,
          'needsTeacherSupport': true,
          'supportReason': 'Struggling with Level $_level after 3 remediation cycles',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      await userRef.set(payload, SetOptions(merge: true));

      // Dual-write to /student_progress/{uid}
      await _firestore?.collection('student_progress').doc(_userId).set(
        {
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Audit log in student_results
      final zone = _level <= 20
          ? 'ZONE_1'
          : _level <= 40
              ? 'ZONE_2'
              : 'ZONE_3';

      await _firestore?.collection('student_results').add({
        'studentId':        _userId,
        'userId':           _userId,
        'assessmentType':   'REMEDIATION_SUPPORT_NEEDED',
        'title':            'Remediation Alert: Teacher Support Needed (Level $_level)',
        'levelNumber':      _level,
        'zone':             zone,
        'difficulty':       difficulty,
        'score':            0,
        'maxScore':         1,
        'totalQuestions':   1,
        'percentage':       0.0,
        'accuracy':         0.0,
        'completionStatus': 'needs_support',
        'attemptNumber':    _remediationCycleCount,
        'timestamp':        FieldValue.serverTimestamp(),
        'completedAt':      FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[LevelProvider] _persistTeacherSupport error: $e');
    }
  }
}