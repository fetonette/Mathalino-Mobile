import 'package:cloud_firestore/cloud_firestore.dart';

/// Nested Statistics Model for Student Profile
class StudentStats {
  final int totalXp;
  final int coins;
  final int streakDays;
  final Timestamp? lastActiveDate;

  const StudentStats({
    this.totalXp = 0,
    this.coins = 0,
    this.streakDays = 0,
    this.lastActiveDate,
  });

  factory StudentStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StudentStats();
    return StudentStats(
      totalXp: (map['totalXp'] ?? map['currentXP'] ?? map['xp'] ?? 0) as int,
      coins: (map['coins'] ?? 0) as int,
      streakDays: (map['streakDays'] ?? map['readingStreak'] ?? 0) as int,
      lastActiveDate: map['lastActiveDate'] is Timestamp
          ? map['lastActiveDate'] as Timestamp
          : (map['lastActive'] is Timestamp ? map['lastActive'] as Timestamp : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalXp': totalXp,
      'coins': coins,
      'streakDays': streakDays,
      'lastActiveDate': lastActiveDate,
    };
  }
}

/// Student Profile Model representing /users/{uid} documents in Firestore
class StudentProfile {
    final String uid;
  final String lrn;
  final String displayName;
  final String role;
  final int gradeLevel; // Numeric grade (1–6). Parsed from either int or "Grade 3" string.
  final String gradeLevelLabel; // Human-readable grade label e.g. "Grade 3"
  final String section;
  final String studentStatus;
  final bool needsTeacherSupport;
  final String parentGuardianName;
  final String parentGuardianEmail;
  final String parentGuardianPhone;
  final bool isParentLinked;
  final String linkedParentUid;
  final String assignedCategory;
  final String assignedTier; // 'Foundation' | 'Intermediate' | 'Advanced'
  final int currentLevel;
  final int startingLevel;
  final StudentStats stats;
  final List<String> usedQuestionsHistory;
  final bool diagnosticCompleted;
  final int diagnosticScore; // 0-20, number of correct answers on diagnostic
  final double diagnosticPercentage; // Percentage score on diagnostic
  final List<String> diagnosticFlags; // 'Needs Attention' competencies (Rule I only)
  final Timestamp? diagnosticCompletedAt; // When diagnostic was completed
  final Timestamp? diagnosticTimestamp;
  final String contentPool; // Spec label: 'Grade 1-3', 'Grade 1-6 Shuffled', etc.
  final List<String> completedZones; // e.g. ['ZONE_1', 'ZONE_2', 'ZONE_3']
    final Map<String, String> masteryOverview;
  final String verificationCode;
  final String avatarUrl;
    final Timestamp? updatedAt;
  final Map<String, String> levelStatusMap;

  const StudentProfile({
    required this.uid,
    required this.lrn,
    required this.displayName,
    this.role = 'student',
    required this.gradeLevel,
    this.gradeLevelLabel = '',
    this.section = '',
    this.studentStatus = 'active',
    this.needsTeacherSupport = false,
    this.parentGuardianName = '',
    this.parentGuardianEmail = '',
    this.parentGuardianPhone = '',
    this.isParentLinked = false,
    this.linkedParentUid = '',
    required this.assignedCategory,
    this.assignedTier = 'Foundation',
    required this.currentLevel,
    required this.startingLevel,
    required this.stats,
    required this.usedQuestionsHistory,
    required this.diagnosticCompleted,
    this.diagnosticScore = 0,
    this.diagnosticPercentage = 0.0,
    this.diagnosticFlags = const [],
    this.diagnosticCompletedAt,
    this.diagnosticTimestamp,
    this.contentPool = '',
    this.completedZones = const [],
    this.masteryOverview = const {},
            required this.verificationCode,
    this.avatarUrl = '',
    this.levelStatusMap = const {},
    this.updatedAt,
  });

  /// Factory constructor to build StudentProfile from Firestore Map and UID
  factory StudentProfile.fromMap(Map<String, dynamic> map, String uid) {
    final rawStats = map['stats'] is Map<String, dynamic>
        ? map['stats'] as Map<String, dynamic>
        : map;

    final historyList = (map['usedQuestionsHistory'] ?? map['usedQuestionIds'] ?? []) as List<dynamic>;

    // Parse gradeLevel robustly:
    // - If it's an int (e.g. 3) → gradeLevel = 3, label = "Grade 3"
    // - If it's a string "Grade 3" → gradeLevel = 3, label = "Grade 3"
    // - If it's a string "3" → gradeLevel = 3, label = "Grade 3"
    // - If missing → gradeLevel = 1, label = "Grade 1"
    final rawGrade = map['gradeLevel'] ?? map['grade'] ?? 1;
    final String gradeLabel;
    final int gradeNumber;

    if (rawGrade is int) {
      gradeNumber = rawGrade;
      gradeLabel = 'Grade $rawGrade';
    } else if (rawGrade is String) {
      final trimmed = rawGrade.trim();
      // Try to extract the numeric part from strings like "Grade 3" or "3"
      final match = RegExp(r'(\d+)').firstMatch(trimmed);
      if (match != null) {
        gradeNumber = int.parse(match.group(1)!);
        gradeLabel = trimmed.startsWith('Grade', 0)
            ? trimmed
            : 'Grade $gradeNumber';
      } else {
        gradeNumber = 1;
        gradeLabel = trimmed.isEmpty ? 'Grade 1' : trimmed;
      }
    } else {
      gradeNumber = 1;
      gradeLabel = 'Grade 1';
    }

    final flagsList = (map['diagnosticFlags'] is List)
        ? (map['diagnosticFlags'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    final tier = map['assignedTier']?.toString() ??
        map['assignedCategory']?.toString() ??
        'Foundation';

    return StudentProfile(
      uid: uid,
      lrn: map['lrn']?.toString() ?? '',
      displayName: map['displayName']?.toString() ??
          map['fullName']?.toString() ??
          map['name']?.toString() ??
          'Student',
      role: map['role']?.toString() ?? 'student',
      gradeLevel: gradeNumber,
      gradeLevelLabel: gradeLabel,
      section: map['section']?.toString() ?? '',
      studentStatus: map['status']?.toString() ??
          map['studentStatus']?.toString() ??
          'active',
      needsTeacherSupport: map['needsTeacherSupport'] == true ||
          (map['remediation'] is Map &&
              (map['remediation'] as Map)['needsTeacherSupport'] == true),
      parentGuardianName: (map['parentDetails'] is Map
              ? (map['parentDetails'] as Map)['parentName']
              : map['parentGuardianName'])
          ?.toString() ??
          '',
      parentGuardianEmail: (map['parentDetails'] is Map
              ? (map['parentDetails'] as Map)['parentEmail']
              : map['parentGuardianEmail'])
          ?.toString() ??
          '',
      parentGuardianPhone: (map['parentDetails'] is Map
              ? (map['parentDetails'] as Map)['parentPhone']
              : map['parentGuardianPhone'])
          ?.toString() ??
          '',
      isParentLinked: map['isParentLinked'] == true ||
          (map['parentDetails'] is Map &&
              (map['parentDetails'] as Map)['isLinked'] == true),
      linkedParentUid: map['linkedParentUid']?.toString() ?? '',
      assignedCategory: map['assignedCategory']?.toString() ??
          map['assignedTier']?.toString() ??
          tier,
      assignedTier: tier,
      currentLevel: (map['currentLevel'] ?? map['level'] ?? 1) as int,
      startingLevel: (map['startingLevel'] ?? 1) as int,
      stats: StudentStats.fromMap(rawStats),
      usedQuestionsHistory: historyList.map((e) => e.toString()).toList(),
      diagnosticCompleted: map['diagnosticCompleted'] == true,
      diagnosticScore: (map['diagnosticScore'] ?? 0) as int,
      diagnosticPercentage: ((map['diagnosticPercentage'] ?? map['percentage'] ?? 0.0) as num).toDouble(),
      diagnosticFlags: flagsList,
      diagnosticCompletedAt: map['diagnosticCompletedAt'] is Timestamp
          ? map['diagnosticCompletedAt'] as Timestamp
          : (map['diagnosticTimestamp'] is Timestamp
              ? map['diagnosticTimestamp'] as Timestamp
              : null),
      diagnosticTimestamp: map['diagnosticTimestamp'] is Timestamp
          ? map['diagnosticTimestamp'] as Timestamp
          : (map['diagnosticCompletedAt'] is Timestamp
              ? map['diagnosticCompletedAt'] as Timestamp
              : null),
      contentPool: map['contentPool']?.toString() ?? '',
      completedZones: (map['completedZones'] is List)
          ? (map['completedZones'] as List).map((e) => e.toString()).toList()
          : const [],
      masteryOverview: (map['masteryOverview'] is Map)
          ? (map['masteryOverview'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
                        verificationCode: map['verificationCode']?.toString() ??
        map['parentVerificationCode']?.toString() ??
        ((map['parentDetails'] is Map)
            ? (((map['parentDetails']) as Map)['verificationCode']?.toString())
            : null) ??
        'MTH-0000',
      avatarUrl: map['avatarUrl']?.toString() ?? map['avatar']?.toString() ?? '',
      levelStatusMap: (map['levelStatus'] is Map)
          ? (map['levelStatus'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      updatedAt: map['updatedAt'] is Timestamp ? map['updatedAt'] as Timestamp : null,
    );
  }

  /// Typed Firestore converter from DocumentSnapshot
  factory StudentProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    if (data == null) {
      throw FormatException('User document ${snapshot.id} contains null data');
    }
    return StudentProfile.fromMap(data, snapshot.id);
  }

  /// Convert StudentProfile to Map for Firestore writes
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'lrn': lrn,
      'displayName': displayName,
      'fullName': displayName,
      'role': 'student',
      'gradeLevel': gradeLevel,
      'gradeLevelLabel': gradeLevelLabel,
      'section': section,
      'status': studentStatus,
      'needsTeacherSupport': needsTeacherSupport,
      'parentGuardianName': parentGuardianName,
      'parentGuardianEmail': parentGuardianEmail,
      'parentGuardianPhone': parentGuardianPhone,
      'isParentLinked': isParentLinked,
      'linkedParentUid': linkedParentUid,
      'assignedCategory': assignedCategory,
      'assignedTier': assignedTier,
      'currentLevel': currentLevel,
      'startingLevel': startingLevel,
      'stats': stats.toMap(),
      'usedQuestionsHistory': usedQuestionsHistory,
      'diagnosticCompleted': diagnosticCompleted,
      'diagnosticScore': diagnosticScore,
      'diagnosticPercentage': diagnosticPercentage,
      'diagnosticFlags': diagnosticFlags,
      'diagnosticCompletedAt': diagnosticCompletedAt,
      'diagnosticTimestamp': diagnosticTimestamp,
      'contentPool': contentPool,
      'completedZones': completedZones,
      'masteryOverview': masteryOverview,
      'verificationCode': verificationCode,
      'avatarUrl': avatarUrl,
      'levelStatus': levelStatusMap,
      'updatedAt': updatedAt,
    };
  }

  /// Typed Firestore converter for writing
  Map<String, dynamic> toFirestore([SetOptions? options]) {
    return toMap();
  }

  /// Firestore Converter object helper
  static CollectionReference<StudentProfile> collection(FirebaseFirestore firestore) {
    return firestore.collection('users').withConverter<StudentProfile>(
          fromFirestore: (snapshot, _) => StudentProfile.fromFirestore(snapshot),
          toFirestore: (profile, _) => profile.toFirestore(),
        );
  }
}