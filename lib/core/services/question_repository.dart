/// lib/core/services/question_repository.dart
///
/// Loads the RMA-derived and Mathalino-adapted question bank from bundled
/// JSON assets (offline-first) and optionally syncs from Firestore when a
/// newer contentVersion is available. Exposes [selectLevelQuestions] used by
/// the 60-level game engine. Diagnostic questions are handled by
/// [DiagnosticQuestionService] (see `diagnostic_question_service.dart`).
///
/// The repository returns the existing [Question] model so the rest of the
/// app (ScoringService, DiagnosticProvider, etc.) does not need to change.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/question.dart';

class QuestionRepository {
  QuestionRepository();

  // In-memory cache: grade → list of Question objects.
  final Map<int, List<Question>> _cache = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Selects [count] questions for a game level.
  ///
  /// [minGrade]/[maxGrade] are derived from the zone.
  /// [competencyCodes] optionally narrows to specific competencies (remediation).
  /// [excludeQuestionIds] prevents repeating answered questions.
  Future<List<Question>> selectLevelQuestions({
    required int minGrade,
    required int maxGrade,
    List<String>? competencyCodes,
    Set<String> excludeQuestionIds = const {},
    int count = 5,
  }) async {
    return selectQuestions(
      minGrade: minGrade,
      maxGrade: maxGrade,
      allowedCompetencyCodes: competencyCodes,
      excludeQuestionIds: excludeQuestionIds,
      count: count,
    );
  }

  /// Core selection method with grade-range → competency → exclude-used →
  /// shuffle → take [count] logic.
  Future<List<Question>> selectQuestions({
    required int minGrade,
    required int maxGrade,
    List<String>? allowedCompetencyCodes,
    Set<String> excludeQuestionIds = const {},
    int count = 20,
  }) async {
    // Load all grades in parallel for instant response (< 50ms)
    final gradeFutures = <Future<List<Question>>>[];
    for (var g = minGrade; g <= maxGrade; g++) {
      gradeFutures.add(_loadGrade(g));
    }
    final gradeResults = await Future.wait(gradeFutures);

    final pool = <Question>[];
    for (final list in gradeResults) {
      pool.addAll(list);
    }

    final filtered = pool.where((q) {
      if (excludeQuestionIds.contains(q.id)) return false;
      if (allowedCompetencyCodes != null &&
          allowedCompetencyCodes.isNotEmpty &&
          !allowedCompetencyCodes.contains(q.competencyCode)) {
        return false;
      }
      return true;
    }).toList();

    filtered.shuffle(Random());

    // If we don't have enough unique questions, relax the exclude constraint.
    if (filtered.length < count) {
      final fallback =
          pool
              .where(
                (q) =>
                    allowedCompetencyCodes == null ||
                    allowedCompetencyCodes.isEmpty ||
                    allowedCompetencyCodes.contains(q.competencyCode),
              )
              .toList()
            ..shuffle(Random());
      return fallback.take(count).toList();
    }

    return filtered.take(count).toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Loads (and caches) the question list for [grade] from the bundled JSON
  /// asset instantly, and triggers an asynchronous background sync if needed.
  Future<List<Question>> _loadGrade(int grade) async {
    if (_cache.containsKey(grade)) return _cache[grade]!;

    final questions = await _loadFromAsset(grade);
    _cache[grade] = questions;

    // Trigger non-blocking remote sync in the background
    _syncRemoteInBackground(grade);

    return questions;
  }

  /// Non-blocking remote sync: checks Firestore in background without delaying UI
  void _syncRemoteInBackground(int grade) {
    Future.microtask(() async {
      try {
        final remoteVersion = await _remoteContentVersion(
          grade,
        ).timeout(const Duration(seconds: 3), onTimeout: () => null);
        final localVersion = _localVersions[grade];
        if (remoteVersion != null &&
            (localVersion == null || remoteVersion > localVersion)) {
          final remote = await _loadFromSupabase(
            grade,
          ).timeout(const Duration(seconds: 4), onTimeout: () => []);
          if (remote.isNotEmpty) {
            _cache[grade] = remote;
            _localVersions[grade] = remoteVersion;
          }
        }
      } catch (_) {
        // Silently ignore background sync failures
      }
    });
  }

  Future<List<Question>> _loadFromAsset(int grade) async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/questions/grade$grade.json',
      );
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _questionFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Question>> _loadFromSupabase(int grade) async {
    try {
      final rows = await Supabase.instance.client
          .from('questions')
          .select()
          .eq('grade', grade)
          .eq('is_digitally_playable', true)
          .timeout(const Duration(seconds: 4));
      return rows
          .map((row) => _questionFromJson({...row, 'id': row['id']?.toString() ?? ''}))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int?> _remoteContentVersion(int grade) async {
    try {
      final row = await Supabase.instance.client
          .from('question_bank_meta')
          .select('content_version')
          .eq('grade', grade)
          .maybeSingle();
      return row?['content_version'] as int?;
    } catch (_) {
      return null;
    }
  }

  final Map<int, int> _localVersions = {};

  // ── JSON → Question bridge ─────────────────────────────────────────────────

  /// Converts the QuestionModel-schema JSON to the app's [Question] model so
  /// the rest of the codebase (ScoringService, DiagnosticProvider, etc.)
  /// needs zero changes.
  Question _questionFromJson(Map<String, dynamic> json) {
    // Parse choices: either List<Map> (QuestionModel format) or List<String>
    List<String>? choices;
    final rawChoices = json['choices'];
    if (rawChoices is List && rawChoices.isNotEmpty) {
      if (rawChoices.first is Map) {
        // QuestionModel format: [{id: 'a', text: 'something'}, ...]
        choices = rawChoices
            .map((c) => '${(c as Map)['id']}. ${c['text']}')
            .toList();
      } else {
        choices = rawChoices.map((e) => e.toString()).toList();
      }
    }

    // acceptableAnswers (new schema) → correctAnswer (existing Question field)
    dynamic correctAnswer;
    final acceptable = json['acceptableAnswers'];
    if (acceptable is List && acceptable.isNotEmpty) {
      correctAnswer = acceptable.length == 1
          ? acceptable.first.toString()
          : acceptable;
    } else {
      correctAnswer = json['correctAnswer'] ?? '';
    }

    final resolvedChoices = (choices != null && choices.isNotEmpty)
        ? choices
        : ['A. 1', 'B. 2', 'C. 3', 'D. 4'];

    return Question(
      id: json['id']?.toString() ?? '',
      grade: (json['grade'] as num?)?.toInt() ?? 1,
      contentDomain:
          json['strand']?.toString() ??
          json['contentDomain']?.toString() ??
          'Number and Algebra',
      competencyCode: json['competencyCode']?.toString() ?? '',
      competencyText:
          json['competencyDescription']?.toString() ??
          json['competencyText']?.toString() ??
          '',
      cognitiveDomain:
          (json['tags'] is List && (json['tags'] as List).isNotEmpty)
          ? (json['tags'] as List).first.toString()
          : json['cognitiveDomain']?.toString() ?? 'knowing',
      type: 'multipleChoice',
      questionText:
          json['prompt']?.toString() ?? json['questionText']?.toString() ?? '',
      choices: resolvedChoices,
      correctAnswer: correctAnswer,
      maxPoints:
          (json['points'] as num?)?.toInt() ??
          (json['maxPoints'] as num?)?.toInt() ??
          1,
      scoringRubric:
          json['explanation']?.toString() ?? json['scoringRubric']?.toString(),
      groupId: json['groupId']?.toString(),
      sharedStimulusId: json['sharedStimulus']?.toString(),
    );
  }
}
