import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diagnostic_result.dart';
import '../models/student_profile.dart';
import '../models/student_result_model.dart';

/// Central Supabase read/write wrapper for Mathalino Student App.
///
/// Orchestrates queries and mutations across the normalized Supabase schema:
/// - `users`: Base account identities and credentials
/// - `students`: Enrolled student roster, verification codes, teacher links
/// - `student_progress`: Level progression, level status maps, total XP, coins, streaks
/// - `student_assessments`: Diagnostic status, scores, tiers, milestone data
/// - `student_results`: Individual diagnostic, level, and remediation session audits
/// - `level_progress`: Per-level completion records
/// - `used_questions`: Anti-repetition question history
/// - `student_badges`: Earned student badge achievements
/// - `questions` / `question_bank`: Curriculum question pools
class SupabaseService {
  static final SupabaseService instance = SupabaseService();

  final SupabaseClient? _injectedClient;

  SupabaseService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _safeClient {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client {
    final client = _safeClient;
    if (client == null) {
      throw StateError('Supabase client is not initialized');
    }
    return client;
  }

  // ── Student Profile Composition ──────────────────────────────────────────

  /// Fetches a unified [StudentProfile] for [userId] by composing rows from:
  /// `users`, `students`, `student_progress`, and `student_assessments`.
  Future<StudentProfile?> fetchStudentProfile(String userId) async {
    try {
      final client = _client;

      // 1. Fetch from users table
      final userRow = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) return null;

      final lrn = userRow['lrn']?.toString();

      // 2. Fetch from students table (by lrn or uid)
      Map<String, dynamic>? studentRow;
      if (lrn != null && lrn.isNotEmpty) {
        studentRow = await client
            .from('students')
            .select()
            .eq('lrn', lrn)
            .maybeSingle();
      }
      studentRow ??= await client
          .from('students')
          .select()
          .eq('uid', userId)
          .maybeSingle();

      // 3. Fetch from student_progress table (by lrn or uid)
      Map<String, dynamic>? progressRow;
      if (lrn != null && lrn.isNotEmpty) {
        progressRow = await client
            .from('student_progress')
            .select()
            .eq('lrn', lrn)
            .maybeSingle();
      }
      progressRow ??= await client
          .from('student_progress')
          .select()
          .eq('uid', userId)
          .maybeSingle();

      // 4. Fetch from student_assessments table (by lrn or uid)
      Map<String, dynamic>? assessmentRow;
      if (lrn != null && lrn.isNotEmpty) {
        assessmentRow = await client
            .from('student_assessments')
            .select()
            .eq('lrn', lrn)
            .maybeSingle();
      }
      assessmentRow ??= await client
          .from('student_assessments')
          .select()
          .eq('uid', userId)
          .maybeSingle();

      return StudentProfile.fromComposite(
        uid: userId,
        userRow: userRow,
        studentRow: studentRow,
        progressRow: progressRow,
        assessmentRow: assessmentRow,
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null; // No rows found
      debugPrint('[SupabaseService] fetchStudentProfile error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseService] fetchStudentProfile error: $e');
      rethrow;
    }
  }

  /// Subscribes to real-time profile updates for [userId].
  /// Emits the refreshed composite [StudentProfile] whenever updates occur.
  Stream<StudentProfile> subscribeStudentProfile(String userId) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((_) async {
          final profile = await fetchStudentProfile(userId);
          if (profile == null) {
            throw Exception('Student profile $userId does not exist');
          }
          return profile;
        });
  }

  /// Upserts the student profile across the appropriate database tables.
  Future<void> writeStudentProfile(StudentProfile profile) async {
    try {
      final client = _client;
      final now = DateTime.now().toIso8601String();

      // 1. Update users
      await client.from('users').update({
        'name': profile.displayName,
        'full_name': profile.displayName,
        'section': profile.section,
        'current_xp': profile.stats.totalXp,
        'coins': profile.stats.coins,
        'updated_at': now,
      }).eq('id', profile.uid);

      // 2. Update students
      if (profile.lrn.isNotEmpty) {
        await client.from('students').update({
          'name': profile.displayName,
          'full_name': profile.displayName,
          'section': profile.section,
          'current_xp': profile.stats.totalXp,
          'coins': profile.stats.coins,
          'status': profile.studentStatus,
          'updated_at': now,
        }).eq('lrn', profile.lrn);
      }

      // 3. Update student_progress
      final spPayload = {
        'current_level': profile.currentLevel,
        'starting_level': profile.startingLevel,
        'level_status_map': profile.levelStatusMap,
        'question_history': profile.usedQuestionsHistory,
        'total_xp': profile.stats.totalXp,
        'coins': profile.stats.coins,
        'streak_days': profile.stats.streakDays,
        'completed_zones': profile.completedZones,
        'updated_at': now,
      };
      if (profile.lrn.isNotEmpty) {
        await client.from('student_progress').update(spPayload).eq('lrn', profile.lrn);
      } else {
        await client.from('student_progress').update(spPayload).eq('uid', profile.uid);
      }

      // 4. Update student_assessments
      final saPayload = {
        'diagnostic_completed': profile.diagnosticCompleted,
        'diagnostic_score': profile.diagnosticScore,
        'diagnostic_percentage': profile.diagnosticPercentage,
        'assigned_tier': profile.assignedTier,
        'starting_level': profile.startingLevel,
        'diagnostic_completed_at': profile.diagnosticCompletedAt?.toIso8601String(),
        'updated_at': now,
      };
      if (profile.lrn.isNotEmpty) {
        await client.from('student_assessments').update(saPayload).eq('lrn', profile.lrn);
      } else {
        await client.from('student_assessments').update(saPayload).eq('uid', profile.uid);
      }
    } catch (e) {
      debugPrint('[SupabaseService] writeStudentProfile error: $e');
      rethrow;
    }
  }

  /// Updates specific fields by intelligently routing them to the correct table
  /// (`student_progress`, `student_assessments`, `users`, or `students`).
  Future<void> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final client = _client;
      final now = DateTime.now().toIso8601String();

      // Retrieve LRN to allow targeted foreign key updates
      String lrn = (fields['lrn'] ?? '').toString();
      if (lrn.isEmpty) {
        final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
        lrn = u?['lrn']?.toString() ?? '';
      }

      // 1. Separate fields into table-specific buckets
      final userUpdates = <String, dynamic>{'updated_at': now};
      final studentUpdates = <String, dynamic>{'updated_at': now};
      final progressUpdates = <String, dynamic>{'updated_at': now};
      final assessmentUpdates = <String, dynamic>{'updated_at': now};

      for (final entry in fields.entries) {
        final k = entry.key;
        final v = entry.value;

        if (k == 'name' || k == 'full_name' || k == 'displayName' || k == 'fullName') {
          userUpdates['full_name'] = v;
          userUpdates['name'] = v;
          studentUpdates['full_name'] = v;
          studentUpdates['name'] = v;
        } else if (k == 'section') {
          userUpdates['section'] = v;
          studentUpdates['section'] = v;
        } else if (k == 'status' || k == 'student_status' || k == 'studentStatus') {
          studentUpdates['status'] = v;
        } else if (k == 'total_xp' || k == 'current_xp' || k == 'currentXP' || k == 'totalXp') {
          userUpdates['current_xp'] = v;
          studentUpdates['current_xp'] = v;
          progressUpdates['total_xp'] = v;
        } else if (k == 'coins') {
          userUpdates['coins'] = v;
          studentUpdates['coins'] = v;
          progressUpdates['coins'] = v;
        } else if (k == 'current_level' || k == 'currentLevel' || k == 'level') {
          progressUpdates['current_level'] = v;
        } else if (k == 'starting_level' || k == 'startingLevel') {
          progressUpdates['starting_level'] = v;
          assessmentUpdates['starting_level'] = v;
        } else if (k == 'level_status_map' || k == 'levelStatus') {
          progressUpdates['level_status_map'] = v;
        } else if (k == 'used_questions_history' || k == 'usedQuestionsHistory' || k == 'question_history') {
          progressUpdates['question_history'] = v;
        } else if (k == 'completed_zones' || k == 'completedZones') {
          progressUpdates['completed_zones'] = v;
        } else if (k == 'streak_days' || k == 'streakDays') {
          progressUpdates['streak_days'] = v;
        } else if (k == 'remediation') {
          progressUpdates['remediation'] = v;
          if (v is Map && v['active'] == true) {
            progressUpdates['remediation_active'] = true;
          }
        } else if (k == 'diagnostic_completed' || k == 'diagnosticCompleted') {
          assessmentUpdates['diagnostic_completed'] = v;
        } else if (k == 'diagnostic_score' || k == 'diagnosticScore') {
          assessmentUpdates['diagnostic_score'] = v;
        } else if (k == 'diagnostic_percentage' || k == 'diagnosticPercentage') {
          assessmentUpdates['diagnostic_percentage'] = v;
        } else if (k == 'assigned_tier' || k == 'assignedTier' || k == 'assignedCategory' || k == 'assigned_category') {
          assessmentUpdates['assigned_tier'] = v;
        } else if (k == 'diagnostic_completed_at' || k == 'diagnosticCompletedAt') {
          assessmentUpdates['diagnostic_completed_at'] = v;
        } else if (k == 'mastery_overview' || k == 'masteryOverview') {
          assessmentUpdates['competency_scores'] = v;
        }
      }

      // Execute targeted updates
      if (userUpdates.length > 1) {
        await client.from('users').update(userUpdates).eq('id', userId);
      }
      if (lrn.isNotEmpty && studentUpdates.length > 1) {
        await client.from('students').update(studentUpdates).eq('lrn', lrn);
      }
      if (progressUpdates.length > 1) {
        Map<String, dynamic>? currentSp;
        if (lrn.isNotEmpty) {
          currentSp = await client.from('student_progress').select().eq('lrn', lrn).maybeSingle();
        }
        currentSp ??= await client.from('student_progress').select().eq('uid', userId).maybeSingle();

        final rawData = Map<String, dynamic>.from(currentSp?['raw_data'] as Map? ?? {});
        if (progressUpdates.containsKey('current_level')) {
          rawData['currentLevel'] = progressUpdates['current_level'];
        }
        if (progressUpdates.containsKey('level_status_map')) {
          rawData['levelStatusMap'] = progressUpdates['level_status_map'];
        }
        if (progressUpdates.containsKey('total_xp')) {
          rawData['totalXp'] = progressUpdates['total_xp'];
        }
        if (progressUpdates.containsKey('coins')) {
          rawData['coins'] = progressUpdates['coins'];
        }
        rawData['updatedAt'] = now;
        progressUpdates['raw_data'] = rawData;

        if (currentSp == null) {
          progressUpdates['uid'] = userId;
          if (lrn.isNotEmpty) progressUpdates['lrn'] = lrn;
          await client.from('student_progress').insert(progressUpdates);
        } else {
          if (lrn.isNotEmpty) {
            await client.from('student_progress').update(progressUpdates).eq('lrn', lrn);
          } else {
            await client.from('student_progress').update(progressUpdates).eq('uid', userId);
          }
        }
      }
      if (assessmentUpdates.length > 1) {
        if (lrn.isNotEmpty) {
          await client.from('student_assessments').update(assessmentUpdates).eq('lrn', lrn);
        } else {
          await client.from('student_assessments').update(assessmentUpdates).eq('uid', userId);
        }
      }
    } catch (e) {
      debugPrint('[SupabaseService] updateUserFields error: $e');
      rethrow;
    }
  }

  /// Updates user fields with an initial existence verification.
  Future<void> updateUserFieldsInTransaction(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    await updateUserFields(userId, fields);
  }

  // ── Level Progression ──────────────────────────────────────────────────────

  /// Records level completion, unlocking the subsequent level node,
  /// updating `student_progress`, upserting `level_progress`, and inserting a
  /// `student_results` session record.
  Future<void> saveLevelCompletion({
    required String userId,
    required String lrn,
    required int level,
    required int nextLevel,
    required bool isGameComplete,
    required List<String> usedQuestions,
    required int score,
    required int maxScore,
    required double accuracyPct,
    required bool isChallenge,
    required String difficulty,
    required String zone,
  }) async {
    final client = _client;
    final now = DateTime.now().toIso8601String();

    String resolvedLrn = lrn;
    if (resolvedLrn.isEmpty) {
      final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
      resolvedLrn = u?['lrn']?.toString() ?? '';
    }

    // 1. Fetch current progress
    Map<String, dynamic>? currentSp;
    if (resolvedLrn.isNotEmpty) {
      currentSp = await client
          .from('student_progress')
          .select()
          .eq('lrn', resolvedLrn)
          .maybeSingle();
    }
    currentSp ??= await client
        .from('student_progress')
        .select()
        .eq('uid', userId)
        .maybeSingle();

    final currentMap = Map<String, dynamic>.from(
      currentSp?['level_status_map'] as Map? ?? {},
    );
    currentMap[level.toString()] = 'completed';
    if (!isGameComplete) {
      currentMap[nextLevel.toString()] = 'unlocked';
    }

    final currentHistory =
        (currentSp?['question_history'] as List?)?.cast<String>() ?? [];
    final updatedHistory = {...currentHistory, ...usedQuestions}.toList();

    final xpGain = isChallenge ? 100 : 50;
    final coinGain = isChallenge ? 20 : 10;
    final currentXp = (currentSp?['total_xp'] as int?) ?? 0;
    final currentCoins = (currentSp?['coins'] as int?) ?? 0;

    final rawData = Map<String, dynamic>.from(currentSp?['raw_data'] as Map? ?? {});
    rawData['currentLevel'] = nextLevel;
    rawData['levelStatusMap'] = currentMap;
    rawData['totalXp'] = currentXp + xpGain;
    rawData['coins'] = currentCoins + coinGain;
    rawData['updatedAt'] = now;

    // 2. Update student_progress
    final spPayload = {
      'current_level': nextLevel,
      'level_status_map': currentMap,
      'question_history': updatedHistory,
      'total_xp': currentXp + xpGain,
      'coins': currentCoins + coinGain,
      'remediation_active': false,
      'raw_data': rawData,
      'updated_at': now,
    };
    if (currentSp == null) {
      spPayload['uid'] = userId;
      if (resolvedLrn.isNotEmpty) spPayload['lrn'] = resolvedLrn;
      spPayload['starting_level'] = 1;
      await client.from('student_progress').insert(spPayload);
    } else {
      if (resolvedLrn.isNotEmpty) {
        await client.from('student_progress').update(spPayload).eq('lrn', resolvedLrn);
      } else {
        await client.from('student_progress').update(spPayload).eq('uid', userId);
      }
    }

    // 3. Upsert level_progress
    if (resolvedLrn.isNotEmpty) {
      try {
        await client.from('level_progress').upsert({
          'student_lrn': resolvedLrn,
          'level': level,
          'status': 'completed',
          'stars': accuracyPct >= 90 ? 3 : (accuracyPct >= 60 ? 2 : 1),
          'best_score': score,
          'updated_at': now,
        });
      } catch (e) {
        debugPrint('[SupabaseService] level_progress upsert warning: $e');
      }
    }

    // 4. Record used questions in used_questions table
    if (resolvedLrn.isNotEmpty && usedQuestions.isNotEmpty) {
      for (final qId in usedQuestions) {
        try {
          await client.from('used_questions').insert({
            'student_lrn': resolvedLrn,
            'question_id': qId,
            'level': level,
            'is_correct': true,
            'answered_at': now,
          });
        } catch (_) {}
      }
    }

    // 5. Insert student_results audit
    final assessmentType = isChallenge ? 'LEVEL_CHALLENGE' : 'LEVEL_PRACTICE';
    await client.from('student_results').insert({
      'student_uid': userId,
      if (resolvedLrn.isNotEmpty) 'lrn': resolvedLrn,
      'assessment_type': assessmentType,
      'level_number': level,
      'score': score,
      'max_score': maxScore,
      'percentage': accuracyPct,
      'accuracy': maxScore > 0 ? score / maxScore : 0.0,
      'xp_awarded': xpGain,
      'coins_awarded': coinGain,
      'stars': accuracyPct >= 90 ? 3 : (accuracyPct >= 60 ? 2 : 1),
      'result_data': {
        'studentId': userId,
        'level': level,
        'score': score,
        'maxScore': maxScore,
        'percentage': accuracyPct,
        'isChallenge': isChallenge,
        'difficulty': difficulty,
        'zone': zone,
      },
      'created_at': now,
    });

    // 6. Sync XP & coins to users and students tables
    try {
      await client.from('users').update({
        'current_xp': currentXp + xpGain,
        'coins': currentCoins + coinGain,
        'updated_at': now,
      }).eq('id', userId);
    } catch (_) {}

    if (resolvedLrn.isNotEmpty) {
      try {
        await client.from('students').update({
          'current_xp': currentXp + xpGain,
          'coins': currentCoins + coinGain,
          'stats': {
            'totalXp': currentXp + xpGain,
            'coins': currentCoins + coinGain,
            'lastActive': now,
          },
          'updated_at': now,
        }).eq('lrn', resolvedLrn);
      } catch (_) {}
    }
  }

  /// Appends used question IDs to the student's question history.
  Future<void> recordUsedQuestions({
    required String userId,
    required String lrn,
    required int level,
    required List<String> questionIds,
  }) async {
    if (questionIds.isEmpty) return;
    final client = _client;
    final now = DateTime.now().toIso8601String();

    String resolvedLrn = lrn;
    if (resolvedLrn.isEmpty) {
      final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
      resolvedLrn = u?['lrn']?.toString() ?? '';
    }

    Map<String, dynamic>? currentSp;
    if (resolvedLrn.isNotEmpty) {
      currentSp = await client.from('student_progress').select('question_history').eq('lrn', resolvedLrn).maybeSingle();
    }
    currentSp ??= await client.from('student_progress').select('question_history').eq('uid', userId).maybeSingle();

    final currentHistory = (currentSp?['question_history'] as List?)?.cast<String>() ?? [];
    final updatedHistory = {...currentHistory, ...questionIds}.toList();

    if (resolvedLrn.isNotEmpty) {
      await client.from('student_progress').update({
        'question_history': updatedHistory,
        'updated_at': now,
      }).eq('lrn', resolvedLrn);
    } else {
      await client.from('student_progress').update({
        'question_history': updatedHistory,
        'updated_at': now,
      }).eq('uid', userId);
    }
  }

  // ── Diagnostic Assessment ──────────────────────────────────────────────────

  /// Persists RMA Diagnostic Assessment placement to `student_assessments`,
  /// `student_progress`, and `student_results`.
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
    final client = _client;
    final now = DateTime.now().toIso8601String();

    String resolvedLrn = lrn;
    if (resolvedLrn.isEmpty) {
      final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
      resolvedLrn = u?['lrn']?.toString() ?? '';
    }

    // 1. Update student_assessments
    final diagMap = {
      'score': score,
      'percentage': percentage,
      'assignedTier': category,
      'startingLevel': startingLevel,
      'contentPool': contentPool,
      'completed': true,
      'completedAt': now,
      'flags': diagnosticResult?.diagnosticFlags ?? [],
    };
    final saPayload = {
      'diagnostic_completed': true,
      'diagnostic_score': score,
      'diagnostic_percentage': percentage,
      'assigned_tier': category,
      'starting_level': startingLevel,
      'diagnostic_completed_at': now,
      'diagnostic': diagMap,
      'competency_scores': diagnosticResult?.competencyScores,
      'updated_at': now,
    };
    if (resolvedLrn.isNotEmpty) {
      await client.from('student_assessments').update(saPayload).eq('lrn', resolvedLrn);
    } else {
      await client.from('student_assessments').update(saPayload).eq('uid', userId);
    }

    // 2. Update student_progress
    Map<String, dynamic>? currentSp;
    if (resolvedLrn.isNotEmpty) {
      currentSp = await client.from('student_progress').select().eq('lrn', resolvedLrn).maybeSingle();
    }
    currentSp ??= await client.from('student_progress').select().eq('uid', userId).maybeSingle();

    final currentHistory = (currentSp?['question_history'] as List?)?.cast<String>() ?? [];
    final updatedHistory = {...currentHistory, ...usedQuestions}.toList();

    // Mark previous levels completed and startingLevel unlocked
    final currentLevelMap = Map<String, dynamic>.from(currentSp?['level_status_map'] as Map? ?? {});
    for (int i = 1; i < startingLevel; i++) {
      currentLevelMap[i.toString()] = 'completed';
    }
    currentLevelMap[startingLevel.toString()] = 'unlocked';

    final rawData = Map<String, dynamic>.from(currentSp?['raw_data'] as Map? ?? {});
    rawData['startingLevel'] = startingLevel;
    rawData['currentLevel'] = startingLevel;
    rawData['levelStatusMap'] = currentLevelMap;
    rawData['updatedAt'] = now;

    final spPayload = {
      'starting_level': startingLevel,
      'current_level': startingLevel,
      'level_status_map': currentLevelMap,
      'question_history': updatedHistory,
      'raw_data': rawData,
      'updated_at': now,
    };
    if (currentSp == null) {
      spPayload['uid'] = userId;
      if (resolvedLrn.isNotEmpty) spPayload['lrn'] = resolvedLrn;
      await client.from('student_progress').insert(spPayload);
    } else {
      if (resolvedLrn.isNotEmpty) {
        await client.from('student_progress').update(spPayload).eq('lrn', resolvedLrn);
      } else {
        await client.from('student_progress').update(spPayload).eq('uid', userId);
      }
    }

    // 3. Insert student_results record
    final mathPerf = diagnosticResult?.mathDomainPerformance;
    final cogPerf = diagnosticResult?.cognitiveDomainPerformance;
    final itemsList = diagnosticResult?.itemBreakdown.map((e) => e.toMap()).toList() ?? [];

    await client.from('student_results').insert({
      'student_uid': userId,
      if (resolvedLrn.isNotEmpty) 'lrn': resolvedLrn,
      'score': score,
      'max_score': 20,
      'percentage': percentage,
      'accuracy': score / 20.0,
      'assessment_type': 'DIAGNOSTIC',
      'starting_level': startingLevel,
      'mathalino_tier': category,
      'result_data': {
        'studentId': userId,
        'score': score,
        'maxScore': 20,
        'percentage': percentage,
        'assessmentType': 'DIAGNOSTIC',
        'assignedTier': category,
        'startingLevel': startingLevel,
        'contentPool': contentPool,
        'itemBreakdown': itemsList,
        'questionIds': usedQuestions,
        'competencyScores': diagnosticResult?.competencyScores ?? {},
        if (mathPerf != null && mathPerf.isNotEmpty) 'mathDomainPerformance': mathPerf,
        if (cogPerf != null && cogPerf.isNotEmpty) 'cognitiveDomainPerformance': cogPerf,
        'timestamp': now,
      },
      'created_at': now,
    });
  }

  // ── Remediation ────────────────────────────────────────────────────────────

  /// Persists remediation state and alerts to `student_progress` and `student_results`.
  Future<void> saveRemediationUpdate({
    required String userId,
    required String lrn,
    required Map<String, dynamic> remediationData,
    bool? needsTeacherSupport,
    String? status,
    int? remediationLevel,
    int? remediationFailedCount,
    String? zone,
    String? difficulty,
  }) async {
    final client = _client;
    final now = DateTime.now().toIso8601String();

    String resolvedLrn = lrn;
    if (resolvedLrn.isEmpty) {
      final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
      resolvedLrn = u?['lrn']?.toString() ?? '';
    }

    final spUpdate = <String, dynamic>{
      'remediation': remediationData,
      'remediation_active': remediationData['active'] == true,
      'remediation_level': ?remediationLevel,
      'remediation_failed_count': ?remediationFailedCount,
      'updated_at': now,
    };

    if (resolvedLrn.isNotEmpty) {
      await client.from('student_progress').update(spUpdate).eq('lrn', resolvedLrn);
    } else {
      await client.from('student_progress').update(spUpdate).eq('uid', userId);
    }

    if (needsTeacherSupport == true) {
      await client.from('student_results').insert({
        'student_uid': userId,
        if (resolvedLrn.isNotEmpty) 'lrn': resolvedLrn,
        'assessment_type': 'REMEDIATION_SUPPORT_NEEDED',
        'level_number': remediationLevel,
        'score': 0,
        'max_score': 1,
        'percentage': 0.0,
        'accuracy': 0.0,
        'result_data': {
          'studentId': userId,
          'title': 'Remediation Alert: Teacher Support Needed',
          'level': remediationLevel,
          'zone': zone,
          'difficulty': difficulty,
          'attemptNumber': remediationFailedCount ?? 1,
        },
        'created_at': now,
      });
    }
  }

  // ── Post Assessment ────────────────────────────────────────────────────────

  /// Finalizes zone milestone post-assessment, awards badges, and records results.
  Future<void> savePostAssessment({
    required String userId,
    required String lrn,
    required int milestoneLevel,
    required String zone,
    required int score,
    required int maxScore,
    required double percentage,
    required Map<String, dynamic> masteryOverview,
    required List<String> earnedBadges,
    required List<String> questionIds,
    required StudentResult studentResult,
  }) async {
    final client = _client;
    final now = DateTime.now().toIso8601String();

    String resolvedLrn = lrn;
    if (resolvedLrn.isEmpty) {
      final u = await client.from('users').select('lrn').eq('id', userId).maybeSingle();
      resolvedLrn = u?['lrn']?.toString() ?? '';
    }

    // 1. Update student_progress
    Map<String, dynamic>? currentSp;
    if (resolvedLrn.isNotEmpty) {
      currentSp = await client.from('student_progress').select().eq('lrn', resolvedLrn).maybeSingle();
    }
    currentSp ??= await client.from('student_progress').select().eq('uid', userId).maybeSingle();

    final currentZones = (currentSp?['completed_zones'] as List?)?.cast<String>() ?? [];
    if (!currentZones.contains(zone)) {
      currentZones.add(zone);
    }
    final currentHistory = (currentSp?['question_history'] as List?)?.cast<String>() ?? [];
    final updatedHistory = {...currentHistory, ...questionIds}.toList();

    final spUpdate = {
      'completed_zones': currentZones,
      'question_history': updatedHistory,
      'updated_at': now,
    };
    if (resolvedLrn.isNotEmpty) {
      await client.from('student_progress').update(spUpdate).eq('lrn', resolvedLrn);
    } else {
      await client.from('student_progress').update(spUpdate).eq('uid', userId);
    }

    // 2. Update student_assessments
    if (resolvedLrn.isNotEmpty) {
      try {
        final currentSa = await client.from('student_assessments').select().eq('lrn', resolvedLrn).maybeSingle();
        final milestones = Map<String, dynamic>.from(currentSa?['milestone_assessments'] as Map? ?? {});
        milestones[zone] = {
          'level': milestoneLevel,
          'score': score,
          'maxScore': maxScore,
          'percentage': percentage,
          'completedAt': now,
          'masteryOverview': masteryOverview,
        };
        await client.from('student_assessments').update({
          'milestone_assessments': milestones,
          'updated_at': now,
        }).eq('lrn', resolvedLrn);
      } catch (e) {
        debugPrint('[SupabaseService] milestone_assessments update warning: $e');
      }
    }

    // 3. Write earned badges to student_badges
    if (resolvedLrn.isNotEmpty) {
      for (final badgeId in earnedBadges) {
        try {
          await client.from('student_badges').insert({
            'student_lrn': resolvedLrn,
            'badge_id': badgeId,
            'badge_name': badgeId,
            'category': 'achievement',
            'earned_at': now,
          });
        } catch (e) {
          debugPrint('[SupabaseService] student_badges insert warning: $e');
        }
      }
    }

    // 4. Insert student_results
    await addStudentResult(studentResult);
  }

  // ── Student Results ────────────────────────────────────────────────────────

  /// Inserts a new result row into `student_results`.
  /// Returns the generated UUID of the new row.
  Future<String> addStudentResult(StudentResult result) async {
    try {
      final client = _client;
      final now = DateTime.now().toIso8601String();

      String resolvedLrn = result.lrn ?? '';
      final sUid = result.studentId.isNotEmpty ? result.studentId : (result.userId ?? '');

      if (resolvedLrn.isEmpty && sUid.isNotEmpty) {
        try {
          final u = await client.from('users').select('lrn').eq('id', sUid).maybeSingle();
          resolvedLrn = u?['lrn']?.toString() ?? '';
        } catch (_) {}
      }

      final data = await client
          .from('student_results')
          .insert({
            'student_uid': sUid,
            if (resolvedLrn.isNotEmpty) 'lrn': resolvedLrn,
            'score': result.score,
            'max_score': result.maxScore,
            'percentage': result.percentage,
            'accuracy': result.maxScore > 0 ? result.score / result.maxScore : 0.0,
            'assessment_type': result.assessmentType,
            if (result.levelNumber != null) 'level_number': result.levelNumber,
            if (result.startingLevel != null) 'starting_level': result.startingLevel,
            if (result.assignedTier != null) 'mathalino_tier': result.assignedTier,
            if (result.xpAwarded != null) 'xp_awarded': result.xpAwarded,
            if (result.coinsAwarded != null) 'coins_awarded': result.coinsAwarded,
            'result_data': result.toMap(),
            'created_at': now,
          })
          .select('id')
          .single();
      return data['id'].toString();
    } catch (e) {
      debugPrint('[SupabaseService] addStudentResult error: $e');
      rethrow;
    }
  }

  /// Fetches a single result from `student_results` by [resultId].
  Future<StudentResult?> fetchStudentResult(String resultId) async {
    try {
      final data = await _client
          .from('student_results')
          .select()
          .eq('id', resultId)
          .single();
      return StudentResult.fromMap(data, resultId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      debugPrint('[SupabaseService] fetchStudentResult error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseService] fetchStudentResult error: $e');
      rethrow;
    }
  }

  /// Fetches all results for a student, newest first.
  Future<List<StudentResult>> fetchResultsForStudent(String studentId) async {
    try {
      final rows = await _client
          .from('student_results')
          .select()
          .eq('student_uid', studentId)
          .order('created_at', ascending: false);
      return rows.map((row) => StudentResult.fromMap(row, row['id'].toString())).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchResultsForStudent error: $e');
      rethrow;
    }
  }

  // ── Questions ──────────────────────────────────────────────────────────────

  /// Fetches a single question from `questions` or `question_bank`.
  Future<Map<String, dynamic>?> fetchQuestion(String questionId) async {
    try {
      final data = await _client
          .from('questions')
          .select()
          .eq('id', questionId)
          .maybeSingle();
      if (data != null) return data;

      return await _client
          .from('question_bank')
          .select()
          .eq('question_id', questionId)
          .maybeSingle();
    } catch (e) {
      debugPrint('[SupabaseService] fetchQuestion error: $e');
      return null;
    }
  }

  // ── Badges ─────────────────────────────────────────────────────────────────

  /// Fetches the earned badge IDs for a student from `student_badges`.
  Future<List<String>> fetchEarnedBadgeIds(String userId, [String? studentLrn]) async {
    try {
      String lrn = studentLrn ?? '';
      if (lrn.isEmpty) {
        final u = await _client.from('users').select('lrn').eq('id', userId).maybeSingle();
        lrn = u?['lrn']?.toString() ?? '';
      }
      if (lrn.isEmpty) return [];

      final rows = await _client
          .from('student_badges')
          .select('badge_id')
          .eq('student_lrn', lrn);
      return rows.map((row) => row['badge_id'].toString()).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchEarnedBadgeIds error: $e');
      return [];
    }
  }

  // ── Daily Challenge ────────────────────────────────────────────────────────

  /// Fetches today's daily challenge document.
  Future<Map<String, dynamic>?> fetchDailyChallenge(String dateKey) async {
    try {
      final data = await _client
          .from('daily_challenges')
          .select()
          .eq('date', dateKey)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[SupabaseService] fetchDailyChallenge error: $e');
      return null;
    }
  }

  /// Checks if a student has already completed today's challenge.
  Future<bool> hasCompletedDailyChallenge(String userId, String dateKey) async {
    try {
      final rows = await _client
          .from('student_daily_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('date', dateKey);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[SupabaseService] hasCompletedDailyChallenge error: $e');
      return false;
    }
  }

  /// Records a completed daily challenge (anti-replay + stats update).
  Future<void> recordDailyChallenge({
    required String userId,
    required String dateKey,
    required Map<String, dynamic> progressData,
    required Map<String, dynamic> statsUpdate,
    required Map<String, dynamic> resultData,
  }) async {
    try {
      await _client.from('student_daily_progress').insert(progressData);
      await updateUserFields(userId, statsUpdate);
      await _client.from('student_results').insert(resultData);
    } catch (e) {
      debugPrint('[SupabaseService] recordDailyChallenge error: $e');
      rethrow;
    }
  }
}
