import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/question_model.dart';

/// Reads the validated Zone 1-3 question bank (Levels 1-60) from the
/// Supabase `question_bank` table (authoritative) with bundled JSON asset
/// fallback (local). The bank is cached in memory after the first request.
class QuestionBankService {
  QuestionBankService();

  /// In-memory cache of the full Zone 1-3 bank (300 docs, Levels 1-60).
  List<QuestionModel>? _cache;

  /// Bundled fallback question-bank assets.
  static const List<String> _assetPaths = [
    'assets/data/questions/question_bank_level1-20.json',
    'assets/data/questions/question_bank_level21-40.json',
    'assets/data/questions/question_bank_level41-60.json',
  ];

  /// Loads the question bank from the bundled local JSON assets.
  Future<List<QuestionModel>> _loadFromAsset() async {
    final bank = <QuestionModel>[];
    for (final assetPath in _assetPaths) {
      try {
        final jsonString = await rootBundle.loadString(assetPath);
        final List<dynamic> data = jsonDecode(jsonString) as List<dynamic>;
        bank.addAll(data.map((dynamic item) {
          final map = Map<String, dynamic>.from(item as Map);
          return QuestionModel.fromMap(
            map,
            map['question_id']?.toString() ?? '',
          );
        }));
      } catch (e) {
        debugPrint('[QuestionBankService] Asset load failed for $assetPath: $e');
      }
    }
    return bank;
  }

  /// Fetches the complete question bank (Levels 1-60), compositing from:
  /// 1. Supabase `question_bank` table (authoritative for any question_id it provides).
  /// 2. Bundled local asset (fills in every question_id Supabase doesn't provide).
  Future<List<QuestionModel>> fetchQuestionBank() async {
    if (_cache != null) return _cache!;

    // Attempt 1: Supabase (authoritative when populated).
    List<QuestionModel> remoteBank = const [];
    try {
      final rows = await Supabase.instance.client
          .from('question_bank')
          .select();
      remoteBank = rows.map((row) {
        final map = Map<String, dynamic>.from(row);
        return QuestionModel.fromMap(
          map,
          map['question_id']?.toString() ?? '',
        );
      }).toList(growable: false);
      debugPrint(
        '[QuestionBankService] Supabase returned ${remoteBank.length} questions.',
      );
    } catch (e) {
      debugPrint('[QuestionBankService] Supabase fetch failed: $e');
    }

    // Attempt 2: bundled local assets (fill any gaps).
    final assetBank = await _loadFromAsset();

    // Composite: local assets first, Supabase data overrides for same question_id.
    final byId = <String, QuestionModel>{
      for (final q in assetBank) q.questionId: q,
    };
    for (final q in remoteBank) {
      byId[q.questionId] = q;
    }

    final merged = byId.values.toList(growable: false);
    _cache = List<QuestionModel>.unmodifiable(merged);
    debugPrint(
      '[QuestionBankService] Cached ${merged.length} questions '
      '(Supabase: ${remoteBank.length}; filled from asset: '
      '${merged.length - remoteBank.length}).',
    );
    return _cache!;
  }

  /// Fetches the questions belonging to [level] (Levels 1-60, all three zones).
  Future<List<QuestionModel>> fetchQuestionsForLevel(int level) async {
    final bank = await fetchQuestionBank();
    return bank.where((q) => q.level == level).toList(growable: false);
  }
}
