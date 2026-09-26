import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/errors/auth_exception.dart';

void main() {
  group('StudentProfile Model Tests', () {
    test('Should parse StudentProfile map correctly with nested StudentStats', () {
      final sampleMap = {
        'lrn': '123456789001',
        'name': 'Juan Dela Cruz',
        'role': 'student',
        'gradeLevel': 4,
        'assignedCategory': 'Intermediate',
        'currentLevel': 25,
        'startingLevel': 21,
        'diagnosticCompleted': true,
        'verificationCode': 'MTH-AB12',
        'usedQuestionsHistory': ['G4_Q1', 'G4_Q2'],
        'stats': {
          'totalXp': 450,
          'coins': 120,
          'streakDays': 5,
        }
      };

      final profile = StudentProfile.fromMap(sampleMap, 'test_uid_123');

      expect(profile.uid, equals('test_uid_123'));
      expect(profile.lrn, equals('123456789001'));
      expect(profile.displayName, equals('Juan Dela Cruz'));
      expect(profile.role, equals('student'));
      expect(profile.gradeLevel, equals(4));
      expect(profile.assignedCategory, equals('Intermediate'));
      expect(profile.currentLevel, equals(25));
      expect(profile.startingLevel, equals(21));
      expect(profile.diagnosticCompleted, isTrue);
      expect(profile.verificationCode, equals('MTH-AB12'));
      expect(profile.usedQuestionsHistory, containsAll(['G4_Q1', 'G4_Q2']));
      expect(profile.stats.totalXp, equals(450));
      expect(profile.stats.coins, equals(120));
      expect(profile.stats.streakDays, equals(5));
    });

    test('Should convert StudentProfile to Map correctly', () {
      final profile = StudentProfile(
        uid: 'uid_999',
        lrn: '987654321099',
        displayName: 'Maria Santos',
        gradeLevel: 5,
        assignedCategory: 'Mastery',
        currentLevel: 45,
        startingLevel: 41,
        stats: const StudentStats(totalXp: 1200, coins: 300, streakDays: 10),
        usedQuestionsHistory: ['G5_Q30A'],
        diagnosticCompleted: true,
        verificationCode: 'MTH-XY88',
      );

      final map = profile.toMap();

      expect(map['uid'], equals('uid_999'));
      expect(map['lrn'], equals('987654321099'));
      expect(map['displayName'], equals('Maria Santos'));
      expect(map['role'], equals('student'));
      expect(map['gradeLevel'], equals(5));
      expect(map['assignedCategory'], equals('Mastery'));
      expect(map['currentLevel'], equals(45));
      expect(map['startingLevel'], equals(41));
      expect(map['stats']['totalXp'], equals(1200));
      expect(map['usedQuestionsHistory'], contains('G5_Q30A'));
      expect(map['verificationCode'], equals('MTH-XY88'));
    });
  });

  group('AuthException Tests', () {
    test('Should display user-friendly message', () {
      final exception = AuthException('Invalid LRN format', code: 'INVALID_LRN');
      expect(exception.toString(), equals('Invalid LRN format'));
      expect(exception.code, equals('INVALID_LRN'));
    });
  });
}
