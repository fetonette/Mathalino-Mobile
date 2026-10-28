import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/errors/diagnostic_exception.dart';
import 'package:mathalino_student_app/core/models/diagnostic_result.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/diagnostic_assessment_service.dart';
import 'package:mathalino_student_app/core/services/game_logic_service.dart';
import 'package:mathalino_student_app/core/services/scoring_service.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';
import 'package:mathalino_student_app/providers/diagnostic_provider.dart';

/// SupabaseService test double: no live client. It reports a configurable
/// completion status and records whether a placement write was attempted.
class _FakeSupabaseService extends SupabaseService {
  _FakeSupabaseService(this.completionStatus) : super();

  final DiagnosticCompletionStatus completionStatus;
  int savePlacementCalls = 0;

  @override
  Future<DiagnosticCompletionStatus> resolveDiagnosticCompletion(
    String userId,
  ) async =>
      completionStatus;

  @override
  Future<void> saveDiagnosticPlacement({
    required String userId,
    required String lrn,
    required String category,
    required int startingLevel,
    required String contentPool,
    required int score,
    required double percentage,
    required List<String> usedQuestions,
    DiagnosticResult? diagnosticResult,
  }) async {
    savePlacementCalls++;
  }
}

/// Builds an in-memory provider whose question loader is satisfied offline.
DiagnosticProvider _providerWith(_FakeSupabaseService db) {
  return DiagnosticProvider(
    db: db,
    scoringService: ScoringService(),
    assessmentService: DiagnosticAssessmentService(),
    gameLogic: const GameLogicService(),
  );
}

StudentProfile _returningProfile() => const StudentProfile(
      uid: 'uid_existing',
      lrn: 'LRN0001',
      displayName: 'Returning Kid',
      gradeLevel: 4,
      assignedCategory: 'Advanced',
      assignedTier: 'Advanced',
      currentLevel: 41,
      startingLevel: 41,
      stats: StudentStats(totalXp: 900, coins: 20),
      usedQuestionsHistory: [],
      diagnosticCompleted: true,
      diagnosticPercentage: 100.0,
      contentPool: 'Grade 1-6 Shuffled',
      verificationCode: 'VC',
    );

Future<void> _answerAll(DiagnosticProvider provider) async {
  await provider.loadDiagnosticQuestions(
    userId: 'uid_existing',
    gradeLevel: 4,
    usedQuestionsHistory: const [],
  );
  // Force a full, valid 20-item attempt using the real loaded questions.
  for (var i = 0; i < provider.questions.length; i++) {
    provider.answerCurrentQuestion(provider.questions[i].correctAnswer);
  }
}

void main() {
  group('A1 — completion decision (pure evidence)', () {
    test('read failure is never treated as a new student', () {
      expect(
        resolveDiagnosticStatusFromEvidence(
          readFailed: true,
          assessmentFlag: false,
          hasDiagnosticResult: false,
        ),
        DiagnosticCompletionStatus.indeterminate,
      );
    });

    test('truthful assessment flag marks completion', () {
      expect(
        resolveDiagnosticStatusFromEvidence(
          readFailed: false,
          assessmentFlag: true,
          hasDiagnosticResult: false,
        ),
        DiagnosticCompletionStatus.completed,
      );
    });

    test('durable DIAGNOSTIC result row marks completion even without flag',
        () {
      expect(
        resolveDiagnosticStatusFromEvidence(
          readFailed: false,
          assessmentFlag: false,
          hasDiagnosticResult: true,
        ),
        DiagnosticCompletionStatus.completed,
      );
    });

    test('clean read with no evidence → new student', () {
      expect(
        resolveDiagnosticStatusFromEvidence(
          readFailed: false,
          assessmentFlag: false,
          hasDiagnosticResult: false,
        ),
        DiagnosticCompletionStatus.none,
      );
    });

    test('client-less resolve is indeterminate, never "none"', () async {
      // Default SupabaseService has no client → must NOT claim "new student".
      final status = await SupabaseService().resolveDiagnosticCompletion('u');
      expect(status, DiagnosticCompletionStatus.indeterminate);
    });
  });

  group('A1 — StudentProfile completion parsing', () {
    test('recognizes true / "true" / 1 as completed', () {
      for (final value in [true, 'true', 'TRUE', 1]) {
        final profile = StudentProfile.fromMap(
          {'diagnostic_completed': value},
          'uid',
        );
        expect(profile.diagnosticCompleted, isTrue,
            reason: 'value $value should count as completed');
      }
    });

    test('absent / false flag is not completed', () {
      expect(
        StudentProfile.fromMap({}, 'uid').diagnosticCompleted,
        isFalse,
      );
      expect(
        StudentProfile.fromMap({'diagnostic_completed': false}, 'uid')
            .diagnosticCompleted,
        isFalse,
      );
    });

    test('current_level > 1 alone is NOT proof of completion', () {
      final profile = StudentProfile.fromMap(
        {'current_level': 41, 'diagnostic_completed': false},
        'uid',
      );
      expect(profile.currentLevel, equals(41));
      expect(profile.diagnosticCompleted, isFalse);
    });
  });

  group('A3 — duplicate-submission / placement-overwrite guard', () {
    test('confirmed completed student writes nothing and yields '
        'DIAGNOSTIC_ALREADY_COMPLETED (no fabricated placement)', () async {
      final db = _FakeSupabaseService(DiagnosticCompletionStatus.completed);
      final provider = _providerWith(db);
      await _answerAll(provider);

      await expectLater(
        provider.submitDiagnostic(
          userId: 'uid_existing',
          currentProfile: _returningProfile(),
        ),
        throwsA(isA<DiagnosticException>().having(
          (e) => e.code,
          'code',
          'DIAGNOSTIC_ALREADY_COMPLETED',
        )),
      );

      expect(db.savePlacementCalls, equals(0),
          reason: 'A completed diagnostic must not be re-written');
      // No placement (fabricated or otherwise) is produced for the UI.
      expect(provider.placementResult, isNull);
      // Answers are preserved so a retry cannot lose work.
      expect(provider.isComplete, isTrue);
      expect(provider.answers.length, equals(20));
    });

    test('new student (confirmed none) DOES write placement once', () async {
      final db = _FakeSupabaseService(DiagnosticCompletionStatus.none);
      final provider = _providerWith(db);
      await _answerAll(provider);

      await provider.submitDiagnostic(
        userId: 'uid_existing',
        currentProfile: _returningProfile(),
      );

      expect(db.savePlacementCalls, equals(1));
    });

    test('indeterminate read writes nothing and yields '
        'DIAGNOSTIC_STATUS_UNCONFIRMED (retry-safe, answers preserved)',
        () async {
      final db = _FakeSupabaseService(DiagnosticCompletionStatus.indeterminate);
      final provider = _providerWith(db);
      await _answerAll(provider);

      await expectLater(
        provider.submitDiagnostic(
          userId: 'uid_existing',
          currentProfile: _returningProfile(),
        ),
        throwsA(isA<DiagnosticException>().having(
          (e) => e.code,
          'code',
          'DIAGNOSTIC_STATUS_UNCONFIRMED',
        )),
      );

      expect(db.savePlacementCalls, equals(0),
          reason: 'An unconfirmed status must not authorize an overwrite');
      expect(provider.placementResult, isNull);
      expect(provider.isComplete, isTrue);
      expect(provider.answers.length, equals(20));
    });

    test('explicit forceReassessment overrides the guard', () async {
      final db = _FakeSupabaseService(DiagnosticCompletionStatus.completed);
      final provider = _providerWith(db);
      await _answerAll(provider);

      await provider.submitDiagnostic(
        userId: 'uid_existing',
        currentProfile: _returningProfile(),
        forceReassessment: true,
      );

      expect(db.savePlacementCalls, equals(1),
          reason: 'forceReassessment is the sanctioned escape hatch');
    });
  });
}
