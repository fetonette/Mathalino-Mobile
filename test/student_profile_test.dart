import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mathalino_student_app/core/models/student_profile.dart';

void main() {
  group('StudentProfile.fromMap (teacher dashboard data)', () {
    test('parses fullName, section, status, parentDetails, and avatar from /users doc', () {
      final map = <String, dynamic>{
        'uid': 'student-uid-123',
        'role': 'student',
        'lrn': '123456789012',
        'fullName': 'Juan Dela Cruz',
        'name': 'Juan Dela Cruz',
        'email': '123456789012@student.readquest.edu',
        'gradeLevel': 'Grade 3',
        'section': 'Maitim-1',
        'status': 'active',
        'avatar': 'default_avatar.png',
        'currentXP': 150,
        'coins': 30,
        'parentDetails': {
          'parentName': 'Maria Cruz',
          'parentEmail': 'maria@example.com',
          'parentPhone': '09171234567',
          'verificationCode': 'MTH-ABCD',
        },
        'isParentLinked': true,
        'linkedParentUid': 'parent-uid-999',
      };

      final profile = StudentProfile.fromMap(map, 'student-uid-123');

      expect(profile.uid, 'student-uid-123');
      expect(profile.displayName, 'Juan Dela Cruz');
      expect(profile.lrn, '123456789012');
      expect(profile.role, 'student');
      expect(profile.gradeLevel, 3);
      expect(profile.gradeLevelLabel, 'Grade 3');
      expect(profile.section, 'Maitim-1');
      expect(profile.studentStatus, 'active');
      expect(profile.avatarUrl, 'default_avatar.png');
      expect(profile.parentGuardianName, 'Maria Cruz');
      expect(profile.parentGuardianEmail, 'maria@example.com');
      expect(profile.parentGuardianPhone, '09171234567');
      expect(profile.verificationCode, 'MTH-ABCD');
      expect(profile.isParentLinked, isTrue);
      expect(profile.linkedParentUid, 'parent-uid-999');
    });

    test('parses isParentLinked/linkedParentUid and defaults to false when absent', () {
      final map = <String, dynamic>{
        'uid': 'uid-link',
        'displayName': 'Linked Student',
        'gradeLevel': 2,
        'section': 'Sampaguita',
        'isParentLinked': true,
        'linkedParentUid': 'parent-uid-42',
      };

      final profile = StudentProfile.fromMap(map, 'uid-link');
      expect(profile.isParentLinked, isTrue);
      expect(profile.linkedParentUid, 'parent-uid-42');

      final unlinked = StudentProfile.fromMap({
        'uid': 'uid-unlink',
        'displayName': 'Unlinked Student',
      }, 'uid-unlink');
      expect(unlinked.isParentLinked, isFalse);
      expect(unlinked.linkedParentUid, '');
    });

    test('falls back to displayName when fullName is absent (legacy compat)', () {
      final map = <String, dynamic>{
        'uid': 'uid-456',
        'displayName': 'Legacy Student',
        'gradeLevel': 1,
        'section': 'Section A',
        'status': 'active',
      };

      final profile = StudentProfile.fromMap(map, 'uid-456');

      expect(profile.displayName, 'Legacy Student');
      expect(profile.section, 'Section A');
      expect(profile.studentStatus, 'active');
    });

    test('reads flat currentXP/coins when stats map is absent', () {
      final map = <String, dynamic>{
        'uid': 'uid-789',
        'displayName': 'Test Student',
        'gradeLevel': 2,
        'currentXP': 500,
        'coins': 25,
      };

      final profile = StudentProfile.fromMap(map, 'uid-789');

      expect(profile.stats.totalXp, 500);
      expect(profile.stats.coins, 25);
    });

    test('reads nested stats map when present', () {
      final map = <String, dynamic>{
        'uid': 'uid-012',
        'displayName': 'Stats Student',
        'gradeLevel': 4,
        'stats': {
          'totalXp': 1000,
          'coins': 42,
          'streakDays': 7,
          'lastActiveDate': Timestamp.fromDate(DateTime(2024, 1, 15)),
        },
      };

      final profile = StudentProfile.fromMap(map, 'uid-012');

      expect(profile.stats.totalXp, 1000);
      expect(profile.stats.coins, 42);
      expect(profile.stats.streakDays, 7);
      expect(profile.stats.lastActiveDate, isNotNull);
    });

    test('parses levelStatusMap from Firestore', () {
      final map = <String, dynamic>{
        'uid': 'uid-034',
        'displayName': 'Map Student',
        'gradeLevel': 1,
        'levelStatus': {
          '1': 'completed',
          '2': 'unlocked',
          '3': 'locked',
        },
      };

      final profile = StudentProfile.fromMap(map, 'uid-034');

      expect(profile.levelStatusMap['1'], 'completed');
      expect(profile.levelStatusMap['2'], 'unlocked');
      expect(profile.levelStatusMap['3'], 'locked');
    });

    test('round-trips through toMap and fromMap', () {
      final original = StudentProfile(
        uid: 'uid-rt',
        lrn: '111111111111',
        displayName: 'Round Trip',
        role: 'student',
        gradeLevel: 5,
        gradeLevelLabel: 'Grade 5',
        section: 'Sampaguita',
        studentStatus: 'active',
        parentGuardianName: 'Parent Name',
        parentGuardianEmail: 'parent@test.com',
        parentGuardianPhone: '09998887777',
        assignedCategory: 'Beginner',
        currentLevel: 5,
        startingLevel: 1,
        stats: const StudentStats(totalXp: 200, coins: 10),
        usedQuestionsHistory: ['L1-Q1', 'L2-Q3'],
        diagnosticCompleted: true,
        verificationCode: 'MTH-RT01',
        avatarUrl: 'avatar_1.png',
        levelStatusMap: {'1': 'completed', '2': 'unlocked'},
      );

      final roundTrip = StudentProfile.fromMap(original.toMap(), original.uid);

      expect(roundTrip.uid, original.uid);
      expect(roundTrip.displayName, original.displayName);
      expect(roundTrip.section, original.section);
      expect(roundTrip.studentStatus, original.studentStatus);
      expect(roundTrip.parentGuardianName, original.parentGuardianName);
      expect(roundTrip.parentGuardianEmail, original.parentGuardianEmail);
      expect(roundTrip.parentGuardianPhone, original.parentGuardianPhone);
      expect(roundTrip.avatarUrl, original.avatarUrl);
      expect(roundTrip.levelStatusMap, original.levelStatusMap);
      expect(roundTrip.stats.totalXp, original.stats.totalXp);
    });
  });
}