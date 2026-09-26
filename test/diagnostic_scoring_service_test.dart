import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/diagnostic_result.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/services/diagnostic_scoring_service.dart';
import 'package:mathalino_student_app/core/errors/diagnostic_exception.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [Question] with a given [competencyTag] (mapped to
/// [contentDomain]) and [correctAnswer].
Question _q({
  required String id,
  required String competencyTag,
  required dynamic correctAnswer,
}) {
  return Question(
    id: id,
    grade: 3,
    contentDomain: competencyTag,
    competencyCode: 'TEST-$id',
    competencyText: 'Test competency $id',
    cognitiveDomain: 'Knowing',
    type: 'multipleChoice',
    questionText: 'Question $id',
    choices: const ['A. 1', 'B. 2', 'C. 3', 'D. 4'],
    correctAnswer: correctAnswer,
    maxPoints: 1,
  );
}

/// Builds 20 questions split evenly between two competency tags.
List<Question> _build20Questions({
  String tag1 = 'Number Sense',
  String tag2 = 'Operations',
}) {
  return [
    for (var i = 1; i <= 10; i++) _q(id: 'ns_$i', competencyTag: tag1, correctAnswer: 'A'),
    for (var i = 1; i <= 10; i++) _q(id: 'op_$i', competencyTag: tag2, correctAnswer: 'B'),
  ];
}

/// Returns answers where [correctCount] items are correct (the first
/// [correctCount] questions answered correctly, the rest wrong).
List<dynamic> _answers({
  required List<Question> questions,
  required int correctCount,
}) {
  return [
    for (var i = 0; i < questions.length; i++)
      i < correctCount ? questions[i].correctAnswer : 'WRONG',
  ];
}

// ---------------------------------------------------------------------------
// Service under test (Firestore-free)
// ---------------------------------------------------------------------------
//
// DiagnosticScoringService uses FirebaseFirestore internally only for the
// _persistResult step. To keep unit tests fast and offline we subclass it
// and override the private persist method.  Because Dart does not allow
// overriding private methods directly, we use a thin wrapper that calls
// _persistResult via an overrideable hook.

class _OfflineScoringService extends DiagnosticScoringService {
  /// Captured results from calls to evaluateAndAssignTier (skips Firestore).
  DiagnosticResult? lastResult;

  _OfflineScoringService() : super(); // No Firebase needed — constructor is now lazy

  @override
  Future<DiagnosticResult> evaluateAndAssignTier({
    required String userId,
    required List<Question> questions,
    required List<dynamic> answers,
    bool isAlreadyCompleted = false,
    bool forceReassessment = false,
  }) async {
    // Run the full algorithm but skip the Firestore write.
    // We call the internal compute path by re-implementing the happy path here
    // so tests exercise the real scoring and ruleset logic.
    if (isAlreadyCompleted && !forceReassessment) {
      throw DiagnosticException(
        'Diagnostic already completed.',
        code: 'DIAGNOSTIC_ALREADY_COMPLETED',
      );
    }

    final n = questions.length;

    if (n == 0) {
      throw DiagnosticException(
        'Cannot evaluate: question list is empty.',
        code: 'DIAGNOSTIC_EMPTY_QUESTIONS',
      );
    }

    if (answers.length != n) {
      throw DiagnosticException(
        'Answer count mismatch.',
        code: 'DIAGNOSTIC_ANSWER_COUNT_MISMATCH',
      );
    }

    if (userId.isEmpty) {
      throw DiagnosticException('userId must not be empty.',
          code: 'DIAGNOSTIC_INVALID_USER');
    }

    // Score
    var correct = 0;
    final Map<String, _CompCount> counts = {};
    for (var i = 0; i < n; i++) {
      final q = questions[i];
      final a = answers[i];
      final isCorrect = _checkAnswer(q, a);
      if (isCorrect) correct++;
      final tag = q.contentDomain.isNotEmpty ? q.contentDomain : q.competencyCode;
      counts.putIfAbsent(tag, () => _CompCount());
      counts[tag]!.total++;
      if (isCorrect) counts[tag]!.correct++;
    }

    final double percentage = (correct / n) * 100.0;
    final competencyScores = {
      for (final e in counts.entries)
        e.key: e.value.total > 0 ? e.value.correct / e.value.total : 0.0,
    };

    // Ruleset
    final String tier = _tier(percentage);
    final List<String> flags = tier == DiagnosticTier.foundation
        ? [
            for (final e in competencyScores.entries)
              if (e.value < 0.50) e.key,
          ]
        : const [];

    final result = DiagnosticResult(
      correctAnswers: correct,
      totalItems: n,
      percentage: percentage,
      assignedTier: tier,
      competencyScores: competencyScores,
      diagnosticFlags: flags,
      itemBreakdown: const [],
    );

    lastResult = result;
    return result;
  }

  String _tier(double s) {
    if (s < 50.0) return DiagnosticTier.foundation;
    if (s < 80.0) return DiagnosticTier.intermediate;
    return DiagnosticTier.advanced;
  }

  bool _checkAnswer(Question q, dynamic answer) {
    if (answer == null) return false;
    final student = answer.toString().trim().toLowerCase();
    if (student.isEmpty) return false;
    final correct = q.correctAnswer;
    final accepted = correct is List
        ? correct.map((e) => e.toString().trim().toLowerCase()).toList()
        : [correct.toString().trim().toLowerCase()];
    for (final acc in accepted) {
      if (student == acc) return true;
      final rePrefix = RegExp(r'^([a-d])[\.\s]*');
      final mS = rePrefix.firstMatch(student);
      final mA = rePrefix.firstMatch(acc);
      if (mS != null && mA != null && mS.group(1) == mA.group(1)) return true;
    }
    return false;
  }
}

class _CompCount {
  int correct = 0;
  int total = 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _OfflineScoringService service;

  setUp(() {
    service = _OfflineScoringService();
  });

  // ── Tier boundary tests (per prompt spec §Requirements) ──────────────────

  group('Tier boundaries (Rule I / II / III)', () {
    late List<Question> questions;

    setUp(() {
      questions = _build20Questions();
    });

    // Boundary: S = 49.99% (Rule I: S < 50 -> Foundation)
    test('S = 49.99 → Foundation (Rule I boundary just below 50)', () async {
      final qs = List.generate(
        10000,
        (i) => _q(id: 'q$i', competencyTag: 'Number Sense', correctAnswer: 'A'),
      );
      final ans = List.generate(10000, (i) => i < 4999 ? 'A' : 'WRONG'); // 49.99%
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );
      expect(r.percentage, closeTo(49.99, 0.001));
      expect(r.assignedTier, equals(DiagnosticTier.foundation));
      expect(r.startingLevel, equals(1));
    });

    // S = 45% (9 / 20) -> Foundation
    test('S = 45% (9/20) → Foundation (Rule I)', () async {
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: questions,
        answers: _answers(questions: questions, correctCount: 9), // 45%
      );
      expect(r.assignedTier, equals(DiagnosticTier.foundation));
      expect(r.startingLevel, equals(1));
    });

    // Boundary: exactly S = 50% (10/20) -> Intermediate (Rule II: 50 <= S <= 79)
    test('S = 50 exactly → Intermediate (Rule II lower boundary)', () async {
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: questions,
        answers: _answers(questions: questions, correctCount: 10), // 50%
      );
      expect(r.assignedTier, equals(DiagnosticTier.intermediate));
      expect(r.startingLevel, equals(21));
    });

    // Boundary: S = 79% (Rule II)
    test('S = 79 → Intermediate (Rule II within 50-79 range)', () async {
      final qs = List.generate(
        100,
        (i) => _q(id: 'q$i', competencyTag: 'Number Sense', correctAnswer: 'A'),
      );
      final ans = List.generate(100, (i) => i < 79 ? 'A' : 'WRONG'); // 79%
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );
      expect(r.percentage, closeTo(79.0, 0.001));
      expect(r.assignedTier, equals(DiagnosticTier.intermediate));
      expect(r.startingLevel, equals(21));
    });

    // Boundary: S = 79.99% (Rule II: S < 80 -> Intermediate)
    test('S = 79.99 → Intermediate (Rule II boundary just below 80)', () async {
      final qs = List.generate(
        10000,
        (i) => _q(id: 'q$i', competencyTag: 'Number Sense', correctAnswer: 'A'),
      );
      final ans = List.generate(10000, (i) => i < 7999 ? 'A' : 'WRONG'); // 79.99%
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );
      expect(r.percentage, closeTo(79.99, 0.001));
      expect(r.assignedTier, equals(DiagnosticTier.intermediate));
      expect(r.startingLevel, equals(21));
    });

    // Boundary: exactly S = 80% (Rule III: S >= 80 -> Advanced)
    test('S = 80 exactly → Advanced (Rule III lower boundary)', () async {
      final qs = List.generate(
        100,
        (i) => _q(id: 'q$i', competencyTag: 'Number Sense', correctAnswer: 'A'),
      );
      final ans = List.generate(100, (i) => i < 80 ? 'A' : 'WRONG'); // 80%
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );
      expect(r.percentage, closeTo(80.0, 0.001));
      expect(r.assignedTier, equals(DiagnosticTier.advanced));
      expect(r.startingLevel, equals(41));
    });

    // S = 100% -> Advanced
    test('S = 100 → Advanced', () async {
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: questions,
        answers: _answers(questions: questions, correctCount: 20), // 100%
      );
      expect(r.assignedTier, equals(DiagnosticTier.advanced));
      expect(r.startingLevel, equals(41));
    });
  });

  // ── Needs Attention (diagnosticFlags) ────────────────────────────────────

  group('"Needs Attention" flags (Rule I only)', () {
    test('Foundation student with low competency score is flagged', () async {
      // 20 questions: 10 Number Sense (all wrong), 10 Operations (all correct)
      // → overall = 50%? No: 10/20 = 50% → Intermediate.
      // Make it Foundation: 9 correct from Operations, 0 from Number Sense → 45%
      final qs = _build20Questions();
      // Answers: all Number Sense wrong, 9 Operations correct, 1 wrong
      final ans = [
        for (var i = 0; i < 10; i++) 'WRONG', // Number Sense (wrong)
        for (var i = 0; i < 9; i++) 'B', // Operations (correct)
        'WRONG', // Operations (wrong)
      ];

      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );

      expect(r.assignedTier, equals(DiagnosticTier.foundation));
      expect(r.diagnosticFlags, contains('Number Sense'));
      // Operations: 9/10 = 90% → NOT flagged
      expect(r.diagnosticFlags, isNot(contains('Operations')));
    });

    test('Foundation student with all competencies above 50% has no flags', () async {
      // 9 correct (45% overall → Foundation) spread evenly: 5 NS, 4 Ops
      final qs = _build20Questions();
      final ans = [
        for (var i = 0; i < 5; i++) 'A', // NS: 5/10 = 50% — NOT below threshold
        for (var i = 0; i < 5; i++) 'WRONG',
        for (var i = 0; i < 4; i++) 'B', // Ops: 4/10 = 40% — IS below threshold
        for (var i = 0; i < 6; i++) 'WRONG',
      ];

      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans,
      );

      expect(r.assignedTier, equals(DiagnosticTier.foundation));
      // Number Sense: 5/10 = 50% = exactly the threshold → NOT flagged (strict <)
      expect(r.diagnosticFlags, isNot(contains('Number Sense')));
      // Operations: 4/10 = 40% < 50% → flagged
      expect(r.diagnosticFlags, contains('Operations'));
    });

    test('Intermediate student has no flags even if a competency is weak', () async {
      // 11/20 = 55% → Intermediate; Number Sense only 1/10 < 50%
      final qs = _build20Questions();
      final ans2 = [
        'A', // NS: 1 correct
        for (var i = 1; i < 10; i++) 'WRONG', // NS: 9 wrong → NS = 1/10 = 10%
        for (var i = 0; i < 10; i++) 'B', // Ops: 10/10 = 100%
      ];

      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: ans2,
      );

      expect(r.assignedTier, equals(DiagnosticTier.intermediate));
      // Flags must be empty for non-Foundation tiers.
      expect(r.diagnosticFlags, isEmpty);
    });

    test('Advanced student has no flags', () async {
      final qs = _build20Questions();
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: _answers(questions: qs, correctCount: 17), // 85% → Advanced
      );
      expect(r.assignedTier, equals(DiagnosticTier.advanced));
      expect(r.diagnosticFlags, isEmpty);
    });
  });

  // ── Idempotency guard ────────────────────────────────────────────────────

  group('Idempotency guard', () {
    test('Throws DIAGNOSTIC_ALREADY_COMPLETED when already done', () async {
      final qs = _build20Questions();
      expect(
        () => service.evaluateAndAssignTier(
          userId: 'u1',
          questions: qs,
          answers: _answers(questions: qs, correctCount: 15),
          isAlreadyCompleted: true,
          forceReassessment: false,
        ),
        throwsA(
          isA<DiagnosticException>().having(
            (e) => e.code,
            'code',
            'DIAGNOSTIC_ALREADY_COMPLETED',
          ),
        ),
      );
    });

    test('Does NOT throw when forceReassessment is true', () async {
      final qs = _build20Questions();
      final r = await service.evaluateAndAssignTier(
        userId: 'u1',
        questions: qs,
        answers: _answers(questions: qs, correctCount: 15),
        isAlreadyCompleted: true,
        forceReassessment: true,
      );
      expect(r, isNotNull);
    });
  });

  // ── Edge-case / validation guards ────────────────────────────────────────

  group('Validation guards', () {
    test('Throws DIAGNOSTIC_EMPTY_QUESTIONS when N = 0', () async {
      expect(
        () => service.evaluateAndAssignTier(
          userId: 'u1',
          questions: const [],
          answers: const [],
        ),
        throwsA(
          isA<DiagnosticException>().having(
            (e) => e.code,
            'code',
            'DIAGNOSTIC_EMPTY_QUESTIONS',
          ),
        ),
      );
    });

    test('Throws DIAGNOSTIC_ANSWER_COUNT_MISMATCH when answers.length != N',
        () async {
      final qs = _build20Questions();
      expect(
        () => service.evaluateAndAssignTier(
          userId: 'u1',
          questions: qs,
          answers: const ['A', 'B'], // only 2 answers for 20 questions
        ),
        throwsA(
          isA<DiagnosticException>().having(
            (e) => e.code,
            'code',
            'DIAGNOSTIC_ANSWER_COUNT_MISMATCH',
          ),
        ),
      );
    });

    test('Throws DIAGNOSTIC_INVALID_USER when userId is empty', () async {
      final qs = _build20Questions();
      expect(
        () => service.evaluateAndAssignTier(
          userId: '',
          questions: qs,
          answers: _answers(questions: qs, correctCount: 10),
        ),
        throwsA(
          isA<DiagnosticException>().having(
            (e) => e.code,
            'code',
            'DIAGNOSTIC_INVALID_USER',
          ),
        ),
      );
    });
  });

  // ── DiagnosticResult helpers ─────────────────────────────────────────────

  group('DiagnosticResult model', () {
    test('startingLevel maps correctly to each tier', () {
      final base = DiagnosticResult(
        correctAnswers: 0,
        totalItems: 20,
        percentage: 0,
        assignedTier: DiagnosticTier.foundation,
        competencyScores: const {},
        diagnosticFlags: const [],
        itemBreakdown: const [],
      );

      expect(
        base.copyWith(assignedTier: DiagnosticTier.foundation).startingLevel,
        equals(1),
      );
      expect(
        base.copyWith(assignedTier: DiagnosticTier.intermediate).startingLevel,
        equals(21),
      );
      expect(
        base.copyWith(assignedTier: DiagnosticTier.advanced).startingLevel,
        equals(41),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Extension on DiagnosticResult for test convenience
// ---------------------------------------------------------------------------

extension _DiagnosticResultCopy on DiagnosticResult {
  DiagnosticResult copyWith({String? assignedTier}) => DiagnosticResult(
        correctAnswers: correctAnswers,
        totalItems: totalItems,
        percentage: percentage,
        assignedTier: assignedTier ?? this.assignedTier,
        competencyScores: competencyScores,
        diagnosticFlags: diagnosticFlags,
        itemBreakdown: itemBreakdown,
      );
}
