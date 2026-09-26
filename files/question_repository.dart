/// lib/core/services/question_repository.dart
///
/// Loads question content from bundled JSON assets (offline-first) and
/// syncs from Firestore when a newer contentVersion is available. Exposes
/// the single selectQuestions() entry point the game engine and diagnostic
/// flow both use.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/question_model.dart';

class QuestionRepository {
  QuestionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // In-memory cache: grade -> question list. Swap for hive/sqflite for
  // persistence across app restarts if desired.
  final Map<int, List<QuestionModel>> _cache = {};

  /// Loads (and caches) the full question list for a single grade.
  Future<List<QuestionModel>> loadGrade(int grade) async {
    if (_cache.containsKey(grade)) return _cache[grade]!;

    List<QuestionModel> questions = await _loadFromAsset(grade);

    try {
      final remoteVersion = await _remoteContentVersion(grade);
      final localVersion = await _localContentVersion(grade);
      if (remoteVersion != null &&
          (localVersion == null || remoteVersion > localVersion)) {
        final remoteQuestions = await _loadFromFirestore(grade);
        if (remoteQuestions.isNotEmpty) {
          questions = remoteQuestions;
          await _saveLocalContentVersion(grade, remoteVersion);
        }
      }
    } catch (e) {
      // Network/Firestore failure -> silently keep the bundled asset copy.
      // ignore: avoid_print
      print('QuestionRepository: remote sync failed for grade $grade: $e');
    }

    _cache[grade] = questions;
    return questions;
  }

  Future<List<QuestionModel>> _loadFromAsset(int grade) async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/questions/grade$grade.json');
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('QuestionRepository: no bundled asset for grade $grade: $e');
      return [];
    }
  }

  Future<List<QuestionModel>> _loadFromFirestore(int grade) async {
    final snapshot = await _firestore
        .collectionGroup('items')
        .where('grade', isEqualTo: grade)
        .withConverter<QuestionModel>(
          fromFirestore: (snap, _) =>
              QuestionModel.fromJson(snap.data()!..['id'] = snap.id),
          toFirestore: (q, _) => q.toJson(),
        )
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<int?> _remoteContentVersion(int grade) async {
    final doc =
        await _firestore.collection('question_bank_meta').doc('$grade').get();
    if (!doc.exists) return null;
    return doc.data()?['contentVersion'] as int?;
  }

  // Simple placeholders for local version tracking; replace with
  // shared_preferences in the real app.
  final Map<int, int> _localVersions = {};
  Future<int?> _localContentVersion(int grade) async => _localVersions[grade];
  Future<void> _saveLocalContentVersion(int grade, int version) async {
    _localVersions[grade] = version;
  }

  /// Core content-selection method used by both the diagnostic and the
  /// 60-level game engine. Implements: grade-range filter -> competency
  /// filter -> difficulty filter -> exclude used questions -> playable-only
  /// -> shuffle -> take `count`.
  Future<List<QuestionModel>> selectQuestions({
    required int minGrade,
    required int maxGrade,
    List<String>? allowedCompetencies,
    DifficultyTier difficulty = DifficultyTier.normal,
    Set<String> excludeQuestionIds = const {},
    required int count,
    bool digitallyPlayableOnly = true,
  }) async {
    final pool = <QuestionModel>[];
    for (var g = minGrade; g <= maxGrade; g++) {
      pool.addAll(await loadGrade(g));
    }

    final filtered = pool.where((q) {
      if (digitallyPlayableOnly && !q.isDigitallyPlayable) return false;
      if (excludeQuestionIds.contains(q.id)) return false;
      if (q.difficulty != difficulty) return false;
      if (allowedCompetencies != null &&
          allowedCompetencies.isNotEmpty &&
          !allowedCompetencies.contains(q.competencyCode)) {
        return false;
      }
      return true;
    }).toList();

    filtered.shuffle(Random());
    return filtered.take(count).toList();
  }
}
