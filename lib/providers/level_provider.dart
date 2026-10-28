import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/question_model.dart';
import '../core/services/game_logic_service.dart';
import '../core/services/answering_timer.dart';
import '../core/services/question_bank_service.dart';
import '../core/services/supabase_service.dart';

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

  /// Preparation / Moderate levels only: the student has run out of hearts
  /// (three incorrect answers). The UI shows a supportive "Let's Practice
  /// Again!" screen offering Try Again / Back to Adventure Map. No further
  /// answers are accepted and nothing is persisted while in this phase.
  outOfHearts,
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
  final SupabaseService _supabaseService;
  final AnsweringTimer _answeringTimer;

  /// When true, database writes are skipped (used by unit tests).
  final bool _dryRun;

  /// Minimum number of preparation-range attempts required before the
  /// mastery threshold is evaluated. A single correct answer (100%) should
  /// not by itself satisfy remediation — the student must engage with at
  /// least this many practice questions so the remediation range has been
  /// meaningfully exercised. (The `isMasteryMet` function itself is left
  /// unchanged to match the reference `gameLogic.js` contract.)
  static const int _minRemediationAttempts = 4;

  /// Starting hearts for Preparation / Moderate levels. Each incorrect answer
  /// removes exactly one heart; at zero the student is routed to
  /// [PlayerPhase.outOfHearts] for a supportive retry. Challenge levels and the
  /// remediation loop ignore hearts entirely.
  static const int kMaxHearts = 3;

  LevelProvider({
    GameLogicService? gameLogic,
    QuestionBankService? questionBank,
    SupabaseService? supabaseService,
    AnsweringTimer? answeringTimer,
    this._dryRun = false,
  })  : _gameLogic = gameLogic ?? const GameLogicService(),
        _questionBank = questionBank ?? QuestionBankService(),
        _supabaseService = supabaseService ?? SupabaseService(),
        _answeringTimer = answeringTimer ?? AnsweringTimer();

  void attachFirestore(dynamic _) {} // no-op kept for call-site compatibility

  // ── Session state ────────────────────────────────────────────────────
  String _userId = '';
  String _lrn = '';
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

  /// Actual persisted reward outcome for the most recent confirmed level
  /// completion. Null until a save confirms, and cleared on a new attempt so a
  /// future Level Complete animation only ever reflects genuinely saved
  /// Stars/XP/Coins. Data-only in this step — no UI consumes it yet.
  LevelCompletionOutcome? _completionOutcome;

  /// Increments whenever a new attempt/level begins so a late async save result
  /// from an earlier attempt cannot overwrite the current outcome.
  int _completionGeneration = 0;
  int _score = 0; // number of correct answers in this level session
  int _attemptedTotal = 0; // number of answered questions in this session

  // Hearts (Preparation / Moderate levels only). Never below 0, never above
  // [kMaxHearts]. Reset at the start of every level session.
  int _hearts = kMaxHearts;

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

  /// Remaining hearts for the current level session (Preparation / Moderate).
  /// Always between 0 and [kMaxHearts]; challenge levels ignore this value.
  int get hearts => _hearts;

  /// Score shown on the completion screen and persisted for the just-completed
  /// level. Non-Challenge (Preparation / Moderate) levels report the universal
  /// three-chance score via [GameLogicService.chanceScoreForAttempts] (attempt
  /// 1/2/3 → 3/2/1); Challenge levels keep their raw correct-answer count so
  /// their existing question-based scoring is completely unchanged.
  int get completedScore => _gameLogic.isChallengeLevel(_level)
      ? _score
      : (_score == 0 ? 0 : _gameLogic.chanceScoreForAttempts(_attemptedTotal));

  /// Denominator paired with [completedScore]: the fixed
  /// [GameLogicService.kMaxChances] (3) for non-Challenge chance scoring, or the
  /// attempted-question total for Challenge levels.
  int get completedMax => _gameLogic.isChallengeLevel(_level)
      ? (_attemptedTotal > 0 ? _attemptedTotal : 1)
      : GameLogicService.kMaxChances;

  /// The confirmed persisted reward outcome for the current completion, or
  /// null when nothing has been confirmed yet. Data-only; not yet consumed by
  /// the Level Complete UI.
  LevelCompletionOutcome? get completionOutcome => _completionOutcome;

  /// The per-attempt answering timer measuring active student answering time.
  AnsweringTimer get answeringTimer => _answeringTimer;

  /// Starts the answering timer upon the first user interaction with an answer.
  /// Subsequent calls during the same attempt are no-ops.
  void recordAnswerInteraction() {
    _answeringTimer.startOnFirstInteraction();
  }

  /// Pauses the answering timer (e.g. app backgrounded/inactive).
  void pauseAnsweringTimer() {
    _answeringTimer.pause();
  }

  /// Resumes the answering timer when returning to active gameplay.
  void resumeAnsweringTimer() {
    if (!_feedbackPending &&
        (_phase == PlayerPhase.playing ||
         _phase == PlayerPhase.remediationPrep ||
         _phase == PlayerPhase.challengeRetry)) {
      _answeringTimer.resume();
    }
  }

  /// Permanently stops the answering timer for the current attempt.
  void stopAnsweringTimer() {
    _answeringTimer.stop();
  }

  /// Begins a level session for [level]. [usedHistory] is the student's
  /// existing `usedQuestionsHistory` from their profile. [seedBank] may be
  /// supplied in tests to avoid a network round-trip.
  Future<void> startLevel({
    required String userId,
    String? lrn,
    required int level,
    required List<String> usedHistory,
    List<QuestionModel>? seedBank,
  }) async {
    _userId = userId;
    _lrn = lrn ?? '';
    _level = level;
    _completionOutcome = null;
    _completionGeneration++;
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
    _hearts = kMaxHearts;
    _answeringTimer.reset();
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
    recordAnswerInteraction();
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
      // Preparation / Moderate only: remove exactly one heart (never below
      // zero). At zero hearts enter the supportive out-of-hearts state WITHOUT
      // persisting a completion or granting any reward.
      _hearts = (_hearts - 1).clamp(0, kMaxHearts);
      if (_hearts == 0) {
        _phase = PlayerPhase.outOfHearts;
        _answeringTimer.stop();
      }
      notifyListeners();
      return;
    }

    if (!_gameLogic.isChallengeLevel(_level)) {
      // Preparation level: a single CORRECT answer completes the level.
      _phase = PlayerPhase.levelComplete;
      _answeringTimer.stop();
      unawaited(_persistHistory());
      unawaited(_persistComplete());
      notifyListeners();
      return;
    }

    // Challenge level passed — resolve and advance.
    _gameLogic.resolveChallengeAttempt(level: _level, isCorrect: true);
    _phase = _level == kFinalBossLevel
        ? PlayerPhase.adventureComplete
        : PlayerPhase.levelComplete;
    _answeringTimer.stop();
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
    _answeringTimer.pause();
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
    if (_phase != PlayerPhase.levelComplete &&
        _phase != PlayerPhase.adventureComplete &&
        _phase != PlayerPhase.outOfHearts &&
        _phase != PlayerPhase.needsTeacherSupport &&
        _phase != PlayerPhase.levelFailed) {
      _answeringTimer.resume();
    }
    notifyListeners();
  }

  /// Restarts the current Preparation / Moderate level in place after the
  /// student runs out of hearts. Resets hearts to [kMaxHearts], zeroes the
  /// session score and attempted-answer counter, selects a valid question, and
  /// returns to [PlayerPhase.playing]. Performs NO database writes and grants NO
  /// rewards — it is purely an in-session retry.
  void restartLevelForHearts() {
    _hearts = kMaxHearts;
    _score = 0;
    _attemptedTotal = 0;
    _lastAnsweredQuestion = null;
    _lastCorrect = null;
    _lastSelected = null;
    _feedbackPending = false;
    _completionOutcome = null;
    _completionGeneration++;
    _answeringTimer.reset();
    final q = _gameLogic.selectQuestion(
      _bank,
      level: _level,
      usedQuestionsHistory: _usedHistory,
    );
    _currentQuestion = q?.withShuffledChoices();
    _phase = q == null ? PlayerPhase.levelFailed : PlayerPhase.playing;
    _error = q == null ? 'No available question for level $_level.' : null;
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
        _answeringTimer.stop();
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
    _answeringTimer.stop();
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
      await _supabaseService.recordUsedQuestions(
        userId: _userId,
        lrn: _lrn,
        level: _level,
        questionIds: _usedHistory,
      );
    } catch (e) {
      debugPrint('[LevelProvider] persistHistory error: $e');
    }
  }

  /// Builds the merge payload written when the current level is
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
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'levelStatus.$_level': 'completed',
      'level_status_map': {_level.toString(): 'completed'},
      'needsTeacherSupport': false,
      'needs_teacher_support': false,
      'status': 'active',
      'studentStatus': 'active',
      'remediation': null,
      'usedQuestionsHistory': _usedHistory,
      'used_questions_history': _usedHistory,
      'updated_at': now,
    };
    if (isGameComplete) {
      data['currentLevel'] = kFinalBossLevel;
      data['current_level'] = kFinalBossLevel;
      data['current'] = kFinalBossLevel;
      data['completedZones'] = ['ZONE_3'];
      data['completed_zones'] = ['ZONE_3'];
    } else {
      final next = _level + 1;
      data['currentLevel'] = next;
      data['current_level'] = next;
      data['current'] = next;
      data['levelStatus.$next'] = 'unlocked';
      data['level_status_map'] = {
        _level.toString(): 'completed',
        next.toString(): 'unlocked',
      };
    }
    return data;
  }

  Future<void> _persistComplete() async {
    if (_dryRun) return;
    try {
      final isGameComplete = _level == kFinalBossLevel;
      final nextLevel = isGameComplete ? kFinalBossLevel : _level + 1;
      final zone = _level <= 20 ? 'ZONE_1' : _level <= 40 ? 'ZONE_2' : 'ZONE_3';
      final isChallenge = _gameLogic.isChallengeLevel(_level);
      // Non-Challenge levels persist the universal three-chance score (X/3);
      // Challenge levels keep their raw correct-count / attempted denominator.
      // Star thresholds are unchanged, so the persisted stars derive to the same
      // chance score shown on screen (3/3 → 3, 2/3 → 2, 1/3 → 1).
      final outScore = completedScore;
      final outMax = completedMax;
      final accuracyPct = outMax > 0
          ? double.parse((outScore / outMax * 100).toStringAsFixed(1))
          : 0.0;

      // Capture the attempt generation + level so a late async result from an
      // earlier attempt/level can never overwrite the current one's outcome.
      final generation = _completionGeneration;
      final completionLevel = _level;

      final outcome = await _supabaseService.saveLevelCompletionWithOutcome(
        userId: _userId,
        lrn: _lrn,
        level: _level,
        nextLevel: nextLevel,
        isGameComplete: isGameComplete,
        usedQuestions: _usedHistory,
        score: outScore,
        maxScore: outMax,
        accuracyPct: accuracyPct,
        isChallenge: isChallenge,
        difficulty: difficulty,
        zone: zone,
        // Stored inside the EXISTING student_results.result_data JSONB only —
        // no schema/column/write-order change. Only new non-Challenge records
        // are tagged; historical rows and Challenge results are never touched.
        scoringMode: isChallenge ? null : 'CHANCE_OF_3',
        attemptNumber: isChallenge ? null : _attemptedTotal,
        durationSeconds: _answeringTimer.elapsedSeconds,
      );

      // Ignore a result that arrived after a newer attempt/level began.
      if (generation != _completionGeneration || completionLevel != _level) {
        return;
      }
      // Adopt the confirmed persisted outcome. A test double / unconfirmed save
      // returns saveSucceeded=false so the Level Complete UI must not animate.
      _completionOutcome = outcome;
      notifyListeners();
    } catch (e) {
      debugPrint('[LevelProvider] persistComplete error: $e');
    }
  }

  /// Persists the Needs Teacher Support escalation state to Supabase.
  Future<void> _persistTeacherSupport() async {
    if (_dryRun) return;
    try {
      final zone = _level <= 20 ? 'ZONE_1' : _level <= 40 ? 'ZONE_2' : 'ZONE_3';
      final now = DateTime.now().toIso8601String();
      final remediationMap = {
        'active': true,
        'target_level': _level,
        'cycle_count': _remediationCycleCount,
        'needs_teacher_support': true,
        'support_reason': 'Struggling with Level $_level after 3 remediation cycles',
        'updated_at': now,
      };

      await _supabaseService.saveRemediationUpdate(
        userId: _userId,
        lrn: _lrn,
        remediationData: remediationMap,
        needsTeacherSupport: true,
        status: 'needs_support',
        remediationLevel: _level,
        remediationFailedCount: _remediationCycleCount,
        zone: zone,
        difficulty: difficulty,
      );
    } catch (e) {
      debugPrint('[LevelProvider] _persistTeacherSupport error: $e');
    }
  }
}