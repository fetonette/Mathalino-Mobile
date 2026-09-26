import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/models/learn_content_models.dart';
import 'package:mathalino_student_app/core/services/learn_content_service.dart';

void main() {
  group('LEARN_CONTENT_STRUCTURE.md Verification & Schema Tests', () {
    late String rawJson;
    late Map<String, dynamic> jsonMap;
    late LearnContentPackage package;

    setUpAll(() {
      final file = File('assets/data/mathalino_learn_content_v2.json');
      expect(file.existsSync(), isTrue,
          reason: 'mathalino_learn_content_v2.json must exist in assets/data/');
      rawJson = file.readAsStringSync();
      jsonMap = json.decode(rawJson) as Map<String, dynamic>;
      package = LearnContentPackage.fromJson(jsonMap);
    });

    test('1. Root structure matches schema 2.0 and metadata rules', () {
      expect(package.appSection, equals('Learn'));
      expect(package.schemaVersion, equals('2.0'));
      expect(package.sourceDocuments, isNotEmpty);
      expect(package.lessonSequenceOrder, equals(LearnContentService.defaultSequenceOrder));
      expect(package.moduleMappingNotes.containsKey('data_and_probability'), isTrue);
    });

    test('2. Grades 1 to 6 hierarchy and traceability rules', () {
      expect(package.grades.length, equals(6));

      // Expected counts per LEARN_CONTENT_STRUCTURE.md §3 Table
      // Grade 1: 2 NS, 2 OP, 1 FR, 3 GE = 8
      // Grade 2: 3 NS, 4 OP, 1 FR, 2 GE = 10
      // Grade 3: 2 NS, 5 OP, 2 FR, 4 GE = 13
      // Grade 4: 0 NS, 3 OP, 2 FR, 5 GE = 10
      // Grade 5: 1 NS, 5 OP, 3 FR, 2 GE = 11
      // Grade 6: 0 NS, 0 OP, 0 FR, 0 GE = 0
      final expectedTopicCounts = {1: 8, 2: 10, 3: 13, 4: 10, 5: 11, 6: 0};

      int totalLessons = 0;

      for (final grade in package.grades) {
        expect(grade.id, equals('grade_${grade.gradeLevel}'));
        expect(grade.modules.length, equals(4));

        final totalTopicsInGrade =
            grade.modules.fold<int>(0, (sum, m) => sum + m.topics.length);
        expect(totalTopicsInGrade, equals(expectedTopicCounts[grade.gradeLevel]),
            reason: 'Topic count mismatch for Grade ${grade.gradeLevel}');

        totalLessons += totalTopicsInGrade;

        if (grade.gradeLevel <= 5) {
          expect(grade.status, equals('supported_by_source'));
          expect(grade.isSupported, isTrue);
        } else {
          // §4 Grade 6 intentionally empty
          expect(grade.status, equals('NOT_SUPPORTED_BY_SOURCE'));
          expect(grade.isSupported, isFalse);
          expect(grade.note, isNotNull);
          expect(grade.note!.isNotEmpty, isTrue);
        }
      }

      // Exactly 52 lessons total as stated in §3
      expect(totalLessons, equals(52));
    });

    test('3. Grade 4 Number Sense gap is documented and empty per §5', () {
      final g4 = package.getGrade(4);
      expect(g4, isNotNull);
      final nsModule = g4!.getModule('number_sense');
      expect(nsModule, isNotNull);
      expect(nsModule!.topics, isEmpty);
      expect(nsModule.note, isNotNull);
      expect(nsModule.note!.toLowerCase().contains('no rma item'), isTrue);
    });

    test('4. Data & Probability lessons carry moduleMappingNote per §6', () {
      final flaggedLessonIds = ['g3_op_05', 'g4_op_03', 'g5_op_04', 'g5_op_05'];

      for (final id in flaggedLessonIds) {
        bool found = false;
        for (final grade in package.grades) {
          for (final mod in grade.modules) {
            for (final t in mod.topics) {
              if (t.id == id) {
                found = true;
                expect(t.moduleMappingNote, isNotNull,
                    reason: 'Lesson $id must contain moduleMappingNote');
                expect(t.moduleMappingNote!.isNotEmpty, isTrue);
                expect(t.module, equals('operations'));
              }
            }
          }
        }
        expect(found, isTrue, reason: 'Flagged lesson $id not found');
      }
    });

    test('5. Every lesson strictly implements the 11-part lessonSequence (§2)', () {
      int checkedCount = 0;

      for (final grade in package.grades) {
        for (final mod in grade.modules) {
          for (final topic in mod.topics) {
            checkedCount++;
            final seq = topic.lessonSequence;

            // 1. Objectives (List<String>)
            expect(seq.objectives, isNotEmpty,
                reason: '${topic.id} missing objectives');
            // 2. Introduction (String)
            expect(seq.introduction.trim(), isNotEmpty,
                reason: '${topic.id} missing introduction');
            // 3. Explanation (List<String>)
            expect(seq.explanation, isNotEmpty,
                reason: '${topic.id} missing explanation');
            // 4. Key Concepts (List<String>)
            expect(seq.keyConcepts, isNotEmpty,
                reason: '${topic.id} missing keyConcepts');
            // 5. Worked Examples (List<WorkedExample>)
            expect(seq.workedExamples, isNotEmpty,
                reason: '${topic.id} missing workedExamples');
            for (final we in seq.workedExamples) {
              expect(we.problem.trim(), isNotEmpty);
              expect(we.solution.trim(), isNotEmpty);
            }
            // 6. Guided Practice (List<GuidedPracticeItem>)
            expect(seq.guidedPractice, isNotEmpty,
                reason: '${topic.id} missing guidedPractice');
            for (final gp in seq.guidedPractice) {
              expect(gp.problem.trim(), isNotEmpty);
              expect(gp.hint.trim(), isNotEmpty);
            }
            // 7. Independent Practice (List<String>)
            expect(seq.independentPractice, isNotEmpty,
                reason: '${topic.id} missing independentPractice');
            // 8. Real-Life Application (String)
            expect(seq.realLifeApplication.trim(), isNotEmpty,
                reason: '${topic.id} missing realLifeApplication');
            // 9. Check Understanding (List<String>)
            expect(seq.checkUnderstanding, isNotEmpty,
                reason: '${topic.id} missing checkUnderstanding');
            // 10. Summary (String)
            expect(seq.summary.trim(), isNotEmpty,
                reason: '${topic.id} missing summary');
            // 11. Challenge (List<String>)
            expect(seq.challenge, isNotEmpty,
                reason: '${topic.id} missing challenge');

            // Dynamic accessor seq[key] verification
            for (final key in LearnContentService.defaultSequenceOrder) {
              expect(seq[key], isNotNull,
                  reason: 'Dynamic accessor seq["$key"] failed on ${topic.id}');
            }

            // Traceability fields
            expect(topic.rmaCompetencyCodes, isNotEmpty);
            expect(topic.rmaSource.trim(), isNotEmpty);
            expect(topic.gradeLevel, equals(grade.gradeLevel));
          }
        }
      }

      expect(checkedCount, equals(52));
    });

    test('6. Model serialization and deserialization roundtrips without data loss', () {
      final sampleGrade = package.grades.first;
      final serialized = sampleGrade.toJson();
      final roundtrip = GradeLearnContent.fromJson(serialized);

      expect(roundtrip.id, equals(sampleGrade.id));
      expect(roundtrip.gradeLevel, equals(sampleGrade.gradeLevel));
      expect(roundtrip.status, equals(sampleGrade.status));
      expect(roundtrip.modules.length, equals(sampleGrade.modules.length));

      final firstTopic = sampleGrade.modules.first.topics.first;
      final topicSerialized = firstTopic.toJson();
      final topicRoundtrip = LearnTopic.fromJson(topicSerialized);

      expect(topicRoundtrip.id, equals(firstTopic.id));
      expect(topicRoundtrip.title, equals(firstTopic.title));
      expect(topicRoundtrip.rmaCompetencyCodes, equals(firstTopic.rmaCompetencyCodes));
      expect(topicRoundtrip.lessonSequence.objectives,
          equals(firstTopic.lessonSequence.objectives));
      expect(topicRoundtrip.lessonSequence.workedExamples.first.problem,
          equals(firstTopic.lessonSequence.workedExamples.first.problem));
    });
  });
}
