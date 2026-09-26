import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/game_rules.dart';
import '../models/question.dart';
import 'rewards_service.dart';
import 'scoring_service.dart';

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
  final FirebaseFirestore _firestore;
  final ScoringService _scoringService;
  final RewardsService _rewardsService;

  DailyChallengeService({
    FirebaseFirestore? firestore,
    ScoringService? scoringService,
    RewardsService? rewardsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
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
    final docRef = _firestore.doc(dailyChallengePath(date));
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw DailyChallengeNotFoundException(date);
    }

    final data = snapshot.data()!;
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
    final docRef = _firestore.doc(studentDailyProgressPath(userId, date));
    final snapshot = await docRef.get();
    return snapshot.exists;
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
    final progressPath = studentDailyProgressPath(userId, date);
    final challengePath = dailyChallengePath(date);

    if (questions.isEmpty) {
      throw StateError('Cannot complete an empty challenge.');
    }
    if (answers.length != questions.length) {
      throw StateError(
        'Answer count (${answers.length}) does not match question count (${questions.length}).',
      );
    }

    // Score all answers using the existing ScoringService pattern.
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
        'questionId': question.id,
        'rawAnswer': rawAnswer?.toString() ?? '',
        'pointsEarned': earned,
        'maxPoints': question.maxPoints,
        'isCorrect': isCorrect,
        'competencyCode': question.competencyCode,
        'type': question.type,
      });
    }

    // Run the atomic write transaction.
    final result = await _firestore.runTransaction((transaction) async {
      // 1. Replay prevention: ensure no progress doc exists.
      final progressRef = _firestore.doc(progressPath);
      final progressSnap = await transaction.get(progressRef);
      if (progressSnap.exists) {
        throw DailyChallengeAlreadyCompletedException(date);
      }

      // 2. Read current user stats for streak resolution.
      final statsRef = _firestore.doc(statsDocumentPath(userId));
      final statsSnap = await transaction.get(statsRef);

      int currentXp = 0;
      int currentCoins = 0;
      int currentStreak = 0;
      DateTime? lastActiveDate;

      if (statsSnap.exists && statsSnap.data() != null) {
        final statsData = statsSnap.data()!;
        currentXp = (statsData['totalXp'] ?? 0) as int;
        currentCoins = (statsData['coins'] ?? 0) as int;
        currentStreak = (statsData['streakDays'] ?? 0) as int;

        final lastActive = statsData['lastActiveDate'];
        if (lastActive is Timestamp) {
          lastActiveDate = lastActive.toDate();
        } else if (lastActive is DateTime) {
          lastActiveDate = lastActive;
        }
      }

      // 3. Resolve the new streak count.
      final newStreak = _rewardsService.resolveStreak(
        currentStreak: currentStreak,
        lastActiveDate: lastActiveDate,
      );

      // 4. Compute rewards.
      //    Daily challenges are not tied to a level, so base XP/coins use
      //    the general completion constants.
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

      // 5. Write the student's daily progress document (anti-replay).
      transaction.set(progressRef, {
        'userId': userId,
        'date': dateKey,
        'challengePath': challengePath,
        'totalQuestions': questions.length,
        'correctCount': correctCount,
        'pointsEarned': totalPoints,
        'maxPoints': maxPoints,
        'accuracy': maxPoints == 0 ? 0.0 : totalPoints / maxPoints,
        'xpAwarded': xpAwarded,
        'coinsAwarded': coinsAwarded,
        'streakDays': newStreak,
        'completedAt': Timestamp.fromDate(date),
        'perQuestionResults': perQuestionResults,
      });

      // 6. Update the user's stats subdocument (streak + XP + coins).
      transaction.set(statsRef, {
        'totalXp': currentXp + xpAwarded,
        'coins': currentCoins + coinsAwarded,
        'streakDays': newStreak,
        'lastActiveDate': Timestamp.fromDate(date),
      }, SetOptions(merge: true));

      // 7. Write a session record to `student_results` for dashboards.
      final resultsRef = _firestore.collection('student_results').doc();
      final accuracy = maxPoints == 0 ? 0.0 : totalPoints / maxPoints;
      final percentage = accuracy * 100.0;
      final completionStatus = accuracy >= 0.8 ? 'passed' : 'completed';

      transaction.set(resultsRef, {
        'studentId': userId,
        'userId': userId, // Dual-write alias
        'assessmentType': AssessmentType.dailyChallenge,
        'title': 'Daily Math Challenge ($dateKey)',
        'date': dateKey,
        'score': correctCount,
        'maxScore': questions.length,
        'totalQuestions': questions.length, // Dual-write alias
        'correctCount': correctCount,
        'pointsEarned': totalPoints,
        'maxPoints': maxPoints,
        'accuracy': accuracy,
        'percentage': percentage,
        'completionStatus': completionStatus,
        'xpAwarded': xpAwarded,
        'coinsAwarded': coinsAwarded,
        'streakDays': newStreak,
        'timestamp': Timestamp.fromDate(date),
        'completedAt': Timestamp.fromDate(date), // Dual-write alias
      });

      return DailyChallengeResult(
        totalQuestions: questions.length,
        correctCount: correctCount,
        pointsEarned: totalPoints,
        maxPoints: maxPoints,
        xpAwarded: xpAwarded,
        coinsAwarded: coinsAwarded,
        streakDays: newStreak,
      );
    });

    return result;
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
