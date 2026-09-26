import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/student_result_model.dart';

void main() {
  group('QuestionResultItem', () {
    test('round-trips through toMap and fromMap with full metadata', () {
      const item = QuestionResultItem(
        itemNumber: 1,
        questionId: 'L1-Q1',
        questionText: 'What is 3 + 4?',
        selectedAnswer: '7',
        correctAnswer: '7',
        isCorrect: true,
        pointsEarned: 1,
        maxPoints: 1,
        contentDomain: 'Number and Number Sense',
        cognitiveDomain: 'Knowing',
        difficulty: 'Preparation',
        competencyCode: 'M1NS-Ia-1',
        timeSpentSeconds: 12,
      );

      final map = item.toMap();
      expect(map['itemNumber'], 1);
      expect(map['questionId'], 'L1-Q1');
      expect(map['questionText'], 'What is 3 + 4?');
      expect(map['selectedAnswer'], '7');
      expect(map['studentAnswer'], '7'); // backward-compat alias
      expect(map['correctAnswer'], '7');
      expect(map['isCorrect'], isTrue);
      expect(map['correct'], isTrue); // backward-compat alias
      expect(map['contentDomain'], 'Number and Number Sense');
      expect(map['cognitiveDomain'], 'Knowing');
      expect(map['difficulty'], 'Preparation');
      expect(map['competencyCode'], 'M1NS-Ia-1');
      expect(map['timeSpentSeconds'], 12);

      final parsed = QuestionResultItem.fromMap(map);
      expect(parsed.itemNumber, item.itemNumber);
      expect(parsed.questionId, item.questionId);
      expect(parsed.questionText, item.questionText);
      expect(parsed.selectedAnswer, item.selectedAnswer);
      expect(parsed.correctAnswer, item.correctAnswer);
      expect(parsed.isCorrect, item.isCorrect);
      expect(parsed.contentDomain, item.contentDomain);
      expect(parsed.cognitiveDomain, item.cognitiveDomain);
      expect(parsed.timeSpentSeconds, 12);
    });

    test('fromMap tolerates legacy field names (studentAnswer and correct)', () {
      final legacyMap = {
        'itemNumber': 2,
        'questionId': 'Q-legacy',
        'competencyTag': 'Geometry',
        'competencyCode': 'M1GE-IIIa-1',
        'correct': false,
        'studentAnswer': 'A',
      };

      final item = QuestionResultItem.fromMap(legacyMap);
      expect(item.itemNumber, 2);
      expect(item.questionId, 'Q-legacy');
      expect(item.contentDomain, 'Geometry');
      expect(item.isCorrect, isFalse);
      expect(item.selectedAnswer, 'A');
      expect(item.pointsEarned, 0);
      expect(item.maxPoints, 1);
    });
  });

  group('StudentResult Model — Modern & Expanded Fields', () {
    test('serializes and deserializes math and cognitive domain rollups', () {
      final ts = Timestamp.now();
      final modernResult = StudentResult(
        resultId: 'res_001',
        studentId: 'student_xyz',
        userId: 'student_xyz',
        lrn: '107170918362',
        assessmentId: 'RMA-G4-DIAG',
        assessmentType: 'DIAGNOSTIC',
        title: 'RMA Diagnostic Assessment',
        score: 18,
        maxScore: 20,
        percentage: 90.0,
        completionStatus: 'completed',
        attemptNumber: 1,
        durationSeconds: 245,
        assignedTier: 'Advanced',
        startingLevel: 41,
        mathDomainPerformance: {
          'Number and Number Sense': {'correct': 8, 'total': 10, 'accuracyPct': 80},
          'Geometry': {'correct': 5, 'total': 5, 'accuracyPct': 100},
          'Measurement': {'correct': 5, 'total': 5, 'accuracyPct': 100},
        },
        cognitiveDomainPerformance: {
          'Knowing': {'correct': 10, 'total': 10, 'accuracyPct': 100},
          'Applying': {'correct': 5, 'total': 6, 'accuracyPct': 83},
          'Reasoning': {'correct': 3, 'total': 4, 'accuracyPct': 75},
        },
        questionResults: const [
          QuestionResultItem(
            itemNumber: 1,
            questionId: 'L1-Q1',
            selectedAnswer: '7',
            correctAnswer: '7',
            isCorrect: true,
            contentDomain: 'Number and Number Sense',
            cognitiveDomain: 'Knowing',
            competencyCode: 'M1NS',
          ),
        ],
        timestamp: ts,
        completedAt: ts,
      );

      final map = modernResult.toMap();

      // Verify dual-write fields
      expect(map['studentId'], 'student_xyz');
      expect(map['userId'], 'student_xyz');
      expect(map['lrn'], '107170918362');
      expect(map['assessmentId'], 'RMA-G4-DIAG');
      expect(map['score'], 18);
      expect(map['maxScore'], 20);
      expect(map['totalQuestions'], 20);
      expect(map['percentage'], 90.0);
      expect(map['accuracy'], 0.9);
      expect(map['durationSeconds'], 245);
      expect(map['completionStatus'], 'completed');

      // Verify domain rollups
      expect(map['mathDomainPerformance'], isNotNull);
      expect(map['domainPerformances'], isNotNull); // Dashboard alias
      expect(map['mathDomainPerformance']['Geometry']['accuracyPct'], 100);
      expect(map['cognitiveDomainPerformance']['Knowing']['accuracyPct'], 100);

      // Verify round-trip
      final parsed = StudentResult.fromMap(map, 'res_001');
      expect(parsed.studentId, 'student_xyz');
      expect(parsed.userId, 'student_xyz');
      expect(parsed.durationSeconds, 245);
      expect(parsed.mathDomainPerformance?['Geometry']?['accuracyPct'], 100);
      expect(parsed.cognitiveDomainPerformance?['Knowing']?['accuracyPct'], 100);
      expect(parsed.questionResults?.length, 1);
      expect(parsed.questionResults?.first.selectedAnswer, '7');
    });
  });

  group('StudentResult Model — Backward Compatibility with Legacy Documents', () {
    test('parses legacy remediation doc (userId, totalQuestions, completedAt, no studentId)', () {
      final legacyRemediationMap = {
        'userId': 'user_remed_123',
        'levelNumber': 5,
        'assessmentType': 'REMEDIATION',
        'score': 1,
        'totalQuestions': 1,
        'competencyCode': 'M1NS-Ia-1',
        'completedAt': Timestamp.now(),
      };

      final parsed = StudentResult.fromMap(legacyRemediationMap, 'remed_doc_1');

      // studentId falls back to userId
      expect(parsed.studentId, 'user_remed_123');
      expect(parsed.userId, 'user_remed_123');
      expect(parsed.levelNumber, 5);
      expect(parsed.assessmentType, 'REMEDIATION');
      expect(parsed.score, 1);
      expect(parsed.maxScore, 1);
      expect(parsed.percentage, 100.0);
      expect(parsed.timestamp, isNotNull); // falls back to completedAt
      expect(parsed.completionStatus, 'completed');
    });

    test('parses legacy daily challenge doc (correctCount, accuracy, date)', () {
      final legacyDailyMap = {
        'userId': 'daily_user',
        'assessmentType': 'DAILY_CHALLENGE',
        'date': '2026-09-20',
        'completedAt': Timestamp.now(),
        'totalQuestions': 5,
        'correctCount': 4,
        'pointsEarned': 4,
        'maxPoints': 5,
        'accuracy': 0.8,
        'xpAwarded': 40,
        'coinsAwarded': 20,
        'streakDays': 7,
      };

      final parsed = StudentResult.fromMap(legacyDailyMap, 'daily_doc_1');

      expect(parsed.studentId, 'daily_user');
      expect(parsed.score, 4);
      expect(parsed.maxScore, 5);
      expect(parsed.percentage, 80.0);
      expect(parsed.xpAwarded, 40);
      expect(parsed.coinsAwarded, 20);
    });

    test('parses legacy post-assessment doc with Map-shaped itemBreakdown and correct boolean', () {
      final legacyPostMap = {
        'studentId': 'post_user',
        'assessmentType': 'POST_ASSESSMENT',
        'score': 2,
        'maxScore': 2,
        'percentage': 100.0,
        'itemBreakdown': {
          'Q1': {
            'itemNumber': 1,
            'questionId': 'Q1',
            'competencyCode': 'C1',
            'contentDomain': 'Fractions',
            'correct': true,
            'pointsEarned': 1,
            'maxPoints': 1,
            'studentAnswer': '1/2',
          },
          'Q2': {
            'itemNumber': 2,
            'questionId': 'Q2',
            'competencyCode': 'C2',
            'contentDomain': 'Fractions',
            'correct': true,
            'pointsEarned': 1,
            'maxPoints': 1,
            'studentAnswer': '3/4',
          },
        },
      };

      final parsed = StudentResult.fromMap(legacyPostMap, 'post_doc_1');

      expect(parsed.studentId, 'post_user');
      expect(parsed.questionResults?.length, 2);
      expect(parsed.questionResults?[0].questionId, 'Q1');
      expect(parsed.questionResults?[0].isCorrect, isTrue);
      expect(parsed.questionResults?[0].selectedAnswer, '1/2');
      expect(parsed.questionResults?[1].questionId, 'Q2');
      expect(parsed.questionResults?[1].selectedAnswer, '3/4');
    });

    test('parses legacy diagnostic doc with List-shaped itemBreakdown', () {
      final legacyDiagMap = {
        'studentId': 'diag_user',
        'assessmentType': 'DIAGNOSTIC',
        'score': 15,
        'maxScore': 20,
        'percentage': 75.0,
        'assignedTier': 'Intermediate',
        'startingLevel': 21,
        'competencyScores': {'Number Sense': 0.75},
        'diagnosticFlags': <String>[],
        'itemBreakdown': [
          {
            'itemNumber': 1,
            'questionId': 'L1-Q1',
            'competencyCode': 'M1NS-Ia-1',
            'competencyTag': 'Number Sense',
            'isCorrect': true,
            'studentAnswer': 'B',
          }
        ],
        'timestamp': Timestamp.now(),
      };

      final parsed = StudentResult.fromMap(legacyDiagMap, 'diag_doc_1');

      expect(parsed.studentId, 'diag_user');
      expect(parsed.assignedTier, 'Intermediate');
      expect(parsed.startingLevel, 21);
      expect(parsed.questionResults?.length, 1);
      expect(parsed.questionResults?.first.contentDomain, 'Number Sense');
      expect(parsed.questionResults?.first.selectedAnswer, 'B');
      expect(parsed.questionResults?.first.isCorrect, isTrue);
    });
  });
}
