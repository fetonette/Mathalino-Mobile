/// lib/models/question_model.dart
///
/// Core content model for a single assessment/game question, covering both
/// the RMA-derived item bank (Grades 1-6) and any future Mathalino-authored
/// items. Schema-driven: adding a new grade/topic never requires new Dart
/// code, only new data following this shape.

import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionType {
  multipleChoice,
  trueFalse,
  numericInput,
  textInput,
  ordering,
  patternCompletion,
  wordProblem,
  trace, // e.g. "trace two parallel line segments" - not digitally gradable
  draw, // e.g. "draw a 140-degree angle"
  manipulative, // e.g. physical popsicle sticks / counters task
  oral, // spoken-response-only RMA task
}

enum DifficultyTier { normal, hard, superHardcore, finalBoss }

enum QuestionSource {
  rmaOfficial, // verbatim from an official RMA toolkit
  mathalinoAdapted, // adapted/authored for the 20-item in-app diagnostic or game
}

class AnswerChoice {
  final String id; // e.g. "a", "b", "c", "d"
  final String text; // display text, may be empty if imageAsset is used
  final String? imageAsset; // optional image-based choice

  const AnswerChoice({required this.id, required this.text, this.imageAsset});

  factory AnswerChoice.fromJson(Map<String, dynamic> json) => AnswerChoice(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        imageAsset: json['imageAsset'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (imageAsset != null) 'imageAsset': imageAsset,
      };
}

class QuestionModel {
  final String id; // e.g. "RMA_G1_A1a"
  final int grade; // 1-6
  final String strand; // e.g. "Number and Algebra"
  final String competencyCode; // e.g. "NAG1Q1-LC4"
  final String competencyDescription;
  final String taskLabel; // e.g. "Task A: Number and Algebra"
  final String? taskSourceRef; // traceability to source booklet/page
  final String prompt;
  final String? promptImageAsset;
  final QuestionType type;
  final List<AnswerChoice>? choices; // for multipleChoice / trueFalse
  final List<String> acceptableAnswers; // normalized correct answer(s)
  final int points;
  final DifficultyTier difficulty;
  final int? timeLimitSeconds; // optional, from RMA timed-task metadata
  final bool isDigitallyPlayable;
  final QuestionSource source;
  final String? explanation; // optional teacher-facing note / rationale
  final List<String> tags;

  const QuestionModel({
    required this.id,
    required this.grade,
    required this.strand,
    required this.competencyCode,
    required this.competencyDescription,
    required this.taskLabel,
    this.taskSourceRef,
    required this.prompt,
    this.promptImageAsset,
    required this.type,
    this.choices,
    required this.acceptableAnswers,
    this.points = 1,
    this.difficulty = DifficultyTier.normal,
    this.timeLimitSeconds,
    this.isDigitallyPlayable = true,
    this.source = QuestionSource.mathalinoAdapted,
    this.explanation,
    this.tags = const [],
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        grade: json['grade'] as int,
        strand: json['strand'] as String,
        competencyCode: json['competencyCode'] as String,
        competencyDescription: json['competencyDescription'] as String? ?? '',
        taskLabel: json['taskLabel'] as String? ?? '',
        taskSourceRef: json['taskSourceRef'] as String?,
        prompt: json['prompt'] as String,
        promptImageAsset: json['promptImageAsset'] as String?,
        type: QuestionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => QuestionType.textInput,
        ),
        choices: (json['choices'] as List<dynamic>?)
            ?.map((c) => AnswerChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
        acceptableAnswers: (json['acceptableAnswers'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        points: json['points'] as int? ?? 1,
        difficulty: DifficultyTier.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => DifficultyTier.normal,
        ),
        timeLimitSeconds: json['timeLimitSeconds'] as int?,
        isDigitallyPlayable: json['isDigitallyPlayable'] as bool? ?? true,
        source: QuestionSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => QuestionSource.mathalinoAdapted,
        ),
        explanation: json['explanation'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grade': grade,
        'strand': strand,
        'competencyCode': competencyCode,
        'competencyDescription': competencyDescription,
        'taskLabel': taskLabel,
        if (taskSourceRef != null) 'taskSourceRef': taskSourceRef,
        'prompt': prompt,
        if (promptImageAsset != null) 'promptImageAsset': promptImageAsset,
        'type': type.name,
        if (choices != null) 'choices': choices!.map((c) => c.toJson()).toList(),
        'acceptableAnswers': acceptableAnswers,
        'points': points,
        'difficulty': difficulty.name,
        if (timeLimitSeconds != null) 'timeLimitSeconds': timeLimitSeconds,
        'isDigitallyPlayable': isDigitallyPlayable,
        'source': source.name,
        if (explanation != null) 'explanation': explanation,
        'tags': tags,
      };

  /// Firestore typed converter, per the project's execution/safety rules.
  static const firestoreConverter =
      _QuestionModelFirestoreConverter();
}

class _QuestionModelFirestoreConverter
    implements FirestoreConverter<QuestionModel> {
  const _QuestionModelFirestoreConverter();

  @override
  QuestionModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) =>
      QuestionModel.fromJson(snapshot.data()!..putIfAbsent('id', () => snapshot.id));

  @override
  Map<String, dynamic> toFirestore(
    QuestionModel value,
    SetOptions? options,
  ) =>
      value.toJson();
}

/// Minimal alias so this file compiles standalone without importing the full
/// cloud_firestore FirestoreConverter typedef name in older SDKs.
typedef FirestoreConverter<T> = FirestoreDataConverter<T>;
