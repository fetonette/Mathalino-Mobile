
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
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      if (val is String && val.trim().isNotEmpty) {
        return [val.trim()];
      }
      return const [];
    }

    return LessonSequence(
      objectives: parseStringList(json['objectives']),
      introduction: json['introduction']?.toString() ?? '',
      explanation: parseStringList(json['explanation']),
      keyConcepts: parseStringList(json['keyConcepts']),
      workedExamples: (json['workedExamples'] as List<dynamic>? ?? [])
          .map((e) => WorkedExample.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList(),
      guidedPractice: (json['guidedPractice'] as List<dynamic>? ?? [])
          .map((e) => GuidedPracticeItem.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList(),
      independentPractice: parseStringList(json['independentPractice']),
      realLifeApplication: json['realLifeApplication']?.toString() ?? '',
      checkUnderstanding: parseStringList(json['checkUnderstanding']),
      summary: json['summary']?.toString() ?? '',
      challenge: parseStringList(json['challenge']),
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
      problem: json['problem']?.toString() ?? '',
      solution: json['solution']?.toString() ?? '',
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
      problem: json['problem']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem': problem,
      'hint': hint,
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE 7: DYNAMIC TEACHER-PUBLISHED CONTENT DTOs
// ═════════════════════════════════════════════════════════════════════════════

/// Represents a teacher-created mathematics module published to students.
class TeacherPublishedModule {
  final String id;
  final String teacherId;
  final String title;
  final String description;
  final String gradeLevel;
  final int displayOrder;
  final String status;
  final int publishedLessonCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeacherPublishedModule({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description = '',
    this.gradeLevel = '',
    this.displayOrder = 0,
    this.status = 'published',
    this.publishedLessonCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory TeacherPublishedModule.fromSupabase(
    Map<String, dynamic> json, {
    int publishedLessonCount = 0,
  }) {
    // If the join returned math_materials, calculate count automatically if not passed
    var calculatedCount = publishedLessonCount;
    if (json['math_materials'] is List) {
      final materialsList = json['math_materials'] as List<dynamic>;
      calculatedCount = materialsList.where((m) {
        if (m is! Map) return false;
        final rev = (m['review_status'] ?? '').toString().toLowerCase();
        final stat = (m['status'] ?? '').toString();
        return rev == 'published' && (stat == 'Active' || stat == 'published');
      }).length;
    }

    return TeacherPublishedModule(
      id: json['id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Module',
      description: json['description']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString() ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'published',
      publishedLessonCount: calculatedCount,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  /// Converts to legacy [LearnModule] for backward compatibility with existing widgets.
  LearnModule toLegacyLearnModule({List<LearnTopic> topics = const []}) {
    return LearnModule(
      id: id,
      name: title,
      description: description,
      note: gradeLevel.isNotEmpty ? gradeLevel : null,
      topics: topics,
    );
  }
}

/// Lightweight summary of a published lesson belonging to a module.
class PublishedLessonSummary {
  final String id;
  final String moduleId;
  final String teacherId;
  final String title;
  final String gradeLevel;
  final String status;
  final String reviewStatus;
  final DateTime? createdAt;

  const PublishedLessonSummary({
    required this.id,
    required this.moduleId,
    required this.teacherId,
    required this.title,
    this.gradeLevel = '',
    this.status = 'Active',
    this.reviewStatus = 'published',
    this.createdAt,
  });

  factory PublishedLessonSummary.fromSupabase(Map<String, dynamic> json) {
    return PublishedLessonSummary(
      id: json['id']?.toString() ?? '',
      moduleId: json['module_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Lesson',
      gradeLevel: json['grade_level']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      reviewStatus: json['review_status']?.toString() ?? 'published',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

/// Detailed published lesson with the full 11-part [LessonSequence].
/// Note: Practice questions with answers are NEVER included in this student model.
class PublishedLessonDetail {
  final String id;
  final String moduleId;
  final String teacherId;
  final String title;
  final String gradeLevel;
  final LessonSequence lessonSequence;
  final String status;
  final String reviewStatus;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  const PublishedLessonDetail({
    required this.id,
    required this.moduleId,
    required this.teacherId,
    required this.title,
    this.gradeLevel = '',
    required this.lessonSequence,
    this.status = 'Active',
    this.reviewStatus = 'published',
    this.createdAt,
    this.publishedAt,
  });

  factory PublishedLessonDetail.fromSupabase(Map<String, dynamic> json) {
    final lessonJson = json['lesson_data'] is Map<String, dynamic>
        ? json['lesson_data'] as Map<String, dynamic>
        : (json['lesson_data'] is Map
            ? Map<String, dynamic>.from(json['lesson_data'] as Map)
            : <String, dynamic>{});

    return PublishedLessonDetail(
      id: json['id']?.toString() ?? '',
      moduleId: json['module_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Lesson',
      gradeLevel: json['grade_level']?.toString() ?? '',
      lessonSequence: LessonSequence.fromJson(lessonJson),
      status: json['status']?.toString() ?? 'Active',
      reviewStatus: json['review_status']?.toString() ?? 'published',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
    );
  }

  /// Converts into a [LearnTopic] so existing LessonDetailScreen renders without rewriting.
  LearnTopic toLearnTopic({String moduleName = ''}) {
    return LearnTopic(
      id: id,
      gradeLevel: int.tryParse(gradeLevel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
      module: moduleName.isNotEmpty ? moduleName : 'Teacher Practice',
      title: title,
      rmaCompetencyCodes: const [],
      rmaSource: 'Teacher-Created Practice Lesson',
      moduleMappingNote: null,
      lessonSequence: lessonSequence,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PHASE 8: INTERACTIVE STUDENT PRACTICE MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a single student-safe multiple choice practice question.
///
/// Strictly omits `correctAnswer`, `explanation`, and teacher notes to prevent
/// any answer key leakage before or during interactive practice attempts.
class StudentPracticeQuestion {
  final String id;
  final String question;
  final Map<String, String> options;
  final String difficulty;
  final String? hint;
  final String lessonId;
  final String? lessonVersionId;

  const StudentPracticeQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.difficulty = 'standard',
    this.hint,
    required this.lessonId,
    this.lessonVersionId,
  });

  factory StudentPracticeQuestion.fromJson(Map<String, dynamic> json, {String? defaultLessonId}) {
    final rawOptions = json['options'];
    final Map<String, String> parsedOptions = {};

    if (rawOptions is Map) {
      rawOptions.forEach((k, v) {
        if (k != null && v != null) {
          parsedOptions[k.toString().trim().toUpperCase()] = v.toString().trim();
        }
      });
    }

    return StudentPracticeQuestion(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: parsedOptions,
      difficulty: json['difficulty']?.toString().toLowerCase() ?? 'standard',
      hint: json['hint']?.toString(),
      lessonId: json['lesson_id']?.toString() ?? defaultLessonId ?? '',
      lessonVersionId: json['lesson_version_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'difficulty': difficulty,
      if (hint != null) 'hint': hint,
      'lesson_id': lessonId,
      if (lessonVersionId != null) 'lesson_version_id': lessonVersionId,
    };
  }
}

/// Represents the evaluated response from the secure `check_practice_answer` server RPC.
class StudentPracticeAnswerResult {
  final bool isCorrect;
  final String feedback;
  final String? explanation;
  final String questionId;
  final String? correctOption;

  const StudentPracticeAnswerResult({
    required this.isCorrect,
    required this.feedback,
    this.explanation,
    required this.questionId,
    this.correctOption,
  });

  factory StudentPracticeAnswerResult.fromJson(Map<String, dynamic> json) {
    return StudentPracticeAnswerResult(
      isCorrect: json['is_correct'] == true,
      feedback: json['feedback']?.toString() ??
          (json['is_correct'] == true
              ? 'Great job! That is correct!'
              : 'Good try! Let’s work through it.'),
      explanation: json['explanation']?.toString(),
      questionId: json['question_id']?.toString() ?? '',
      correctOption: json['correct_option']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_correct': isCorrect,
      'feedback': feedback,
      if (explanation != null) 'explanation': explanation,
      'question_id': questionId,
      if (correctOption != null) 'correct_option': correctOption,
    };
  }
}

