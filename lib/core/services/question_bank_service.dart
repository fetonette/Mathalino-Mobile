import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/question_model.dart';

/// Reads the validated Zone 1â€“3 question bank (Levels 1â€“60) from the
/// Firestore `question_bank` collection.
///
/// The bank is a small, read-only dataset (300 documents) so it is fetched
/// once and cached in memory after the first request ([fetchQuestionBank]);
/// per-level lookups ([fetchQuestionsForLevel]) filter the cached copy and
/// never fan out extra network calls. Every read uses the typed
/// `withConverter` converter so callers work with [QuestionModel] objects.
class QuestionBankService {
  QuestionBankService({this._firestore});

  /// Explicit Firestore instance; null when relying on the lazy default.
  final FirebaseFirestore? _firestore;

  /// Lazily resolved Firestore instance (only accessed on first read).
  FirebaseFirestore? _resolvedFirestore;

  /// Resolves the Firestore instance on first use so that constructing a
  /// `QuestionBankService` (e.g. in unit tests) does **not** eagerly touch
  /// `FirebaseFirestore.instance`, which requires Firebase to be initialized.
  FirebaseFirestore get _db {
    _resolvedFirestore ??= _firestore ?? _defaultFirestore();
    return _resolvedFirestore!;
  }

  static FirebaseFirestore _defaultFirestore() {
    try {
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  /// In-memory cache of the full Zone 1â€“3 bank (300 docs, Levels 1â€“60).
  List<QuestionModel>? _cache;

  CollectionReference<QuestionModel> get _bankRef =>
      _db.collection('question_bank').withConverter<QuestionModel>(
            fromFirestore: (snapshot, _) => QuestionModel.fromFirestore(snapshot),
            toFirestore: (model, _) => model.toFirestore(),
          );

  /// Bundled fallback question-bank assets. These mirror
  /// `tools/question-bank/mathalino_questions_level1-20.json`,
  /// `mathalino_questions_level21-40.json`, and
  /// `mathalino_questions_level41-60.json`. They are used to complete the
  /// in-memory bank whenever Firestore is empty, unreachable, or has only been
  /// partially uploaded (see [fetchQuestionBank]).
  static const List<String> _assetPaths = [
    'assets/data/questions/question_bank_level1-20.json',
    'assets/data/questions/question_bank_level21-40.json',
    'assets/data/questions/question_bank_level41-60.json',
  ];

  /// Loads the question bank from the bundled local JSON assets.
  ///
  /// Used to fill gaps when Firestore returns zero documents, is unreachable,
  /// or has only been partially populated, so Zones 1â€“3 (Levels 1â€“60) are
  /// playable immediately without requiring the admin-side upload to have been
  /// executed in full first.
  Future<List<QuestionModel>> _loadFromAsset() async {
    final bank = <QuestionModel>[];
    for (final assetPath in _assetPaths) {
      final jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> data = jsonDecode(jsonString) as List<dynamic>;
      bank.addAll(data.map((dynamic item) {
        final map = Map<String, dynamic>.from(item as Map);
        return QuestionModel.fromMap(
          map,
          map['question_id']?.toString() ?? '',
        );
      }));
    }
    return bank;
  }

  /// Fetches the complete `question_bank` (Levels 1â€“60), guaranteeing that every
  /// zone â€” including Zone 3 (Levels 41â€“60) â€” is available. Cached in memory
  /// after the first successful read.
  ///
  /// The bank is always **composited** from two sources:
  ///
  /// 1. The Firestore `question_bank` collection (authoritative for any
  ///    `question_id` it provides).
  /// 2. The bundled local asset (fills in every `question_id` Firestore does
  ///    not already provide).
  ///
  /// Compositing â€” rather than "use Firestore if non-empty, else the asset" â€”
  /// means a **partially uploaded** collection (for example only Zones 1â€“2,
  /// Levels 1â€“40) no longer leaves Zone 3 (Levels 41â€“60) with empty per-level
  /// question pools that surface "No available question": the missing
  /// `question_id`s are filled from the bundled assets. Local data never
  /// overrides authoritative Firestore data for the same `question_id`. Throws
  /// only if **both** sources fail.
  Future<List<QuestionModel>> fetchQuestionBank() async {
    if (_cache != null) return _cache!;

    // Attempt 1: Firestore (authoritative when populated). Failures are
    // non-fatal â€” the composite still falls back to the bundled assets.
    List<QuestionModel> firestoreBank = const [];
    try {
      final snapshot = await _bankRef.get();
      firestoreBank = snapshot.docs
          .map((doc) => doc.data())
          .toList(growable: false);
      debugPrint(
        '[QuestionBankService] Firestore returned ${firestoreBank.length} questions.',
      );
    } catch (e) {
      debugPrint('[QuestionBankService] Firestore fetch failed: $e');
    }

    // Attempt 2: bundled local assets, used to fill any gaps left by a
    // partially-uploaded Firestore bank (or when it is empty/unreachable).
    final assetBank = await _loadFromAsset();

    // Composite: local assets seed every question_id first, then authoritative
    // Firestore data overrides them. This guarantees the full 1â€“60 bank.
    final byId = <String, QuestionModel>{
      for (final q in assetBank) q.questionId: q,
    };
    for (final q in firestoreBank) {
      byId[q.questionId] = q;
    }

    final merged = byId.values.toList(growable: false);
    _cache = List<QuestionModel>.unmodifiable(merged);
    debugPrint(
      '[QuestionBankService] Cached ${merged.length} questions '
      '(Firestore: ${firestoreBank.length}; filled from asset: '
      '${merged.length - firestoreBank.length}).',
    );
    return _cache!;
  }

  /// Fetches the questions belonging to [level] (Levels 1â€“60, all three zones).
  Future<List<QuestionModel>> fetchQuestionsForLevel(int level) async {
    final bank = await fetchQuestionBank();
    return bank.where((q) => q.level == level).toList(growable: false);
  }
}
