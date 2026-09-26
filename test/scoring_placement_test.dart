import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/question.dart';
import 'package:mathalino_student_app/core/services/scoring_service.dart';
import 'package:mathalino_student_app/core/services/placement_service.dart';

void main() {
  final scoringService = ScoringService();
  final placementService = PlacementService();

  group('ScoringService Tests', () {
    test('Multiple Choice - Exact letter match', () {
      const q = Question(
        id: 'G4_Q1',
        grade: 4,
        contentDomain: 'Number and Algebra',
        competencyCode: 'M4NS-Ia-13',
        competencyText: 'Addition of large numbers',
        cognitiveDomain: 'Knowing',
        type: 'multipleChoice',
        questionText: '316 x 7 = ?',
        choices: ['A. 21742', 'B. 21142', 'C. 2212', 'D. 2194'],
        correctAnswer: 'C',
        maxPoints: 1,
      );

      expect(scoringService.scoreQuestion(q, 'C'), equals(1));
      expect(scoringService.scoreQuestion(q, 'c'), equals(1));
      expect(scoringService.scoreQuestion(q, 'A'), equals(0));
    });

    test('Multiple Choice - List of accepted string forms', () {
      const q = Question(
        id: 'G4_Q1',
        grade: 4,
        contentDomain: 'Number and Algebra',
        competencyCode: 'M4NS-Ia-13',
        competencyText: 'Addition of large numbers',
        cognitiveDomain: 'Knowing',
        type: 'multipleChoice',
        questionText: '316 x 7 = ?',
        choices: ['A. 21742', 'B. 21142', 'C. 2212', 'D. 2194'],
        correctAnswer: ['C', '2212', 'C. 2212'],
        maxPoints: 1,
      );

      expect(scoringService.scoreQuestion(q, 'C'), equals(1));
      expect(scoringService.scoreQuestion(q, '2212'), equals(1));
      expect(scoringService.scoreQuestion(q, 'C. 2212'), equals(1));
      expect(scoringService.scoreQuestion(q, 'D'), equals(0));
    });

    test('True/False - Case insensitive comparison', () {
      const q = Question(
        id: 'G4_Q23',
        grade: 4,
        contentDomain: 'Geometry',
        competencyCode: 'M4GE-Ia-1',
        competencyText: 'Perimeter comparison',
        cognitiveDomain: 'Reasoning',
        type: 'trueFalse',
        questionText: 'Are the perimeters equal?',
        choices: ['True', 'False'],
        correctAnswer: 'False',
        maxPoints: 1,
      );

      expect(scoringService.scoreQuestion(q, 'false'), equals(1));
      expect(scoringService.scoreQuestion(q, 'False'), equals(1));
      expect(scoringService.scoreQuestion(q, 'true'), equals(0));
    });

    test('Numeric Input - Whitespace stripping & numeric parsing', () {
      const q = Question(
        id: 'G5_Q39',
        grade: 5,
        contentDomain: 'Number and Algebra',
        competencyCode: 'M5NS-IVa-2',
        competencyText: 'GMDAS operations',
        cognitiveDomain: 'Applying',
        type: 'numericInput',
        questionText: '500 - [(15 x 10) + (1/2 x 95)] = ?',
        correctAnswer: '302.5',
        maxPoints: 1,
      );

      expect(scoringService.scoreQuestion(q, ' 302.5 '), equals(1));
      expect(scoringService.scoreQuestion(q, '302.50'), equals(1));
      expect(scoringService.scoreQuestion(q, '300'), equals(0));
    });

    test('Computation - Exact match check with TODO rubric note', () {
      const q = Question(
        id: 'G4_Q21',
        grade: 4,
        contentDomain: 'Number and Algebra',
        competencyCode: 'M4NS-IIIa-10a',
        competencyText: 'Add dissimilar fractions',
        cognitiveDomain: 'Knowing',
        type: 'computation',
        questionText: '4/6 + 3/9 = ?',
        correctAnswer: '1',
        maxPoints: 2,
      );

      expect(scoringService.scoreQuestion(q, '1'), equals(2));
      expect(scoringService.scoreQuestion(q, ' 1 '), equals(2));
      expect(scoringService.scoreQuestion(q, '18/18'), equals(0));
    });
  });

  group('PlacementService Tests', () {
    test('< 50% returns Foundation / Level 1 / Grade 1-3', () {
      final res = placementService.calculatePlacement(9, 20); // 45%
      expect(res.category, equals('Foundation'));
      expect(res.startingLevel, equals(1));
      expect(res.contentPool, equals(['Grade 1', 'Grade 2', 'Grade 3']));
      expect(res.scorePercentage, equals(45.0));
    });

    test('50% - 79% returns Intermediate / Level 21 / Grade 1-6', () {
      final res50 = placementService.calculatePlacement(10, 20); // 50%
      expect(res50.category, equals('Intermediate'));
      expect(res50.startingLevel, equals(21));
      expect(res50.contentPool, equals(['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6']));

      final res75 = placementService.calculatePlacement(15, 20); // 75%
      expect(res75.category, equals('Intermediate'));
      expect(res75.startingLevel, equals(21));
    });

    test('80% - 100% returns Advanced / Level 41 / Grade 1-6 Advanced', () {
      final res80 = placementService.calculatePlacement(16, 20); // 80%
      expect(res80.category, equals('Advanced'));
      expect(res80.startingLevel, equals(41));
      expect(res80.contentPool, equals(['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6 Advanced']));

      final res95 = placementService.calculatePlacement(19, 20); // 95%
      expect(res95.category, equals('Advanced'));
      expect(res95.startingLevel, equals(41));

      final res100 = placementService.calculatePlacement(20, 20); // 100%
      expect(res100.category, equals('Advanced'));
      expect(res100.startingLevel, equals(41));
      expect(res100.scorePercentage, equals(100.0));
    });

    test('Safe handling of 0 total points', () {
      final resZero = placementService.calculatePlacement(0, 0);
      expect(resZero.category, equals('Foundation'));
      expect(resZero.startingLevel, equals(1));
      expect(resZero.scorePercentage, equals(0.0));
    });
  });
}
