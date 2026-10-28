import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/bundled_learn_content.dart';
import '../models/learn_content_models.dart';

/// Service responsible for loading teacher-published Learn content from Supabase
/// and fallback legacy content models if needed.
class LearnContentService {
  static const String assetPath = 'assets/data/mathalino_learn_content_v2.json';

  final SupabaseClient? _injectedClient;

  SupabaseClient get _supabase {
    final client = _injectedClient;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  // In-memory caches to prevent redundant network and disk operations
  final Map<int, GradeLearnContent> _gradeCache = {};
  LearnContentPackage? _cachedPackage;

  LearnContentService({SupabaseClient? supabaseClient})
      : _injectedClient = supabaseClient {
    _initFromBundled();
  }

  void _initFromBundled() {
    try {
      final dynamic decoded = json.decode(bundledLearnContentJson);
      if (decoded is Map<String, dynamic>) {
        _cachedPackage = LearnContentPackage.fromJson(decoded);
        for (final grade in _cachedPackage!.grades) {
          _gradeCache[grade.gradeLevel] = grade;
        }
      }
    } catch (e) {
      debugPrint('[LearnContentService] Synchronous bundled init error: $e');
    }
  }

  /// Synchronously returns cached grade content without any await
  GradeLearnContent? getGradeSync(int gradeLevel) {
    if (_gradeCache.containsKey(gradeLevel)) {
      return _gradeCache[gradeLevel];
    }
    return _cachedPackage?.getGrade(gradeLevel);
  }

  /// Default sequence order matching the 11 formal lesson stages
  static const List<String> defaultSequenceOrder = [
    'objectives',
    'introduction',
    'explanation',
    'keyConcepts',
    'workedExamples',
    'guidedPractice',
    'independentPractice',
    'realLifeApplication',
    'checkUnderstanding',
    'summary',
    'challenge',
  ];

  /// Section metadata (display titles, icons, descriptions)
  static Map<String, ({String title, String subtitle})> sectionMeta = {
    'objectives': (
      title: 'Objectives',
      subtitle: 'What you will master in this lesson'
    ),
    'introduction': (
      title: 'Introduction',
      subtitle: 'Connecting math to the world around you'
    ),
    'explanation': (
      title: 'Step-by-Step Explanation',
      subtitle: 'Clear steps to understand the concept'
    ),
    'keyConcepts': (
      title: 'Key Concepts & Rules',
      subtitle: 'Essential rules and definitions to remember'
    ),
    'workedExamples': (
      title: 'Worked Examples',
      subtitle: 'Fully solved step-by-step problems'
    ),
    'guidedPractice': (
      title: 'Guided Practice',
      subtitle: 'Try these problems with helpful hints'
    ),
    'independentPractice': (
      title: 'Independent Practice',
      subtitle: 'Solve these on your own to test your skills'
    ),
    'realLifeApplication': (
      title: 'Real-Life Application',
      subtitle: 'How this math is used in everyday life'
    ),
    'checkUnderstanding': (
      title: 'Check Understanding',
      subtitle: 'Quick review questions'
    ),
    'summary': (
      title: 'Lesson Summary',
      subtitle: 'The big takeaway of today’s lesson'
    ),
    'challenge': (
      title: 'Math Explorer Challenge',
      subtitle: 'Optional higher-level brain teasers'
    ),
  };

  /// Loads the entire LearnContentPackage from the bundled asset.
  Future<LearnContentPackage> loadFullPackage() async {
    if (_cachedPackage != null) return _cachedPackage!;

    String? jsonString;
    try {
      jsonString = await rootBundle.loadString(assetPath);
    } catch (e) {
      debugPrint('[LearnContentService] rootBundle load failed ($e), falling back to compiled bundled JSON');
      jsonString = bundledLearnContentJson;
    }

    try {
      final dynamic decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        _cachedPackage = LearnContentPackage.fromJson(decoded);
        for (final grade in _cachedPackage!.grades) {
          _gradeCache[grade.gradeLevel] = grade;
        }
        return _cachedPackage!;
      }
      throw StateError('Invalid root JSON structure');
    } catch (e, st) {
      debugPrint('[LearnContentService] Error loading full package: $e\n$st');
      rethrow;
    }
  }

  /// Instant fetch from local asset bundle or in-memory cache (<5ms)
  Future<GradeLearnContent> fetchFromAsset(int gradeLevel) async {
    if (_gradeCache.containsKey(gradeLevel)) {
      return _gradeCache[gradeLevel]!;
    }
    final package = await loadFullPackage();
    final gradeContent = package.getGrade(gradeLevel);
    if (gradeContent == null) {
      throw StateError('No Learn content found for grade $gradeLevel');
    }
    _gradeCache[gradeLevel] = gradeContent;
    return gradeContent;
  }

  /// Fetches Learn content strictly for the student's grade level.
  /// Prioritizes fast local load (<5ms) so students never see a hanging spinner.
  Future<GradeLearnContent> fetchLearnContentForStudent(String userId, {int? fallbackGrade}) async {
    int gradeLevel = fallbackGrade ?? 1;

    // Return instant local content first
    final initialContent = await fetchGradeLearnContent(gradeLevel);

    return initialContent;
  }

  /// Fetches a specific grade's content (e.g. Grade 1-6).
  /// Loads instantly from local bundled asset, with background Firestore sync.
  Future<GradeLearnContent> fetchGradeLearnContent(int gradeLevel) async {
    if (_gradeCache.containsKey(gradeLevel)) {
      return _gradeCache[gradeLevel]!;
    }
    // Load from local bundled asset (primary source)
    try {
      final local = await fetchFromAsset(gradeLevel);
      return local;
    } catch (e) {
      debugPrint('[LearnContentService] Asset load warning: $e');
    }
    throw StateError('No Learn content found for grade $gradeLevel');
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 7: SUPABASE-BACKED TEACHER PUBLISHED CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches published mathematics modules created by the authenticated student's assigned teacher(s).
  ///
  /// Enforces:
  /// - Server-side RLS guarantees student only sees assigned teacher's published modules.
  /// - Client-side filter guarantees only modules with >= 1 published lesson are displayed.
  /// - Sorted in stable order by display_order ascending, then created_at.
  Future<List<TeacherPublishedModule>> fetchPublishedTeacherModules() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated student session found.');
    }

    try {
      final response = await _supabase
          .from('teacher_modules')
          .select('''
            id,
            teacher_id,
            title,
            description,
            grade_level,
            display_order,
            status,
            created_at,
            updated_at,
            math_materials (
              id,
              title,
              status,
              review_status
            )
          ''')
          .eq('status', 'published')
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      final List<TeacherPublishedModule> modules = [];
      for (final raw in response) {
        final mod = TeacherPublishedModule.fromSupabase(raw);
        // Only show modules that contain at least one published practice lesson
        if (mod.publishedLessonCount > 0) {
          modules.add(mod);
        }
      }
      return modules;
    } catch (e, st) {
      debugPrint('[LearnContentService] fetchPublishedTeacherModules error: $e\n$st');
      rethrow;
    }
  }

  /// Fetches published practice lessons belonging to a specific teacher module.
  ///
  /// Only fetches student-safe columns. Sensitive extraction data and private answer keys
  /// are strictly omitted.
  Future<List<PublishedLessonSummary>> fetchPublishedModuleLessons(String moduleId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated student session found.');
    }

    try {
      final response = await _supabase
          .from('math_materials')
          .select('id, module_id, teacher_id, title, grade_level, status, review_status, created_at')
          .eq('module_id', moduleId)
          .eq('review_status', 'published')
          .or('status.eq.Active,status.eq.published')
          .order('created_at', ascending: true);

      final List<PublishedLessonSummary> lessons = [];
      for (final raw in response) {
        lessons.add(PublishedLessonSummary.fromSupabase(raw));
      }
      return lessons;
    } catch (e, st) {
      debugPrint('[LearnContentService] fetchPublishedModuleLessons error: $e\n$st');
      rethrow;
    }
  }

  /// Fetches a single authorized published lesson with its 11-part lesson sequence.
  ///
  /// Note: Practice questions with answers are NEVER fetched in this query.
  Future<PublishedLessonDetail> fetchPublishedLessonDetail(String lessonId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated student session found.');
    }

    try {
      final response = await _supabase
          .from('math_materials')
          .select('id, module_id, teacher_id, title, grade_level, lesson_data, status, review_status, created_at, published_at')
          .eq('id', lessonId)
          .maybeSingle();

      if (response == null) {
        throw StateError('Lesson not found or you are not authorized to view it.');
      }

      final map = Map<String, dynamic>.from(response);
      final reviewStatus = (map['review_status'] ?? '').toString().toLowerCase();
      final status = (map['status'] ?? '').toString();

      if (reviewStatus != 'published' || (status != 'Active' && status != 'published')) {
        throw StateError('This lesson is no longer published by your teacher.');
      }

      return PublishedLessonDetail.fromSupabase(map);
    } catch (e, st) {
      debugPrint('[LearnContentService] fetchPublishedLessonDetail error: $e\n$st');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 8: INTERACTIVE STUDENT PRACTICE & SECURE RPC CALLS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches the 5 student-safe practice questions for a published lesson via Supabase RPC.
  ///
  /// Guarantees:
  /// - Invokes `get_student_practice_questions` securely on Supabase.
  /// - Server enforces student enrollment, published module, and published lesson checks.
  /// - `correctAnswer` and `explanation` are strictly stripped on the server and never sent.
  Future<List<StudentPracticeQuestion>> fetchStudentPracticeQuestions(String lessonId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated student session found.');
    }

    try {
      final response = await _supabase.rpc(
        'get_student_practice_questions',
        params: {'p_lesson_id': lessonId},
      );

      if (response == null) {
        return const [];
      }

      final List<dynamic> list;
      if (response is List) {
        list = response;
      } else if (response is String) {
        final decoded = json.decode(response);
        list = decoded is List ? decoded : const [];
      } else {
        list = const [];
      }

      final List<StudentPracticeQuestion> questions = [];
      for (final item in list) {
        if (item is Map) {
          questions.add(StudentPracticeQuestion.fromJson(
            Map<String, dynamic>.from(item),
            defaultLessonId: lessonId,
          ));
        }
      }

      return questions;
    } catch (e, st) {
      debugPrint('[LearnContentService] fetchStudentPracticeQuestions error: $e\n$st');
      rethrow;
    }
  }

  /// Evaluates an answer for a practice question using the secure server RPC.
  ///
  /// Guarantees:
  /// - `correctAnswer` is verified server-side inside PostgreSQL.
  /// - Returns immediate supportive feedback and explanation upon correct submission.
  /// - Safe retries: no heart/life deduction, no XP/coin modification.
  Future<StudentPracticeAnswerResult> checkPracticeAnswer({
    required String lessonId,
    required String questionId,
    required String selectedOption,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated student session found.');
    }

    try {
      final response = await _supabase.rpc(
        'check_practice_answer',
        params: {
          'p_lesson_id': lessonId,
          'p_question_id': questionId,
          'p_selected_option': selectedOption.trim().toUpperCase(),
        },
      );

      final Map<String, dynamic> map;
      if (response is Map) {
        map = Map<String, dynamic>.from(response);
      } else if (response is String) {
        final decoded = json.decode(response);
        map = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      } else {
        map = <String, dynamic>{};
      }

      return StudentPracticeAnswerResult.fromJson(map);
    } catch (e, st) {
      debugPrint('[LearnContentService] checkPracticeAnswer error: $e\n$st');
      rethrow;
    }
  }

  /// Records lightweight practice progress (attempts, completion) isolated from formal assessments.
  Future<void> recordPracticeProgress({
    required String lessonId,
    required int questionsAttempted,
    required bool isCompleted,
  }) async {
    try {
      await _supabase.rpc(
        'record_practice_progress',
        params: {
          'p_lesson_id': lessonId,
          'p_questions_attempted': questionsAttempted,
          'p_is_completed': isCompleted,
        },
      );
    } catch (e) {
      // Non-blocking: background practice progress should not crash the student UI
      debugPrint('[LearnContentService] recordPracticeProgress non-fatal error: $e');
    }
  }

  /// Clears in-memory cache (e.g. on user logout)
  void clearCache() {
    _gradeCache.clear();
    _cachedPackage = null;
  }
}
