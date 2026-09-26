import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/game_rules.dart';
import '../models/badge.dart';
import '../models/post_assessment_result.dart';
import '../models/question.dart';
import '../models/student_profile.dart';
import '../models/student_result_model.dart';
import 'question_selector_service.dart';
import 'scoring_service.dart';

/// Service for managing Post-Assessment administration, scoring evaluation,
/// domain mastery calculation, growth percentage tracking, and profile finalization.
class PostAssessmentService {
  final FirebaseFirestore _firestore;
  final ScoringService _scoringService;
  final QuestionSelectorService _questionSelector;

  PostAssessmentService({
    FirebaseFirestore? firestore,
    ScoringService? scoringService,
    QuestionSelectorService? questionSelector,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _scoringService = scoringService ?? ScoringService(),
        _questionSelector = questionSelector ?? QuestionSelectorService();

  /// Checks if a level is a major milestone boss level triggering post-assessment.
  static bool isMilestoneLevel(int level) {
    return level == 20 || level == 40 || level == 60;
  }

  /// Returns the zone identifier string for a given milestone level.
  static String? getZoneIdentifierForLevel(int level) {
    return ZoneMilestones.levelToZoneMap[level];
  }

  /// Loads 10-20 post-assessment questions targeting the completed zone.
  Future<List<Question>> loadPostAssessmentQuestions({
    required int zone,
    required List<String> contentPool,
    required List<String> usedQuestionsHistory,
    int limit = 15,
  }) async {
    try {
      final questions = await _questionSelector.selectQuestions(
        level: Level(difficulty: 'post_assessment', levelNumber: zone * 20),
        contentPool: contentPool,
        usedQuestionsHistory: usedQuestionsHistory,
        zone: zone,
        limit: limit,
      );

      // Fallback: If not enough questions from selector, query directly by zone
      if (questions.isEmpty) {
        final (startGrade, endGrade) = zone == 1
            ? (1, 3)
            : (zone == 2 ? (4, 6) : (7, 10));

        final snapshot = await _firestore
            .collection('questions')
            .where('grade', isGreaterThanOrEqualTo: startGrade)
            .where('grade', isLessThanOrEqualTo: endGrade)
            .limit(limit)
            .get();

        return snapshot.docs
            .map((doc) => Question.fromFirestore(doc))
            .toList();
      }

      return questions;
    } catch (e) {
      debugPrint('[PostAssessmentService] loadPostAssessmentQuestions error: $e');
      rethrow;
    }
  }

  /// Evaluates post-assessment answers, calculates domain-specific mastery,
  /// compares against pre-assessment baseline for growth, and resolves milestone badges.
  PostAssessmentResult evaluatePostAssessment({
    required int levelMilestone,
    required String zoneIdentifier,
    required List<Question> questions,
    required List<dynamic> studentAnswers,
    required double preAssessmentPercentage,
  }) {
    int totalEarnedPoints = 0;
    int maxPoints = 0;
    int correctCount = 0;

    // Track domain performance: Map<DomainName, (correct, total)>
    final Map<String, int> domainTotalMap = {};
    final Map<String, int> domainCorrectMap = {};

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = i < studentAnswers.length ? studentAnswers[i] : null;

      final points = _scoringService.scoreQuestion(question, answer);
      final isCorrect = points > 0;

      totalEarnedPoints += points;
      maxPoints += question.maxPoints;
      if (isCorrect) correctCount++;

      final domain = question.contentDomain.isNotEmpty
          ? question.contentDomain
          : 'General Numeracy';

      domainTotalMap[domain] = (domainTotalMap[domain] ?? 0) + 1;
      if (isCorrect) {
        domainCorrectMap[domain] = (domainCorrectMap[domain] ?? 0) + 1;
      }
    }

    final postPercentage =
        maxPoints > 0 ? (totalEarnedPoints / maxPoints) * 100.0 : 0.0;

    // Calculate domain-specific mastery breakdown
    final Map<String, DomainMasteryPerformance> domainPerformances = {};
    final Map<String, String> masteryOverview = {};

    for (final domain in domainTotalMap.keys) {
      final total = domainTotalMap[domain] ?? 1;
      final correct = domainCorrectMap[domain] ?? 0;
      final domainPct = (correct / total) * 100.0;

      final String status;
      if (domainPct >= 85.0) {
        status = 'MASTERED';
      } else if (domainPct >= 70.0) {
        status = 'PROFICIENT';
      } else if (domainPct >= 50.0) {
        status = 'DEVELOPING';
      } else {
        status = 'NEEDS_PRACTICE';
      }

      domainPerformances[domain] = DomainMasteryPerformance(
        domain: domain,
        correctCount: correct,
        totalCount: total,
        percentage: domainPct,
        status: status,
      );

      masteryOverview[domain] = status;
    }

    // Calculate Growth Percentage: post-assessment vs pre-assessment
    final growthPercentage = postPercentage - preAssessmentPercentage;

    // Resolve Milestone Achievement Badges
    final earnedBadges = <String>[];
    if (levelMilestone == 20) {
      earnedBadges.add(BadgeIds.zone1Master);
      earnedBadges.add(BadgeIds.bossSlayer);
    } else if (levelMilestone == 40) {
      earnedBadges.add(BadgeIds.zone2Master);
      earnedBadges.add(BadgeIds.bossSlayer);
    } else if (levelMilestone == 60) {
      earnedBadges.add(BadgeIds.mathWizard);
      earnedBadges.add(BadgeIds.bossSlayer);
    }

    return PostAssessmentResult(
      zoneIdentifier: zoneIdentifier,
      levelMilestone: levelMilestone,
      score: correctCount,
      maxScore: questions.length,
      percentage: postPercentage,
      preAssessmentPercentage: preAssessmentPercentage,
      growthPercentage: growthPercentage,
      domainPerformances: domainPerformances,
      masteryOverview: masteryOverview,
      earnedBadges: earnedBadges,
      completedAt: DateTime.now(),
    );
  }

  /// Finalizes the student profile in Firestore and persists full result document.
  Future<void> finalizeProfileAndPersistResult({
    required String studentId,
    required StudentProfile currentProfile,
    required PostAssessmentResult result,
    required List<Question> questions,
    required List<dynamic> answers,
  }) async {
    final userRef = _firestore.collection('users').doc(studentId);

    // 1. Build Question Results and Domain Rollups
    final questionResults = <QuestionResultItem>[];
    final competenciesMastered = <String>[];
    final competenciesToDevelop = <String>[];
    final mathDomainCounts = <String, Map<String, int>>{};
    final cogDomainCounts = <String, Map<String, int>>{};

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final ans = i < answers.length ? answers[i] : null;
      final points = _scoringService.scoreQuestion(q, ans);
      final isCorrect = points > 0;

      if (isCorrect) {
        competenciesMastered.add(q.competencyCode);
      } else {
        competenciesToDevelop.add(q.competencyCode);
      }

      questionResults.add(QuestionResultItem(
        itemNumber: i + 1,
        questionId: q.id,
        questionText: q.questionText,
        selectedAnswer: ans?.toString() ?? '',
        correctAnswer: q.correctAnswer.toString(),
        isCorrect: isCorrect,
        pointsEarned: points,
        maxPoints: q.maxPoints,
        contentDomain: q.contentDomain,
        cognitiveDomain: q.cognitiveDomain,
        competencyCode: q.competencyCode,
      ));

      if (q.contentDomain.isNotEmpty) {
        final c = mathDomainCounts.putIfAbsent(q.contentDomain, () => {'correct': 0, 'total': 0});
        c['total'] = c['total']! + 1;
        if (isCorrect) c['correct'] = c['correct']! + 1;
      }
      if (q.cognitiveDomain.isNotEmpty) {
        final c = cogDomainCounts.putIfAbsent(q.cognitiveDomain, () => {'correct': 0, 'total': 0});
        c['total'] = c['total']! + 1;
        if (isCorrect) c['correct'] = c['correct']! + 1;
      }
    }

    final mathDomainPerf = <String, Map<String, dynamic>>{};
    mathDomainCounts.forEach((k, v) {
      mathDomainPerf[k] = {
        'correct': v['correct'],
        'total': v['total'],
        'accuracyPct': v['total']! > 0 ? ((v['correct']! / v['total']!) * 100).round() : 0,
      };
    });

    final cogDomainPerf = <String, Map<String, dynamic>>{};
    cogDomainCounts.forEach((k, v) {
      cogDomainPerf[k] = {
        'correct': v['correct'],
        'total': v['total'],
        'accuracyPct': v['total']! > 0 ? ((v['correct']! / v['total']!) * 100).round() : 0,
      };
    });

    // 2. Perform Atomic Profile Update via Transaction
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw FirebaseException(
          plugin: 'post_assessment',
          message: 'Student document $studentId not found',
        );
      }

      // Merge updated domain mastery overview
      final existingMastery =
          (userSnap.data()?['masteryOverview'] as Map<String, dynamic>?) ?? {};
      final mergedMastery = {
        ...existingMastery,
        ...result.masteryOverview,
      };

      // Update /users/{studentId}
      transaction.update(userRef, {
        'completedZones': FieldValue.arrayUnion([result.zoneIdentifier]),
        'masteryOverview': mergedMastery,
        'usedQuestionsHistory':
            FieldValue.arrayUnion(questions.map((q) => q.id).toList()),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write earned badges
      for (final badgeId in result.earnedBadges) {
        final badgeRef = userRef.collection('earnedBadges').doc(badgeId);
        transaction.set(badgeRef, {
          'badgeId': badgeId,
          'earnedAt': FieldValue.serverTimestamp(),
          'zoneMilestone': result.zoneIdentifier,
        });
      }
    });

    // 3. Write summary result to /student_results
    final targetCompetencies = questions.map((q) => q.competencyCode).toSet().toList();

    await _firestore.collection('student_results').add(
          StudentResult(
            resultId: '',
            studentId: studentId,
            userId: studentId,
            assessmentType: AssessmentType.postAssessment,
            title: 'Post-Assessment (${result.zoneIdentifier})',
            score: result.score,
            maxScore: result.maxScore,
            percentage: result.percentage,
            completionStatus: 'completed',
            questionResults: questionResults,
            mathDomainPerformance: mathDomainPerf,
            cognitiveDomainPerformance: cogDomainPerf,
            targetCompetencies: targetCompetencies,
            competenciesMastered: competenciesMastered.toSet().toList(),
            competenciesToDevelop: competenciesToDevelop.toSet().toList(),
            growthPercentage: result.growthPercentage,
            metadata: {
              'zoneIdentifier': result.zoneIdentifier,
              'levelMilestone': result.levelMilestone,
              'preAssessmentPercentage': result.preAssessmentPercentage,
              'growthPercentage': result.growthPercentage,
              'masteryOverview': result.masteryOverview,
              'earnedBadges': result.earnedBadges,
              'studentName': currentProfile.displayName,
              'gradeLevel': currentProfile.gradeLevel,
            },
          ).toFirestore(),
        );

    debugPrint('[PostAssessmentService] Finalized post-assessment for student '
        '$studentId at milestone Level ${result.levelMilestone} (${result.zoneIdentifier}) '
        'with growth +${result.growthPercentage.toStringAsFixed(1)}%');
  }
}
