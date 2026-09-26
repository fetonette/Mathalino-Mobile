import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/constants/diagnostic_questions.dart';
import 'package:mathalino_student_app/core/errors/diagnostic_exception.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/models/student_result_model.dart';
import 'package:mathalino_student_app/core/services/diagnostic_assessment_service.dart';
import 'package:mathalino_student_app/core/services/placement_service.dart';
import 'package:mathalino_student_app/core/services/scoring_service.dart';

void main() {
  group('DiagnosticAssessmentService', () {
    final service = DiagnosticAssessmentService();

    group('loadDiagnosticQuestions', () {
      test('returns exactly 20 questions', () {
        final questions = service.loadDiagnosticQuestions();
        expect(questions.length, equals(20));
      });

      test('question IDs are unique and sequential (diag_001–diag_020)', () {
        final questions = service.loadDiagnosticQuestions();
        final ids = questions.map((q) => q.id).toList();
        expect(ids.toSet().length, equals(20));
        expect(ids.first, equals('diag_001'));
        expect(ids.last, equals('diag_020'));
      });

      test('all questions have valid competency codes', () {
        final questions = service.loadDiagnosticQuestions();
        final validCodes =
            competencyDescriptions.keys.toSet(); // M1NS, M2NS, M3NS, M2OP, M3OP
        for (final q in questions) {
          expect(validCodes, contains(q.competencyCode),
              reason: 'Question ${q.id} has unknown competency: ${q.competencyCode}');
        }
      });

      test('question types are one of the supported types', () {
        final questions = service.loadDiagnosticQuestions();
        const validTypes = {
          'multipleChoice',
          'numericInput',
          'computation',
          'trueFalse',
        };
        for (final q in questions) {
          expect(validTypes, contains(q.type),
              reason: 'Question ${q.id} has unsupported type: ${q.type}');
        }
      });
    });

    group('getDiagnosticQuestion', () {
      test('returns the question when found', () {
        final q = service.getDiagnosticQuestion('diag_010');
        expect(q, isNotNull);
        expect(q!.id, equals('diag_010'));
        expect(q.questionText, isNotEmpty);
      });

      test('returns null when question ID does not exist', () {
        final q = service.getDiagnosticQuestion('nonexistent');
        expect(q, isNull);
      });
    });

    group('getCompetencyDescription', () {
      test('returns description for known competency', () {
        final desc = service.getCompetencyDescription('M1NS');
        expect(desc, contains('Grade 1 Number Sense'));
      });

      test('returns fallback for unknown competency', () {
        final desc = service.getCompetencyDescription('UNKNOWN');
        expect(desc, equals('Unknown competency'));
      });
    });

    group('getPlacementRuleInfo', () {
      test('returns rule map for Beginner', () {
        final rule = service.getPlacementRuleInfo('Beginner');
        expect(rule, isNotNull);
        expect(rule!['category'], equals('Beginner'));
        expect(rule['startingLevel'], equals(1));
      });

      test('returns rule map for Mastery', () {
        final rule = service.getPlacementRuleInfo('mastery');
        expect(rule, isNotNull);
        expect(rule!['startingLevel'], equals(41));
      });

      test('returns null for unknown category', () {
        final rule = service.getPlacementRuleInfo('Unknown');
        expect(rule, isNull);
      });
    });

    group('getContentPoolsForCategory', () {
      test('returns Grade 1-3 for Beginner', () {
        final pools = service.getContentPoolsForCategory('Beginner');
        expect(pools, equals(['Grade 1', 'Grade 2', 'Grade 3']));
      });

      test('returns Grade 1-6 Advanced for Mastery', () {
        final pools = service.getContentPoolsForCategory('Mastery');
        expect(pools, contains('Grade 6 Advanced'));
      });

      test('returns fallback for unknown category', () {
        final pools = service.getContentPoolsForCategory('Unknown');
        expect(pools, equals(['Grade 1', 'Grade 2', 'Grade 3']));
      });
    });

    group('validateDiagnosticCompletion', () {
      final questions = service.loadDiagnosticQuestions();

      test('returns errors when questions list is empty', () {
        final errors = service.validateDiagnosticCompletion(
          questions: [],
          answers: List.filled(20, '0'),
        );
        expect(errors, isNotEmpty);
        expect(errors, contains('No diagnostic questions loaded'));
      });

      test('returns errors when answers list is empty', () {
        final errors = service.validateDiagnosticCompletion(
          questions: questions,
          answers: <dynamic>[],
        );
        expect(errors, contains('No answers submitted'));
      });

      test('returns errors when answer count mismatches question count', () {
        final errors = service.validateDiagnosticCompletion(
          questions: questions,
          answers: List.filled(15, '0'),
        );
        expect(
          errors,
          contains('Answer count (15) does not match question count (20)'),
        );
      });

      test('returns errors when any answer is null', () {
        final answers = List<dynamic>.filled(20, '0');
        answers[5] = null;
        final errors = service.validateDiagnosticCompletion(
          questions: questions,
          answers: answers,
        );
        expect(errors, contains('Question 6 has no answer'));
      });

      test('returns empty list for valid completion', () {
        final answers = List<dynamic>.filled(20, '0');
        final errors = service.validateDiagnosticCompletion(
          questions: questions,
          answers: answers,
        );
        expect(errors, isEmpty);
      });
    });

    group('analyzeDiagnosticPerformance', () {
      final questions = service.loadDiagnosticQuestions();

      test('returns empty strengths/weaknesses when answer count mismatches', () {
        final analysis = service.analyzeDiagnosticPerformance(
          questions: questions,
          answers: List.filled(10, '0'),
          scorePercentage: 50.0,
          placementCategory: 'Intermediate',
        );
        expect(analysis['strengthCompetencies'], isEmpty);
        expect(analysis['weakCompetencies'], isEmpty);
        expect(analysis['recommendations'], isNotEmpty);
      });

      test('identifies mastered competency when all questions correct', () {
        // All M1NS questions answered correctly.
        final answers = questions
            .map((q) => q.correctAnswer is List
                ? (q.correctAnswer as List).first.toString()
                : q.correctAnswer.toString())
            .toList();

        final analysis = service.analyzeDiagnosticPerformance(
          questions: questions,
          answers: answers,
          scorePercentage: 100.0,
          placementCategory: 'Mastery',
        );

        // All competencies should be in mastered list (100% accuracy).
        expect(analysis['strengthCompetencies'], isNotEmpty);
        expect(analysis['weakCompetencies'], isEmpty);
        expect(analysis['category'], equals('Mastery'));
        expect(analysis['recommendations'], contains(
          "Excellent! You've mastered all diagnostic items.",
        ));
      });

      test('identifies weak competencies when all questions wrong', () {
        final answers = List.filled(20, 'WRONG_ANSWER');
        final analysis = service.analyzeDiagnosticPerformance(
          questions: questions,
          answers: answers,
          scorePercentage: 0.0,
          placementCategory: 'Beginner',
        );

        expect(analysis['weakCompetencies'], isNotEmpty);
        expect(analysis['category'], equals('Beginner'));
        expect(analysis['recommendations'], contains(
          "Keep practicing! You're starting your math journey.",
        ));
      });

      test('generates recommendations for Advanced category (75%+)', () {
        final analysis = service.analyzeDiagnosticPerformance(
          questions: questions,
          answers: List.filled(20, 'WRONG'),
          scorePercentage: 80.0,
          placementCategory: 'Advanced',
        );

        expect(analysis['recommendations'], contains(
          "Great job! You have a strong foundation.",
        ));
      });

      test('generates recommendations for Intermediate category (50%+)', () {
        final analysis = service.analyzeDiagnosticPerformance(
          questions: questions,
          answers: List.filled(20, 'WRONG'),
          scorePercentage: 60.0,
          placementCategory: 'Intermediate',
        );

        expect(analysis['recommendations'], contains(
          "Good progress! You're building your skills.",
        ));
      });
    });

    group('buildDiagnosticResultReport', () {
      final questions = service.loadDiagnosticQuestions();

      test('builds report with item breakdown and competency lists', () {
        final answers = List.generate(20, (i) => questions[i].correctAnswer is List
            ? (questions[i].correctAnswer as List).first.toString()
            : questions[i].correctAnswer.toString());

        final report = service.buildDiagnosticResultReport(
          studentId: 'test_student_1',
          studentName: 'Test Student',
          gradeLevel: 3,
          questions: questions,
          answers: answers,
          correctCount: 20,
          scorePercentage: 100.0,
          placementCategory: 'Mastery',
        );

        expect(report['studentId'], equals('test_student_1'));
        expect(report['studentName'], equals('Test Student'));
        expect(report['gradeLevel'], equals(3));
        expect(report['totalItems'], equals(20));
        expect(report['correctAnswers'], equals(20));
        expect(report['percentage'], equals(100.0));
        expect(report['placementCategory'], equals('Mastery'));

        // itemBreakdown should have 20 entries.
        final breakdown = report['itemBreakdown'] as List<dynamic>;
        expect(breakdown.length, equals(20));

        // Every item should be marked correct.
        for (final item in breakdown) {
          expect(item['correct'], isTrue);
        }

        // All competency codes should be in mastered list.
        expect(report['competenciesMastered'], isNotEmpty);
        expect(report['competenciesToDevelop'], isEmpty);
      });

      test('handles incorrect answers in breakdown', () {
        final answers = List.filled(20, 'WRONG_ANSWER');
        final report = service.buildDiagnosticResultReport(
          studentId: 'test_student_2',
          studentName: 'Test Student',
          gradeLevel: 1,
          questions: questions,
          answers: answers,
          correctCount: 0,
          scorePercentage: 0.0,
          placementCategory: 'Beginner',
        );

        final breakdown = report['itemBreakdown'] as List<dynamic>;
        for (final item in breakdown) {
          expect(item['correct'], isFalse);
        }
        expect(report['competenciesToDevelop'], isNotEmpty);
        expect(report['competenciesMastered'], isEmpty);
      });
    });
  });

  group('PlacementService Rule-Based Classification', () {
    final placementService = PlacementService();

    test('percentage < 50% → Foundation / Level 1 / Grade 1-3', () {
      final res = placementService.calculatePlacement(9, 20); // 45%
      expect(res.category, equals('Foundation'));
      expect(res.startingLevel, equals(1));
      expect(res.contentPool, equals(['Grade 1', 'Grade 2', 'Grade 3']));
      expect(res.scorePercentage, equals(45.0));
    });

    test('percentage == 50% → Intermediate / Level 21', () {
      final res = placementService.calculatePlacement(10, 20); // 50%
      expect(res.category, equals('Intermediate'));
      expect(res.startingLevel, equals(21));
      expect(res.contentPool, equals([
        'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'
      ]));
    });

    test('percentage == 75% → Intermediate / Level 21 (within 50-79% range)', () {
      final res = placementService.calculatePlacement(15, 20); // 75%
      expect(res.category, equals('Intermediate'));
      expect(res.startingLevel, equals(21));
      expect(res.scorePercentage, equals(75.0));
    });

    test('percentage == 80% → Advanced / Level 41', () {
      final res = placementService.calculatePlacement(16, 20); // 80%
      expect(res.category, equals('Advanced'));
      expect(res.startingLevel, equals(41));
      expect(res.scorePercentage, equals(80.0));
    });

    test('percentage == 95% → Advanced / Level 41', () {
      final res = placementService.calculatePlacement(19, 20); // 95%
      expect(res.category, equals('Advanced'));
      expect(res.startingLevel, equals(41));
    });

    test('percentage == 100% → Advanced / Level 41', () {
      final res = placementService.calculatePlacement(20, 20); // 100%
      expect(res.category, equals('Advanced'));
      expect(res.startingLevel, equals(41));
      expect(res.contentPool, contains('Grade 6 Advanced'));
      expect(res.scorePercentage, equals(100.0));
    });

    test('edge case: 0/20 → Foundation / Level 1', () {
      final res = placementService.calculatePlacement(0, 20); // 0%
      expect(res.category, equals('Foundation'));
      expect(res.startingLevel, equals(1));
      expect(res.scorePercentage, equals(0.0));
    });

    test('edge case: totalPossiblePoints == 0 returns Foundation', () {
      final res = placementService.calculatePlacement(0, 0);
      expect(res.category, equals('Foundation'));
      expect(res.startingLevel, equals(1));
      expect(res.scorePercentage, equals(0.0));
    });
  });

  group('ScoringService with Diagnostic Questions', () {
    final scoringService = ScoringService();
    final assessmentService = DiagnosticAssessmentService();
    final questions = assessmentService.loadDiagnosticQuestions();

    test('scores all numericInput questions', () {
      final numericQuestions =
          questions.where((q) => q.type == 'numericInput').toList();
      expect(numericQuestions, isNotEmpty);

      for (final q in numericQuestions) {
        final correctAnswer = q.correctAnswer is List
            ? (q.correctAnswer as List).first.toString()
            : q.correctAnswer.toString();

        // Correct answer should score maxPoints.
        expect(
          scoringService.scoreQuestion(q, correctAnswer),
          equals(q.maxPoints),
        );

        // A wrong answer should score 0.
        expect(
          scoringService.scoreQuestion(q, 'WRONG_99999'),
          equals(0),
        );
      }
    });

    test('scores multipleChoice with letter prefix matching', () {
      final mcQuestions =
          questions.where((q) => q.type == 'multipleChoice').toList();
      expect(mcQuestions, isNotEmpty);

      for (final q in mcQuestions) {
        final accepted = q.correctAnswer is List
            ? (q.correctAnswer as List)[0].toString().trim()
            : q.correctAnswer.toString().trim();

        expect(scoringService.scoreQuestion(q, accepted), equals(q.maxPoints));
        expect(scoringService.scoreQuestion(q, 'Z'), equals(0));
      }
    });
  });

  group('StudentResult Model', () {
    test('fromMap parses all fields including competencies', () {
      final map = {
        'studentId': 'student_123',
        'assessmentType': 'DIAGNOSTIC',
        'score': 17,
        'maxScore': 20,
        'percentage': 85.0,
        'itemBreakdown': {'q1': {'correct': true}},
        'targetCompetencies': ['M1NS', 'M2NS'],
        'competenciesMastered': ['M1NS'],
        'competenciesToDevelop': ['M2NS'],
        'metadata': {'placementCategory': 'Advanced'},
        'timestamp': Timestamp.now(),
      };

      final result = StudentResult.fromMap(map, 'result_456');

      expect(result.resultId, equals('result_456'));
      expect(result.studentId, equals('student_123'));
      expect(result.assessmentType, equals('DIAGNOSTIC'));
      expect(result.score, equals(17));
      expect(result.maxScore, equals(20));
      expect(result.percentage, equals(85.0));
      expect(result.targetCompetencies, equals(['M1NS', 'M2NS']));
      expect(result.competenciesMastered, equals(['M1NS']));
      expect(result.competenciesToDevelop, equals(['M2NS']));
      expect(result.metadata?['placementCategory'], equals('Advanced'));
    });

    test('toMap serializes all fields including competencies', () {
      final result = StudentResult(
        resultId: 'r001',
        studentId: 's001',
        assessmentType: 'DIAGNOSTIC',
        score: 18,
        maxScore: 20,
        percentage: 90.0,
        itemBreakdown: {'q1': {'correct': true}},
        targetCompetencies: ['M1NS'],
        competenciesMastered: ['M1NS'],
        competenciesToDevelop: <String>[],
        metadata: {'placementCategory': 'Advanced'},
      );

      final map = result.toMap();

      expect(map['studentId'], equals('s001'));
      expect(map['score'], equals(18));
      expect(map['targetCompetencies'], equals(['M1NS']));
      expect(map['competenciesMastered'], equals(['M1NS']));
      expect(map['metadata']?['placementCategory'], equals('Advanced'));
    });

    test('fromMap handles missing competency fields gracefully', () {
      final map = {
        'studentId': 's002',
        'assessmentType': 'LEVEL_PRACTICE',
        'score': 5,
        'maxScore': 5,
        'percentage': 100.0,
      };

      final result = StudentResult.fromMap(map, 'r002');

      expect(result.targetCompetencies, isNull);
      expect(result.competenciesMastered, isNull);
      expect(result.competenciesToDevelop, isNull);
      expect(result.metadata, isNull);
    });
  });

  group('StudentProfile UpdatedAt Field', () {
    test('fromMap parses updatedAt when present', () {
      final ts = Timestamp.now();
      final map = {
        'lrn': '123456789012',
        'name': 'Test Student',
        'role': 'student',
        'gradeLevel': 3,
        'assignedCategory': 'Beginner',
        'currentLevel': 1,
        'startingLevel': 1,
        'diagnosticCompleted': false,
        'verificationCode': 'MTH-0001',
        'updatedAt': ts,
      };

      final profile = StudentProfile.fromMap(map, 'uid_123');
      expect(profile.updatedAt, isNotNull);
      expect(profile.updatedAt, equals(ts));
    });

    test('fromMap sets updatedAt to null when absent', () {
      final map = {
        'lrn': '123456789012',
        'name': 'Test Student',
        'role': 'student',
        'gradeLevel': 3,
        'assignedCategory': 'Beginner',
        'currentLevel': 1,
        'startingLevel': 1,
        'diagnosticCompleted': false,
        'verificationCode': 'MTH-0001',
      };

      final profile = StudentProfile.fromMap(map, 'uid_456');
      expect(profile.updatedAt, isNull);
    });

    test('toMap includes updatedAt field', () {
      final ts = Timestamp.now();
      final profile = StudentProfile(
        uid: 'uid_789',
        lrn: '123456789012',
        displayName: 'Test',
        gradeLevel: 1,
        assignedCategory: 'Beginner',
        currentLevel: 1,
        startingLevel: 1,
        stats: const StudentStats(),
        usedQuestionsHistory: [],
        diagnosticCompleted: false,
        verificationCode: 'MTH-0002',
        updatedAt: ts,
      );

      final map = profile.toMap();
      expect(map['updatedAt'], equals(ts));
    });
  });

  group('DiagnosticProvider End-to-End Flow (Unit Logic)', () {
    test('calculates correct percentage from answers', () {
      // 17 correct out of 20 → 85% → Advanced
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();

      // Simulate 17 correct answers (first 17 correct, last 3 wrong).
      final answers = <dynamic>[];
      for (var i = 0; i < 20; i++) {
        if (i < 17) {
          final q = questions[i];
          answers.add(q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString());
        } else {
          answers.add('WRONG');
        }
      }

      // Calculate score.
      var pointsEarned = 0;
      var maxPoints = 0;
      var correctCount = 0;
      for (var i = 0; i < questions.length; i++) {
        final earned = scoringService.scoreQuestion(questions[i], answers[i]);
        pointsEarned += earned;
        maxPoints += questions[i].maxPoints;
        if (earned > 0) correctCount++;
      }

      final percentage = (pointsEarned / maxPoints) * 100.0;
      expect(correctCount, equals(17));
      expect(percentage, equals(85.0));

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Advanced'));
      expect(placement.startingLevel, equals(41));
      expect(placement.scorePercentage, equals(85.0));
    });

    test('20 correct → 100% → Mastery', () {
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();
      final answers = questions
          .map((q) => q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString())
          .toList();

      var pointsEarned = 0;
      var maxPoints = 0;
      for (var i = 0; i < questions.length; i++) {
        pointsEarned += scoringService.scoreQuestion(questions[i], answers[i]);
        maxPoints += questions[i].maxPoints;
      }

      final percentage = (pointsEarned / maxPoints) * 100.0;
      expect(percentage, equals(100.0));

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Advanced'));
      expect(placement.startingLevel, equals(41));
    });

    test('9 correct → 45% → Foundation', () {
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();
      final answers = questions
          .map((q) => q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString())
          .toList();

      // Set first 9 correct, rest wrong.
      for (var i = 9; i < 20; i++) {
        answers[i] = 'WRONG';
      }

      var pointsEarned = 0;
      var maxPoints = 0;
      for (var i = 0; i < questions.length; i++) {
        pointsEarned += scoringService.scoreQuestion(questions[i], answers[i]);
        maxPoints += questions[i].maxPoints;
      }

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Foundation'));
      expect(placement.startingLevel, equals(1));
    });

    test('10 correct → 50% → Intermediate', () {
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();
      final answers = questions
          .map((q) => q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString())
          .toList();

      // Set first 10 correct, rest wrong.
      for (var i = 10; i < 20; i++) {
        answers[i] = 'WRONG';
      }

      var pointsEarned = 0;
      var maxPoints = 0;
      for (var i = 0; i < questions.length; i++) {
        pointsEarned += scoringService.scoreQuestion(questions[i], answers[i]);
        maxPoints += questions[i].maxPoints;
      }

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Intermediate'));
      expect(placement.startingLevel, equals(21));
    });

    test('15 correct → 75% → Intermediate (within 50-79% range)', () {
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();
      final answers = questions
          .map((q) => q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString())
          .toList();

      // Set first 15 correct, rest wrong.
      for (var i = 15; i < 20; i++) {
        answers[i] = 'WRONG';
      }

      var pointsEarned = 0;
      var maxPoints = 0;
      for (var i = 0; i < questions.length; i++) {
        pointsEarned += scoringService.scoreQuestion(questions[i], answers[i]);
        maxPoints += questions[i].maxPoints;
      }

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Intermediate'));
      expect(placement.startingLevel, equals(21));
    });

    test('16 correct → 80% → Advanced (Rule III: S >= 80)', () {
      final assessmentService = DiagnosticAssessmentService();
      final scoringService = ScoringService();
      final placementService = PlacementService();

      final questions = assessmentService.loadDiagnosticQuestions();
      final answers = questions
          .map((q) => q.correctAnswer is List
              ? (q.correctAnswer as List).first.toString()
              : q.correctAnswer.toString())
          .toList();

      // Set first 16 correct, rest wrong.
      for (var i = 16; i < 20; i++) {
        answers[i] = 'WRONG';
      }

      var pointsEarned = 0;
      var maxPoints = 0;
      for (var i = 0; i < questions.length; i++) {
        pointsEarned += scoringService.scoreQuestion(questions[i], answers[i]);
        maxPoints += questions[i].maxPoints;
      }

      final placement = placementService.calculatePlacement(pointsEarned, maxPoints);
      expect(placement.category, equals('Advanced'));
      expect(placement.startingLevel, equals(41));
    });

    // ── Note: DiagnosticProvider state-management tests (answers getter,
    // resetDiagnostic) require a Firebase-initialized environment because the
    // provider's default constructor instantiates FirestoreService which
    // accesses FirebaseFirestore.instance. Those tests are covered by
    // integration tests. The unit tests below verify the core scoring and
    // placement logic without needing Firebase. ──
  });

  group('DiagnosticException', () {
    test('stores message, code, and originalError', () {
      final ex = DiagnosticException(
        'Something went wrong',
        code: 'TEST_ERROR',
        originalError: 'root cause',
      );
      expect(ex.message, equals('Something went wrong'));
      expect(ex.code, equals('TEST_ERROR'));
      expect(ex.originalError, equals('root cause'));
      expect(ex.toString(), contains('Something went wrong'));
    });

    test('code is optional', () {
      final ex = DiagnosticException('No code provided');
      expect(ex.code, isNull);
      expect(ex.message, equals('No code provided'));
    });
  });
}
