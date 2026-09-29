
/// Top-level container representing the full Learn Content Package (schema 2.0).
class LearnContentPackage {
  final String appSection;
  final String schemaVersion;
  final String description;
  final List<String> lessonSequenceOrder;
  final List<String> sourceDocuments;
  final Map<String, String> moduleMappingNotes;
  final List<GradeLearnContent> grades;

  const LearnContentPackage({
    required this.appSection,
    required this.schemaVersion,
    required this.description,
    required this.lessonSequenceOrder,
    required this.sourceDocuments,
    required this.moduleMappingNotes,
    required this.grades,
  });

  factory LearnContentPackage.fromJson(Map<String, dynamic> json) {
    return LearnContentPackage(
      appSection: json['appSection'] as String? ?? 'Learn',
      schemaVersion: json['schemaVersion'] as String? ?? '2.0',
      description: json['description'] as String? ?? '',
      lessonSequenceOrder: (json['lessonSequenceOrder'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      sourceDocuments: (json['sourceDocuments'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      moduleMappingNotes: (json['moduleMappingNotes'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
      grades: (json['grades'] as List<dynamic>? ?? [])
          .map((g) => GradeLearnContent.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appSection': appSection,
      'schemaVersion': schemaVersion,
      'description': description,
      'lessonSequenceOrder': lessonSequenceOrder,
      'sourceDocuments': sourceDocuments,
      'moduleMappingNotes': moduleMappingNotes,
      'grades': grades.map((g) => g.toJson()).toList(),
    };
  }

  GradeLearnContent? getGrade(int gradeLevel) {
    try {
      return grades.firstWhere((g) => g.gradeLevel == gradeLevel);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a single grade's Learn content document (`/learn_content/{gradeId}`).
class GradeLearnContent {
  final String id;
  final int gradeLevel;
  final String status;
  final String? note;
  final List<LearnModule> modules;

  const GradeLearnContent({
    required this.id,
    required this.gradeLevel,
    required this.status,
    this.note,
    required this.modules,
  });

  bool get isSupported => status == 'supported_by_source';

  factory GradeLearnContent.fromJson(Map<String, dynamic> json) {
    return GradeLearnContent(
      id: json['id'] as String? ?? '',
      gradeLevel: (json['gradeLevel'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'supported_by_source',
      note: json['note'] as String?,
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((m) => LearnModule.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gradeLevel': gradeLevel,
      'status': status,
      if (note != null) 'note': note,
      'modules': modules.map((m) => m.toJson()).toList(),
    };
  }

  /// Finds a module matching the given suffix or key (e.g., 'number_sense', 'operations', 'fractions', 'geometry').
  LearnModule? getModule(String keyOrSuffix) {
    final normalized = keyOrSuffix.toLowerCase().replaceAll(' ', '_');
    try {
      return modules.firstWhere(
        (m) =>
            m.id.toLowerCase().endsWith(normalized) ||
            m.id.toLowerCase().contains(normalized) ||
            m.name.toLowerCase().replaceAll(' ', '_') == normalized,
      );
    } catch (_) {
      return null;
    }
  }

}

/// Represents one of the 4 curriculum modules (Number Sense, Operations, Fractions, Geometry).
class LearnModule {
  final String id;
  final String name;
  final String description;
  final String? note;
  final List<LearnTopic> topics;

  const LearnModule({
    required this.id,
    required this.name,
    required this.description,
    this.note,
    required this.topics,
  });

  bool get hasTopics => topics.isNotEmpty;

  factory LearnModule.fromJson(Map<String, dynamic> json) {
    return LearnModule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      note: json['note'] as String?,
      topics: (json['topics'] as List<dynamic>? ?? [])
          .map((t) => LearnTopic.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      if (note != null) 'note': note,
      'topics': topics.map((t) => t.toJson()).toList(),
    };
  }
}

/// Represents an individual topic / lesson mapped to RMA competency.
class LearnTopic {
  final String id;
  final int gradeLevel;
  final String module;
  final String title;
  final List<String> rmaCompetencyCodes;
  final String rmaSource;
  final String? moduleMappingNote;
  final LessonSequence lessonSequence;

  const LearnTopic({
    required this.id,
    required this.gradeLevel,
    required this.module,
    required this.title,
    required this.rmaCompetencyCodes,
    required this.rmaSource,
    this.moduleMappingNote,
    required this.lessonSequence,
  });

  factory LearnTopic.fromJson(Map<String, dynamic> json) {
    return LearnTopic(
      id: json['id'] as String? ?? '',
      gradeLevel: (json['gradeLevel'] as num?)?.toInt() ?? 1,
      module: json['module'] as String? ?? '',
      title: json['title'] as String? ?? '',
      rmaCompetencyCodes: (json['rmaCompetencyCodes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      rmaSource: json['rmaSource'] as String? ?? '',
      moduleMappingNote: json['moduleMappingNote'] as String?,
      lessonSequence: LessonSequence.fromJson(
        json['lessonSequence'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gradeLevel': gradeLevel,
      'module': module,
      'title': title,
      'rmaCompetencyCodes': rmaCompetencyCodes,
      'rmaSource': rmaSource,
      if (moduleMappingNote != null) 'moduleMappingNote': moduleMappingNote,
      'lessonSequence': lessonSequence.toJson(),
    };
  }
}

/// The formal 11-part instructional sequence.
class LessonSequence {
  final List<String> objectives;
  final String introduction;
  final List<String> explanation;
  final List<String> keyConcepts;
  final List<WorkedExample> workedExamples;
  final List<GuidedPracticeItem> guidedPractice;
  final List<String> independentPractice;
  final String realLifeApplication;
  final List<String> checkUnderstanding;
  final String summary;
  final List<String> challenge;

  const LessonSequence({
    required this.objectives,
    required this.introduction,
    required this.explanation,
    required this.keyConcepts,
    required this.workedExamples,
    required this.guidedPractice,
    required this.independentPractice,
    required this.realLifeApplication,
    required this.checkUnderstanding,
    required this.summary,
    required this.challenge,
  });

  factory LessonSequence.fromJson(Map<String, dynamic> json) {
    return LessonSequence(
      objectives: (json['objectives'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      introduction: json['introduction'] as String? ?? '',
      explanation: (json['explanation'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      keyConcepts: (json['keyConcepts'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      workedExamples: (json['workedExamples'] as List<dynamic>? ?? [])
          .map((e) => WorkedExample.fromJson(e as Map<String, dynamic>))
          .toList(),
      guidedPractice: (json['guidedPractice'] as List<dynamic>? ?? [])
          .map((e) => GuidedPracticeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      independentPractice:
          (json['independentPractice'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      realLifeApplication: json['realLifeApplication'] as String? ?? '',
      checkUnderstanding: (json['checkUnderstanding'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      summary: json['summary'] as String? ?? '',
      challenge: (json['challenge'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objectives': objectives,
      'introduction': introduction,
      'explanation': explanation,
      'keyConcepts': keyConcepts,
      'workedExamples': workedExamples.map((e) => e.toJson()).toList(),
      'guidedPractice': guidedPractice.map((e) => e.toJson()).toList(),
      'independentPractice': independentPractice,
      'realLifeApplication': realLifeApplication,
      'checkUnderstanding': checkUnderstanding,
      'summary': summary,
      'challenge': challenge,
    };
  }

  /// Dynamic accessor for the 11 section keys as specified in `lessonSequenceOrder`.
  dynamic operator [](String key) {
    switch (key) {
      case 'objectives':
        return objectives;
      case 'introduction':
        return introduction;
      case 'explanation':
        return explanation;
      case 'keyConcepts':
        return keyConcepts;
      case 'workedExamples':
        return workedExamples;
      case 'guidedPractice':
        return guidedPractice;
      case 'independentPractice':
        return independentPractice;
      case 'realLifeApplication':
        return realLifeApplication;
      case 'checkUnderstanding':
        return checkUnderstanding;
      case 'summary':
        return summary;
      case 'challenge':
        return challenge;
      default:
        return null;
    }
  }
}

/// A worked example with problem and step-by-step solution.
class WorkedExample {
  final String problem;
  final String solution;

  const WorkedExample({
    required this.problem,
    required this.solution,
  });

  factory WorkedExample.fromJson(Map<String, dynamic> json) {
    return WorkedExample(
      problem: json['problem'] as String? ?? '',
      solution: json['solution'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem': problem,
      'solution': solution,
    };
  }
}

/// A guided practice problem with a supportive hint.
class GuidedPracticeItem {
  final String problem;
  final String hint;

  const GuidedPracticeItem({
    required this.problem,
    required this.hint,
  });

  factory GuidedPracticeItem.fromJson(Map<String, dynamic> json) {
    return GuidedPracticeItem(
      problem: json['problem'] as String? ?? '',
      hint: json['hint'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem': problem,
      'hint': hint,
    };
  }
}
