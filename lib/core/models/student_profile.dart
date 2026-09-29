/// Nested Statistics Model for Student Profile
class StudentStats {
  final int totalXp;
  final int coins;
  final int streakDays;
  final DateTime? lastActiveDate;

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
      lastActiveDate: _parseDateTime(map['lastActiveDate'] ?? map['lastActive']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalXp': totalXp,
      'coins': coins,
      'streakDays': streakDays,
      'lastActiveDate': lastActiveDate?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  // Handle Firestore Timestamp if still present during transition
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

/// Student Profile Model representing the `users` table in Supabase
class StudentProfile {
  final String uid;
  final String lrn;
  final String displayName;
  final String role;
  final int gradeLevel;
  final String gradeLevelLabel;
  final String section;
  final String studentStatus;
  final bool needsTeacherSupport;
  final String parentGuardianName;
  final String parentGuardianEmail;
  final String parentGuardianPhone;
  final bool isParentLinked;
  final String linkedParentUid;
  final String assignedCategory;
  final String assignedTier;
  final int currentLevel;
  final int startingLevel;
  final StudentStats stats;
  final List<String> usedQuestionsHistory;
  final bool diagnosticCompleted;
  final int diagnosticScore;
  final double diagnosticPercentage;
  final List<String> diagnosticFlags;
  final DateTime? diagnosticCompletedAt;
  final DateTime? diagnosticTimestamp;
  final String contentPool;
  final List<String> completedZones;
  final Map<String, String> masteryOverview;
  final String verificationCode;
  final String avatarUrl;
  final DateTime? updatedAt;
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

  /// Factory constructor from Supabase row map or merged dictionary
  factory StudentProfile.fromMap(Map<String, dynamic> map, String uid) {
    final historyList =
        (map['used_questions_history'] ?? map['usedQuestionsHistory'] ?? map['question_history'] ?? map['usedQuestionIds'] ?? []) as List<dynamic>;

    final rawGrade = map['grade_level'] ?? map['gradeLevel'] ?? map['grade'] ?? 1;
    final String gradeLabel;
    final int gradeNumber;

    if (rawGrade is int) {
      gradeNumber = rawGrade;
      gradeLabel = 'Grade $rawGrade';
    } else if (rawGrade is String) {
      final trimmed = rawGrade.trim();
      final match = RegExp(r'(\d+)').firstMatch(trimmed);
      if (match != null) {
        gradeNumber = int.parse(match.group(1)!);
        gradeLabel = trimmed.startsWith('Grade', 0) ? trimmed : 'Grade $gradeNumber';
      } else {
        gradeNumber = 1;
        gradeLabel = trimmed.isEmpty ? 'Grade 1' : trimmed;
      }
    } else {
      gradeNumber = 1;
      gradeLabel = 'Grade 1';
    }

    final flagsList = (map['diagnostic_flags'] ?? map['diagnosticFlags'] ?? map['flags']) is List
        ? ((map['diagnostic_flags'] ?? map['diagnosticFlags'] ?? map['flags']) as List).map((e) => e.toString()).toList()
        : const <String>[];

    final tier = map['assigned_tier']?.toString() ??
        map['assignedTier']?.toString() ??
        map['assignedCategory']?.toString() ??
        map['mathalino_tier']?.toString() ??
        'Beginner';

    // Parse stats — robust support for nested stats map, flat Supabase columns, and legacy currentXP
    final statsObj = map['stats'];
    final statsMap = <String, dynamic>{
      'totalXp': (statsObj is Map ? (statsObj['totalXp'] ?? statsObj['currentXP'] ?? statsObj['xp']) : null) ??
          map['total_xp'] ?? map['current_xp'] ?? map['currentXP'] ?? map['totalXp'] ?? map['xp'] ?? 0,
      'coins': (statsObj is Map ? statsObj['coins'] : null) ??
          map['coins'] ?? 0,
      'streakDays': (statsObj is Map ? (statsObj['streakDays'] ?? statsObj['streak_days'] ?? statsObj['readingStreak']) : null) ??
          map['streak_days'] ?? map['streakDays'] ?? 0,
      'lastActiveDate': (statsObj is Map ? (statsObj['lastActiveDate'] ?? statsObj['last_active_date'] ?? statsObj['lastActive']) : null) ??
          map['last_active_date'] ?? map['lastActiveDate'] ?? map['last_login'],
    };

    final diagObj = map['diagnostic'] is Map ? (map['diagnostic'] as Map) : null;

    final diagCompleted = map['diagnostic_completed'] == true ||
        map['diagnosticCompleted'] == true ||
        diagObj?['completed'] == true;

    final diagScore = (map['diagnostic_score'] ?? map['diagnosticScore'] ?? diagObj?['score'] ?? 0) as int;

    final rawPct = map['diagnostic_percentage'] ?? map['diagnosticPercentage'] ?? diagObj?['percentage'] ?? map['percentage'] ?? 0.0;
    final double diagPct;
    if (rawPct is num) {
      diagPct = rawPct.toDouble();
    } else if (rawPct is String) {
      diagPct = double.tryParse(rawPct) ?? 0.0;
    } else {
      diagPct = 0.0;
    }

    final diagCompletedAt = _parseDateTime(
      map['diagnostic_completed_at'] ??
          map['diagnosticCompletedAt'] ??
          map['diagnosticTimestamp'] ??
          diagObj?['completedAt'],
    );

    final contentPoolVal = (map['content_pool'] ?? map['contentPool'] ?? diagObj?['contentPool'] ?? '').toString();

    return StudentProfile(
      uid: uid,
      lrn: (map['lrn'] ?? '').toString(),
      displayName: map['display_name']?.toString() ??
          map['displayName']?.toString() ??
          map['fullName']?.toString() ??
          map['full_name']?.toString() ??
          map['name']?.toString() ??
          'Student',
      role: map['role']?.toString() ?? 'student',
      gradeLevel: gradeNumber,
      gradeLevelLabel: gradeLabel,
      section: (map['section'] ?? '').toString(),
      studentStatus: map['student_status']?.toString() ??
          map['status']?.toString() ??
          map['studentStatus']?.toString() ??
          'active',
      needsTeacherSupport: map['needs_teacher_support'] == true ||
          map['needsTeacherSupport'] == true ||
          (map['remediation'] is Map &&
              (map['remediation'] as Map)['needsTeacherSupport'] == true) ||
          map['remediation_active'] == true,
      parentGuardianName: (map['parent_guardian_name'] ??
              (map['parentDetails'] is Map
                  ? (map['parentDetails'] as Map)['parentName']
                  : (map['parent_details'] is Map
                      ? (map['parent_details'] as Map)['parentName']
                      : map['parentGuardianName'])))
          ?.toString() ??
          '',
      parentGuardianEmail: (map['parent_guardian_email'] ??
              (map['parentDetails'] is Map
                  ? (map['parentDetails'] as Map)['parentEmail']
                  : (map['parent_details'] is Map
                      ? (map['parent_details'] as Map)['parentEmail']
                      : map['parentGuardianEmail'])))
          ?.toString() ??
          '',
      parentGuardianPhone: (map['parent_guardian_phone'] ??
              (map['parentDetails'] is Map
                  ? (map['parentDetails'] as Map)['parentPhone']
                  : (map['parent_details'] is Map
                      ? (map['parent_details'] as Map)['parentPhone']
                      : map['parentGuardianPhone'])))
          ?.toString() ??
          '',
      isParentLinked: map['is_parent_linked'] == true ||
          map['isParentLinked'] == true ||
          (map['parentDetails'] is Map &&
              (map['parentDetails'] as Map)['isLinked'] == true) ||
          (map['parent_details'] is Map &&
              (map['parent_details'] as Map)['isLinked'] == true),
      linkedParentUid: (map['linked_parent_uid'] ?? map['linkedParentUid'] ?? '').toString(),
      assignedCategory: map['assigned_category']?.toString() ??
          map['assignedCategory']?.toString() ??
          map['assignedTier']?.toString() ??
          tier,
      assignedTier: tier,
      currentLevel: (map['current_level'] ?? map['currentLevel'] ?? map['level'] ?? 1) as int,
      startingLevel: (map['starting_level'] ?? map['startingLevel'] ?? diagObj?['startingLevel'] ?? 1) as int,
      stats: StudentStats.fromMap(statsMap),
      usedQuestionsHistory: historyList.map((e) => e.toString()).toList(),
      diagnosticCompleted: diagCompleted,
      diagnosticScore: diagScore,
      diagnosticPercentage: diagPct,
      diagnosticFlags: flagsList,
      diagnosticCompletedAt: diagCompletedAt,
      diagnosticTimestamp: diagCompletedAt,
      contentPool: contentPoolVal,
      completedZones: (map['completed_zones'] ?? map['completedZones']) is List
          ? ((map['completed_zones'] ?? map['completedZones']) as List).map((e) => e.toString()).toList()
          : const [],
      masteryOverview: (map['mastery_overview'] ?? map['masteryOverview'] ?? map['competency_scores']) is Map
          ? ((map['mastery_overview'] ?? map['masteryOverview'] ?? map['competency_scores']) as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      verificationCode: map['verification_code']?.toString() ??
          map['verificationCode']?.toString() ??
          map['parentVerificationCode']?.toString() ??
          ((map['parentDetails'] is Map)
              ? (((map['parentDetails']) as Map)['verificationCode']?.toString())
              : null) ??
          ((map['parent_details'] is Map)
              ? (((map['parent_details']) as Map)['verificationCode']?.toString())
              : null) ??
          'MTH-0000',
      avatarUrl: map['avatar_url']?.toString() ?? map['avatarUrl']?.toString() ?? map['avatar']?.toString() ?? '',
      levelStatusMap: (map['level_status_map'] ?? map['levelStatus']) is Map
          ? ((map['level_status_map'] ?? map['levelStatus']) as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  /// Composite factory building a complete profile from normalized Supabase tables:
  /// `users`, `students`, `student_progress`, and `student_assessments`.
  factory StudentProfile.fromComposite({
    required String uid,
    Map<String, dynamic>? userRow,
    Map<String, dynamic>? studentRow,
    Map<String, dynamic>? progressRow,
    Map<String, dynamic>? assessmentRow,
  }) {
    final merged = <String, dynamic>{
      ...?userRow,
      ...?studentRow,
      ...?progressRow,
      ...?assessmentRow,
    };
    return StudentProfile.fromMap(merged, uid);
  }

  /// Convert to map supporting both snake_case (Supabase) and camelCase (unit tests/legacy)
  Map<String, dynamic> toMap() {
    final statsMap = {
      'totalXp': stats.totalXp,
      'coins': stats.coins,
      'streakDays': stats.streakDays,
      'lastActiveDate': stats.lastActiveDate?.toIso8601String(),
    };

    return {
      'id': uid,
      'uid': uid,
      'lrn': lrn,
      'displayName': displayName,
      'display_name': displayName,
      'name': displayName,
      'full_name': displayName,
      'role': role,
      'gradeLevel': gradeLevel,
      'grade_level': gradeLevel,
      'grade_level_label': gradeLevelLabel,
      'section': section,
      'status': studentStatus,
      'student_status': studentStatus,
      'studentStatus': studentStatus,
      'needs_teacher_support': needsTeacherSupport,
      'needsTeacherSupport': needsTeacherSupport,
      'parent_guardian_name': parentGuardianName,
      'parent_guardian_email': parentGuardianEmail,
      'parent_guardian_phone': parentGuardianPhone,
      'is_parent_linked': isParentLinked,
      'isParentLinked': isParentLinked,
      'linked_parent_uid': linkedParentUid.isEmpty ? null : linkedParentUid,
      'linkedParentUid': linkedParentUid.isEmpty ? null : linkedParentUid,
      'assigned_category': assignedCategory,
      'assignedCategory': assignedCategory,
      'assigned_tier': assignedTier,
      'assignedTier': assignedTier,
      'current_level': currentLevel,
      'currentLevel': currentLevel,
      'starting_level': startingLevel,
      'startingLevel': startingLevel,
      'total_xp': stats.totalXp,
      'current_xp': stats.totalXp,
      'currentXP': stats.totalXp,
      'coins': stats.coins,
      'streak_days': stats.streakDays,
      'streakDays': stats.streakDays,
      'last_active_date': stats.lastActiveDate?.toIso8601String(),
      'lastActiveDate': stats.lastActiveDate?.toIso8601String(),
      'stats': statsMap,
      'used_questions_history': usedQuestionsHistory,
      'usedQuestionsHistory': usedQuestionsHistory,
      'diagnostic_completed': diagnosticCompleted,
      'diagnosticCompleted': diagnosticCompleted,
      'diagnostic_score': diagnosticScore,
      'diagnosticScore': diagnosticScore,
      'diagnostic_percentage': diagnosticPercentage,
      'diagnosticPercentage': diagnosticPercentage,
      'diagnostic_flags': diagnosticFlags,
      'diagnosticFlags': diagnosticFlags,
      'diagnostic_completed_at': diagnosticCompletedAt?.toIso8601String(),
      'diagnosticCompletedAt': diagnosticCompletedAt?.toIso8601String(),
      'diagnostic_timestamp': diagnosticTimestamp?.toIso8601String(),
      'diagnosticTimestamp': diagnosticTimestamp?.toIso8601String(),
      'content_pool': contentPool,
      'contentPool': contentPool,
      'completed_zones': completedZones,
      'completedZones': completedZones,
      'mastery_overview': masteryOverview,
      'masteryOverview': masteryOverview,
      'verification_code': verificationCode,
      'verificationCode': verificationCode,
      'avatar_url': avatarUrl,
      'avatarUrl': avatarUrl,
      'level_status_map': levelStatusMap,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': updatedAt,
    };
  }

  /// Alias for backward compatibility
  Map<String, dynamic> toFirestore([dynamic options]) => toMap();
}