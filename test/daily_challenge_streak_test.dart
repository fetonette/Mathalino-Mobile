import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/daily_challenge_service.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';

/// SupabaseService test double: no live client. It reports a configurable
/// Daily-Challenge anchor and records the stats written on completion so the
/// streak logic can be asserted deterministically.
class _FakeDb extends SupabaseService {
  _FakeDb({
    this.streakDays = 0,
    this.totalXp = 0,
    this.coins = 0,
    this.profileLastActive,
    this.anchor = const DailyChallengeAnchor(DailyChallengeAnchorSource.none),
    this.alreadyCompleted = false,
  }) : super();

  final int streakDays;
  final int totalXp;
  final int coins;

  /// The gameplay-written last-active date carried on the profile. Tests set
  /// this to a recent day to prove it can NOT advance the daily streak.
  final DateTime? profileLastActive;

  final DailyChallengeAnchor anchor;
  final bool alreadyCompleted;

  int recordCalls = 0;
  Map<String, dynamic>? lastStatsUpdate;
  Map<String, dynamic>? lastProgressData;

  @override
  Future<StudentProfile?> fetchStudentProfile(String userId) async =>
      StudentProfile(
        uid: userId,
        lrn: '123456789012',
        displayName: 'Test',
        gradeLevel: 3,
        assignedCategory: 'Beginner',
        currentLevel: 1,
        startingLevel: 1,
        stats: StudentStats(
          totalXp: totalXp,
          coins: coins,
          streakDays: streakDays,
          lastActiveDate: profileLastActive,
        ),
        usedQuestionsHistory: const [],
        diagnosticCompleted: true,
        verificationCode: 'MTH-0000',
      );

  @override
  Future<bool> hasCompletedDailyChallenge(
    String userId,
    String dateKey,
  ) async =>
      alreadyCompleted;

  @override
  Future<DailyChallengeAnchor> fetchLastDailyChallengeDate({
    required String userId,
    required String todayKey,
  }) async =>
      anchor;

  @override
  Future<void> recordDailyChallenge({
    required String userId,
    required String dateKey,
    required Map<String, dynamic> progressData,
    required Map<String, dynamic> statsUpdate,
    required Map<String, dynamic> resultData,
  }) async {
    recordCalls++;
    lastProgressData = progressData;
    lastStatsUpdate = statsUpdate;
  }
}

List<Question> _questions() => const [
      Question(
        id: 'Q1',
        grade: 3,
        contentDomain: 'Numbers',
        competencyCode: 'N1',
        competencyText: 'Add',
        cognitiveDomain: 'Knowing',
        type: 'multipleChoice',
        questionText: '1 + 1 = ?',
        choices: ['2', '3'],
        correctAnswer: '2',
        maxPoints: 1,
      ),
    ];

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _daysAgo(int d) => _today().subtract(Duration(days: d));

void main() {
  group('Daily Challenge streak anchoring', () {
    test('first-ever Daily Challenge starts the streak at 1', () async {
      final db = _FakeDb(
        streakDays: 0,
        anchor: const DailyChallengeAnchor(DailyChallengeAnchorSource.none),
      );
      final svc = DailyChallengeService(db: db);
      final res = await svc.completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 1);
      expect(db.lastStatsUpdate?['streak_days'], 1);
    });

    test('consecutive day (yesterday) increments 1 -> 2 -> 3', () async {
      // Day 2: last daily completion was yesterday, current streak 1.
      final day2 = _FakeDb(
        streakDays: 1,
        anchor: DailyChallengeAnchor(
          DailyChallengeAnchorSource.found,
          _daysAgo(1),
        ),
      );
      final r2 = await DailyChallengeService(db: day2).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(r2.streakDays, 2);

      // Day 3: last daily completion yesterday, current streak 2.
      final day3 = _FakeDb(
        streakDays: 2,
        anchor: DailyChallengeAnchor(
          DailyChallengeAnchorSource.found,
          _daysAgo(1),
        ),
      );
      final r3 = await DailyChallengeService(db: day3).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(r3.streakDays, 3);
    });

    test('missed days (gap > 1) reset the streak to 1', () async {
      final db = _FakeDb(
        streakDays: 6,
        anchor: DailyChallengeAnchor(
          DailyChallengeAnchorSource.found,
          _daysAgo(3),
        ),
      );
      final res = await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 1);
    });

    test('ordinary gameplay between Daily Challenges cannot advance streak',
        () async {
      // students.stats.lastActive is fresh (today, from Adventure Map play) but
      // there is NO prior Daily Challenge completion -> streak must be 1, not 2.
      final db = _FakeDb(
        streakDays: 0,
        profileLastActive: _today(),
        anchor: const DailyChallengeAnchor(DailyChallengeAnchorSource.none),
      );
      final res = await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 1);
    });

    test('yesterday gameplay with no prior Daily Challenge does not increment',
        () async {
      // Gameplay yesterday would look "consecutive", but with no daily record
      // this is still the first Daily Challenge -> 1.
      final db = _FakeDb(
        streakDays: 5,
        profileLastActive: _daysAgo(1),
        anchor: const DailyChallengeAnchor(DailyChallengeAnchorSource.none),
      );
      final res = await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 1);
    });

    test('the Daily-Challenge record, not gameplay, drives the increment',
        () async {
      // No gameplay date at all (profile.lastActive null), but a prior daily
      // challenge yesterday -> streak legitimately advances.
      final db = _FakeDb(
        streakDays: 1,
        profileLastActive: null,
        anchor: DailyChallengeAnchor(
          DailyChallengeAnchorSource.found,
          _daysAgo(1),
        ),
      );
      final res = await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 2);
    });

    test('unreadable history never downgrades a known streak', () async {
      final db = _FakeDb(
        streakDays: 4,
        anchor: const DailyChallengeAnchor(DailyChallengeAnchorSource.unreadable),
      );
      final res = await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(res.streakDays, 4);
      expect(db.lastStatsUpdate?['streak_days'], 4);
    });

    test('same-day replay is blocked and writes nothing', () async {
      final db = _FakeDb(alreadyCompleted: true);
      final svc = DailyChallengeService(db: db);
      await expectLater(
        () => svc.completeChallenge(
          userId: 'u1',
          questions: _questions(),
          answers: const ['2'],
          now: _today(),
        ),
        throwsA(isA<DailyChallengeAlreadyCompletedException>()),
      );
      expect(db.recordCalls, 0);
    });
  });

  group('Daily Challenge completion writes', () {
    test('records the daily-progress date and preserves reward keys, without a '
        'last_active_date gameplay write', () async {
      final db = _FakeDb(
        streakDays: 1,
        totalXp: 100,
        coins: 20,
        anchor: DailyChallengeAnchor(
          DailyChallengeAnchorSource.found,
          _daysAgo(1),
        ),
      );
      await DailyChallengeService(db: db).completeChallenge(
        userId: 'u1',
        questions: _questions(),
        answers: const ['2'],
        now: _today(),
      );
      expect(db.recordCalls, 1);
      // The per-day record that future reads use as the anchor.
      expect(db.lastProgressData?['date'], isNotNull);
      // Stats carry the resolved streak + additive rewards, and NO dropped
      // gameplay-style last_active_date field.
      expect(db.lastStatsUpdate?['streak_days'], 2);
      expect(db.lastStatsUpdate?.containsKey('last_active_date'), isFalse);
      expect(db.lastStatsUpdate?['total_xp'], greaterThan(100));
      expect(db.lastStatsUpdate?['coins'], greaterThan(20));
    });
  });

  group('SupabaseService.fetchLastDailyChallengeDate (no client)', () {
    test('client-less read is unreadable, never a false "none"', () async {
      final anchor = await SupabaseService().fetchLastDailyChallengeDate(
        userId: 'u1',
        todayKey: '2026-01-01',
      );
      expect(anchor.source, DailyChallengeAnchorSource.unreadable);
      expect(anchor.date, isNull);
    });

    test('empty user id is treated as unreadable', () async {
      final anchor = await SupabaseService().fetchLastDailyChallengeDate(
        userId: '',
        todayKey: '2026-01-01',
      );
      expect(anchor.source, DailyChallengeAnchorSource.unreadable);
    });
  });
}
