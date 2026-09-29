import 'dart:math';
import '../services/question_shuffle_service.dart';

/// Represents an individual choice option with its stable ID, display position,
/// text content, and correctness status.
class ChoiceOption {
  /// The immutable identifier from the original question bank (e.g. 'A', 'B', 'C', 'D').
  final String stableId;

  /// The visual display letter assigned in the UI (always 'A', 'B', 'C', 'D').
  final String displayLabel;

  /// The text content/value of the choice option (e.g. "18", "7", "Both are equal").
  final String text;

  /// Whether this choice is the correct answer according to the question's answer key.
  final bool isCorrect;

  const ChoiceOption({
    required this.stableId,
    required this.displayLabel,
    required this.text,
    required this.isCorrect,
  });

  @override
  String toString() =>
      'ChoiceOption(display: $displayLabel, stableId: $stableId, text: $text, isCorrect: $isCorrect)';
}

/// Question model mapping 1:1 to the Firestore `question_bank` collection
/// schema (Zones 1–3, Levels 1–60).
///
/// This is a **distinct** model from the legacy `Question` (which maps the
/// old `/questions` schema). It matches the validated
/// `tools/question-bank/mathalino_questions_level1-20.json`,
/// `mathalino_questions_level21-40.json`, and
/// `mathalino_questions_level41-60.json` exactly:
///
/// ```json
/// {
///   "question_id": "L1-Q1",
///   "level": 1,
///   "domain": "Number Identification",
///   "grade_tag": "Grade 1-3",
///   "difficulty": "Preparation",
///   "question_text": "...",
///   "choices": {"A": "...", "B": "...", "C": "...", "D": "..."},
///   "correct_answer": "B",
///   "challenge_group": 5,
///   "attempt_number": 0
/// }
/// ```
class QuestionModel {
  /// Unique id, e.g. `L5-Q3` (also the Firestore document id).
  final String questionId;

  /// Level number (1–60).
  final int level;

  /// Content domain / competency tag, e.g. "Addition" or "Hard Fractions".
  final String domain;

  /// Grade band tag, e.g. "Grade 1-3".
  final String gradeTag;

  /// 'Preparation' | 'Hard' | 'Super Hardcore' | 'Final Boss' | 'Moderate' | 'Moderate (Multi-Step)'.
  final String difficulty;

  final String questionText;

  /// Choice key → label map for display, e.g. {A: '18', B: '12', C: '20', D: '15'}.
  final Map<String, String> choices;

  /// The display key of the correct choice (e.g. "A").
  final String correctAnswer;

  /// The challenge-group bucket this question belongs to.
  final int? challengeGroup;

  /// Template value in the master bank; per-student usage lives on the
  /// student's profile, not the shared bank, so this is informational only.
  final int attemptNumber;

  /// The immutable original choices map from the question bank.
  final Map<String, String> originalChoices;

  /// The immutable original answer key from the question bank (e.g. "C").
  final String originalCorrectAnswer;

  /// Mapping from current display letter (e.g. 'A') to stable choice ID (e.g. 'C').
  final Map<String, String>? choiceKeyMapping;

  /// Rich representation of choices in display order with stable identities.
  final List<ChoiceOption>? storedChoiceOptions;

  const QuestionModel({
    required this.questionId,
    required this.level,
    required this.domain,
    required this.gradeTag,
    required this.difficulty,
    required this.questionText,
    required this.choices,
    required this.correctAnswer,
    this.challengeGroup,
    this.attemptNumber = 0,
    Map<String, String>? originalChoices,
    String? originalCorrectAnswer,
    this.choiceKeyMapping,
    List<ChoiceOption>? choiceOptions,
  })  : originalChoices = originalChoices ?? choices,
        originalCorrectAnswer = originalCorrectAnswer ?? correctAnswer,
        storedChoiceOptions = choiceOptions;

  /// The display letter of the correct choice in the current visual layout (e.g. "A").
  String get displayCorrectAnswer => correctAnswer;

  /// The text value of the correct choice (e.g. "18").
  String get correctAnswerValue {
    final orig = originalChoices[originalCorrectAnswer];
    if (orig != null && orig.isNotEmpty) return orig;
    return choices[correctAnswer] ?? '';
  }

  /// The rich list of choices in display order with stable identities.
  List<ChoiceOption> get choiceOptions {
    final opts = storedChoiceOptions;
    if (opts != null && opts.isNotEmpty) {
      return opts;
    }
    final entries = choices.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) {
      final stableId = choiceKeyMapping?[e.key] ?? e.key;
      final isCorr = stableId.trim().toLowerCase() ==
              originalCorrectAnswer.trim().toLowerCase() ||
          e.value.trim().toLowerCase() ==
              correctAnswerValue.trim().toLowerCase();
      return ChoiceOption(
        stableId: stableId,
        displayLabel: e.key,
        text: e.value,
        isCorrect: isCorr,
      );
    }).toList();
  }

  /// Returns a new [QuestionModel] whose choices have been randomized using the
  /// Fisher-Yates algorithm, while preserving the immutable original answer key
  /// and ensuring the correct answer remains accurately bound to its choice.
  ///
  /// Visual display letters `A, B, C, D` are assigned top-to-bottom.
  /// The original question model is never mutated.
  QuestionModel withShuffledChoices({Random? rng}) {
    if (choices.isEmpty) return this;

    final sourceChoices = originalChoices;
    final sourceCorrectAnswer = originalCorrectAnswer;
    final sourceCorrectValue = correctAnswerValue;

    // Use QuestionShuffleService to Fisher-Yates shuffle the original choice entries
    final originalEntries = sourceChoices.entries.toList();
    final shuffledEntries = QuestionShuffleService.fisherYatesShuffle(
      originalEntries,
      random: rng,
    );

    final newChoices = <String, String>{};
    final newMapping = <String, String>{};
    final newChoiceOptions = <ChoiceOption>[];
    String newDisplayCorrectAnswer = '';

    for (var i = 0; i < shuffledEntries.length; i++) {
      final displayLetter = String.fromCharCode(65 + i); // 'A', 'B', 'C', 'D'
      final entry = shuffledEntries[i];
      final stableId = entry.key;
      final text = entry.value;

      final isCorr = stableId.trim().toLowerCase() ==
              sourceCorrectAnswer.trim().toLowerCase() ||
          text.trim().toLowerCase() ==
              sourceCorrectValue.trim().toLowerCase();

      if (isCorr) {
        newDisplayCorrectAnswer = displayLetter;
      }

      newChoices[displayLetter] = text;
      newMapping[displayLetter] = stableId;
      newChoiceOptions.add(ChoiceOption(
        stableId: stableId,
        displayLabel: displayLetter,
        text: text,
        isCorrect: isCorr,
      ));
    }

    return QuestionModel(
      questionId: questionId,
      level: level,
      domain: domain,
      gradeTag: gradeTag,
      difficulty: difficulty,
      questionText: questionText,
      choices: newChoices,
      correctAnswer: newDisplayCorrectAnswer.isNotEmpty
          ? newDisplayCorrectAnswer
          : correctAnswer,
      challengeGroup: challengeGroup,
      attemptNumber: attemptNumber,
      originalChoices: sourceChoices,
      originalCorrectAnswer: sourceCorrectAnswer,
      choiceKeyMapping: newMapping,
      choiceOptions: newChoiceOptions,
    );
  }

  /// Parses a [QuestionModel] from a Firestore data [Map] (+ its doc id).
  factory QuestionModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawChoices = map['choices'];
    Map<String, String> choicesMap = const {};
    if (rawChoices is Map) {
      choicesMap = rawChoices.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    } else if (rawChoices is List) {
      // Defensive fallback for a list-shaped choices field.
      for (var i = 0; i < rawChoices.length; i++) {
        final letter = String.fromCharCode(65 + i);
        choicesMap = {
          ...choicesMap,
          letter: rawChoices[i].toString(),
        };
      }
    }

    final origAnswer = map['correct_answer']?.toString() ?? '';

    return QuestionModel(
      questionId: docId,
      level: (map['level'] ?? 1) as int,
      domain: map['domain']?.toString() ?? '',
      gradeTag: map['grade_tag']?.toString() ?? '',
      difficulty: map['difficulty']?.toString() ?? 'Preparation',
      questionText: map['question_text']?.toString() ?? '',
      choices: choicesMap,
      correctAnswer: origAnswer,
      challengeGroup: map['challenge_group'] as int?,
      attemptNumber: (map['attempt_number'] ?? 0) as int,
      originalChoices: choicesMap,
      originalCorrectAnswer: origAnswer,
    );
  }

  /// Alias kept for backward-compat call sites; use [fromMap] directly.
  static QuestionModel fromFirestoreData(Map<String, dynamic> data, String id) =>
      QuestionModel.fromMap(data, id);

  /// Serialises back to the Firestore schema (used by the seeded/bundled
  /// bank and for constructing test fixtures).
  ///
  /// Always persists the unmutated [originalChoices] and [originalCorrectAnswer]
  /// so that shuffling for display never modifies the authoritative question bank.
  Map<String, dynamic> toMap() {
    return {
      'question_id': questionId,
      'level': level,
      'domain': domain,
      'grade_tag': gradeTag,
      'difficulty': difficulty,
      'question_text': questionText,
      'choices': originalChoices,
      'correct_answer': originalCorrectAnswer,
      'challenge_group': challengeGroup,
      'attempt_number': attemptNumber,
    };
  }

  /// Alias for [toMap] kept for backward compat.
  Map<String, dynamic> toFirestore([dynamic options]) => toMap();

  /// Whether the given submitted answer (a choice key or value) is correct.
  ///
  /// Answers are evaluated against:
  /// 1. Current display key (e.g. 'A' if the correct option is in slot A).
  /// 2. Stable original choice key (e.g. 'C' if 'C' was the original answer key).
  /// 3. Choice text value (e.g. '18').
  ///
  /// Does NOT rely on raw letter A/B/C/D as the permanent answer identity,
  /// preventing false positives when choices are randomized.
  bool isCorrect(dynamic submittedAnswer) {
    if (submittedAnswer == null) return false;
    final s = submittedAnswer.toString().trim();
    if (s.isEmpty) return false;
    final norm = s.toLowerCase();

    // 1. If submitted answer is a display key (e.g. 'A', 'B', 'C', 'D')
    final upperKey = s.toUpperCase();
    if (choiceKeyMapping != null && choiceKeyMapping!.containsKey(upperKey)) {
      final stableId = choiceKeyMapping![upperKey];
      if (stableId != null) {
        return stableId.trim().toLowerCase() ==
            originalCorrectAnswer.trim().toLowerCase();
      }
    }

    // 2. Direct match against display correct answer (e.g. 'A')
    if (correctAnswer.trim().toLowerCase() == norm) return true;

    // 3. Direct match against stable original correct answer key (e.g. 'C')
    // when choiceKeyMapping is null (unshuffled)
    if (choiceKeyMapping == null &&
        originalCorrectAnswer.trim().toLowerCase() == norm) {
      return true;
    }

    // 4. Direct match against correct answer text value (e.g. '18')
    if (correctAnswerValue.trim().toLowerCase() == norm) return true;

    // 5. Direct match against choices[correctAnswer] if present
    final val = choices[correctAnswer];
    if (val != null && val.trim().toLowerCase() == norm) return true;

    return false;
  }

  @override
  String toString() => 'QuestionModel($questionId, L$level, difficulty: '
      '$difficulty, domain: $domain)';
}