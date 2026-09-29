
import '../constants/game_rules.dart';
import '../models/question.dart';
import 'rewards_service.dart';
import 'scoring_service.dart';
import 'supabase_service.dart';

/// Result payload returned after completing a daily challenge.
class DailyChallengeResult {
  final int totalQuestions;
  final int correctCount;
  final int pointsEarned;
  final int maxPoints;
  final int xpAwarded;
  final int coinsAwarded;
  final int streakDays;

  const DailyChallengeResult({
    required this.totalQuestions,
    required this.correctCount,
    required this.pointsEarned,
    required this.maxPoints,
    required this.xpAwarded,
    required this.coinsAwarded,
    required this.streakDays,
  });

  double get accuracy =>
      totalQuestions == 0 ? 0.0 : correctCount / totalQuestions;
}

/// Daily Challenge Service for Mathalino Student App.
///
/// Fetches today's curated question set from `daily_challenges/{yyyy-MM-dd}`,
/// checks whether `student_daily_progress/{uid}_{yyyy-MM-dd}` already exists
/// (to prevent replay), and orchestrates atomic completion writes.
///
/// On completion:
/// - Writes a result document to `student_daily_progress/{uid}_{yyyy-MM-dd}`
/// - Updates the student's streak via `RewardsService.resolveStreak`
/// - Writes a session record to `student_results`
/// - Updates the student's stats on `/users/{uid}`
class DailyChallengeService {
  final SupabaseService _db;
  final ScoringService _scoringService;
  final RewardsService _rewardsService;

  DailyChallengeService({
    SupabaseService? db,
    ScoringService? scoringService,
    RewardsService? rewardsService,
  })  : _db = db ?? SupabaseService(),
        _scoringService = scoringService ?? ScoringService(),
        _rewardsService = rewardsService ?? RewardsService();

  /// Returns the Firestore document path for today's challenge.
  static String dailyChallengePath(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'daily_challenges/$y-$m-$d';
  }

  /// Returns the Firestore document path for a student's daily progress.
  static String studentDailyProgressPath(String userId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'student_daily_progress/${userId}_$y-$m-$d';
  }

  /// Fetches today's daily challenge questions.
  ///
  /// Throws [DailyChallengeNotFoundException] when no challenge exists for
  /// today.
  Future<List<Question>> fetchTodayChallenge({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final dateKey = _formatDateKey(date);

    final data = await _db.fetchDailyChallenge(dateKey);
    if (data == null) throw DailyChallengeNotFoundException(date);

    final rawQuestions = data['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw DailyChallengeNotFoundException(date);
    }

    return rawQuestions
        .whereType<Map<String, dynamic>>()
        .map((q) => Question.fromMap(q, q['id']?.toString() ?? ''))
        .toList();
  }

  /// Checks whether the student has already completed today's challenge.
  ///
  /// Returns `true` when a progress document already exists (replay blocked).
  Future<bool> hasCompletedToday(String userId, {DateTime? now}) async {
    final date = now ?? DateTime.now();
    final dateKey = _formatDateKey(date);
    return _db.hasCompletedDailyChallenge(userId, dateKey);
  }

  /// Completes the daily challenge and writes results atomically.
  ///
  /// [userId]        - The student's Firebase Auth UID.
  /// [questions]     - The challenge questions presented to the student.
  /// [answers]       - Raw answers aligned 1:1 with [questions].
  ///
  /// Returns a [DailyChallengeResult] with scoring, rewards, and streak info.
  ///
  /// Throws [DailyChallengeAlreadyCompletedException] when a progress
  /// document already exists for today.
  Future<DailyChallengeResult> completeChallenge({
    required String userId,
    required List<Question> questions,
    required List<dynamic> answers,
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    final dateKey = _formatDateKey(date);

    if (questions.isEmpty) throw StateError('Cannot complete an empty challenge.');
    if (answers.length != questions.length) {
      throw StateError(
        'Answer count (${answers.length}) does not match question count (${questions.length}).',
      );
    }

    // Score all answers
    var totalPoints = 0;
    var maxPoints = 0;
    var correctCount = 0;
    final perQuestionResults = <Map<String, dynamic>>[];

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final rawAnswer = answers[i];
      final earned = _scoringService.scoreQuestion(question, rawAnswer);
      final isCorrect = earned >= question.maxPoints && question.maxPoints > 0;

      totalPoints += earned;
      maxPoints += question.maxPoints;
      if (isCorrect) correctCount++;

      perQuestionResults.add({
        'question_id': question.id,
        'raw_answer': rawAnswer?.toString() ?? '',
        'points_earned': earned,
        'max_points': question.maxPoints,
        'is_correct': isCorrect,
        'competency_code': question.competencyCode,
        'type': question.type,
      });
    }

    // Replay check
    if (await _db.hasCompletedDailyChallenge(userId, dateKey)) {
      throw DailyChallengeAlreadyCompletedException(date);
    }

    // Fetch current user stats for streak resolution
    final userProfile = await _db.fetchStudentProfile(userId);
    final currentXp = userProfile?.stats.totalXp ?? 0;
    final currentCoins = userProfile?.stats.coins ?? 0;
    final currentStreak = userProfile?.stats.streakDays ?? 0;
    final lastActiveDate = userProfile?.stats.lastActiveDate;

    // Resolve streak
    final newStreak = _rewardsService.resolveStreak(
      currentStreak: currentStreak,
      lastActiveDate: lastActiveDate,
    );

    // Compute rewards
    final xpAwarded = _rewardsService.calculateXp(
      level: 1,
      correctCount: correctCount,
      totalQuestions: questions.length,
      timeSpent: Duration.zero,
      streakDays: newStreak,
    );
    final coinsAwarded = _rewardsService.calculateCoins(
      correctCount: correctCount,
      totalQuestions: questions.length,
    );

    final accuracy = maxPoints == 0 ? 0.0 : totalPoints / maxPoints;
    final percentage = accuracy * 100.0;
    final completionStatus = accuracy >= 0.8 ? 'passed' : 'completed';
    final nowIso = date.toIso8601String();

    // Write all records atomically via SupabaseService
    await _db.recordDailyChallenge(
      userId: userId,
      dateKey: dateKey,
      progressData: {
        'user_id': userId,
        'date': dateKey,
        'total_questions': questions.length,
        'correct_count': correctCount,
        'points_earned': totalPoints,
        'max_points': maxPoints,
        'accuracy': accuracy,
        'xp_awarded': xpAwarded,
        'coins_awarded': coinsAwarded,
        'streak_days': newStreak,
        'completed_at': nowIso,
        'per_question_results': perQuestionResults,
      },
      statsUpdate: {
        'total_xp': currentXp + xpAwarded,
        'coins': currentCoins + coinsAwarded,
        'streak_days': newStreak,
        'last_active_date': nowIso,
      },
      resultData: {
        'student_id': userId,
        'assessment_type': AssessmentType.dailyChallenge,
        'title': 'Daily Math Challenge ($dateKey)',
        'date': dateKey,
        'score': correctCount,
        'max_score': questions.length,
        'correct_count': correctCount,
        'points_earned': totalPoints,
        'max_points': maxPoints,
        'accuracy': accuracy,
        'percentage': percentage,
        'completion_status': completionStatus,
        'xp_awarded': xpAwarded,
        'coins_awarded': coinsAwarded,
        'streak_days': newStreak,
        'created_at': nowIso,
      },
    );

    return DailyChallengeResult(
      totalQuestions: questions.length,
      correctCount: correctCount,
      pointsEarned: totalPoints,
      maxPoints: maxPoints,
      xpAwarded: xpAwarded,
      coinsAwarded: coinsAwarded,
      streakDays: newStreak,
    );
  }

  /// Formats a [DateTime] as `yyyy-MM-dd`.
  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Thrown when no daily challenge exists for the requested date.
class DailyChallengeNotFoundException implements Exception {
  final DateTime date;
  const DailyChallengeNotFoundException(this.date);

  @override
  String toString() =>
      'No daily challenge found for ${date.year}-${date.month}-${date.day}';
}

/// Thrown when a student attempts to replay the same day's challenge.
class DailyChallengeAlreadyCompletedException implements Exception {
  final DateTime date;
  const DailyChallengeAlreadyCompletedException(this.date);

  @override
  String toString() =>
      'Daily challenge for ${date.year}-${date.month}-${date.day} already completed';
}
