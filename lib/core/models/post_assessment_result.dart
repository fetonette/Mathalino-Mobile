/// Performance details for a specific content domain within the Post-Assessment.
class DomainMasteryPerformance {
  final String domain;
  final int correctCount;
  final int totalCount;
  final double percentage;
  final String status; // 'MASTERED' | 'PROFICIENT' | 'DEVELOPING' | 'NEEDS_PRACTICE'

  const DomainMasteryPerformance({
    required this.domain,
    required this.correctCount,
    required this.totalCount,
    required this.percentage,
    required this.status,
  });

  factory DomainMasteryPerformance.fromMap(Map<String, dynamic> map) {
    return DomainMasteryPerformance(
      domain: map['domain']?.toString() ?? '',
      correctCount: (map['correctCount'] ?? 0) as int,
      totalCount: (map['totalCount'] ?? 0) as int,
      percentage: ((map['percentage'] ?? 0.0) as num).toDouble(),
      status: map['status']?.toString() ?? 'NEEDS_PRACTICE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'domain': domain,
      'correctCount': correctCount,
      'totalCount': totalCount,
      'percentage': percentage,
      'status': status,
    };
  }
}

/// Comprehensive Post-Assessment Evaluation Result Model.
class PostAssessmentResult {
  final String zoneIdentifier; // 'ZONE_1' | 'ZONE_2' | 'ZONE_3'
  final int levelMilestone; // 20, 40, or 60
  final int score;
  final int maxScore;
  final double percentage;
  final double preAssessmentPercentage;
  final double growthPercentage;
  final Map<String, DomainMasteryPerformance> domainPerformances;
  final Map<String, String> masteryOverview;
  final List<String> earnedBadges;
  final DateTime completedAt;

  const PostAssessmentResult({
    required this.zoneIdentifier,
    required this.levelMilestone,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.preAssessmentPercentage,
    required this.growthPercentage,
    required this.domainPerformances,
    required this.masteryOverview,
    required this.earnedBadges,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'zoneIdentifier': zoneIdentifier,
      'levelMilestone': levelMilestone,
      'score': score,
      'maxScore': maxScore,
      'percentage': percentage,
      'preAssessmentPercentage': preAssessmentPercentage,
      'growthPercentage': growthPercentage,
      'domainPerformances':
          domainPerformances.map((k, v) => MapEntry(k, v.toMap())),
      'masteryOverview': masteryOverview,
      'earnedBadges': earnedBadges,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
