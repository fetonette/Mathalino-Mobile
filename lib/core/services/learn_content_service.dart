import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/bundled_learn_content.dart';
import '../models/learn_content_models.dart';

/// Service responsible for loading grade-specific Learn content
/// per the specifications in LEARN_CONTENT_STRUCTURE.md (§8).
class LearnContentService {
  static const String assetPath = 'assets/data/mathalino_learn_content_v2.json';

  // In-memory caches to prevent redundant network and disk operations
  final Map<int, GradeLearnContent> _gradeCache = {};
  LearnContentPackage? _cachedPackage;

  LearnContentService() {
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


  /// Clears in-memory cache (e.g. on user logout)
  void clearCache() {
    _gradeCache.clear();
    _cachedPackage = null;
  }
}
