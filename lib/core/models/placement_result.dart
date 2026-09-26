/// Placement Result Model detailing category, starting level, and accessible content pool
class PlacementResult {
  final String category; // 'Beginner' | 'Intermediate' | 'Advanced' | 'Mastery'
  final int startingLevel; // 1, 21, or 41
  final List<String> contentPool; // e.g. ['Grade 1', 'Grade 2', 'Grade 3']
  final String contentPoolLabel; // Spec label: 'Grade 1-3', 'Grade 1-6 Shuffled', etc.
  final double scorePercentage;

  const PlacementResult({
    required this.category,
    required this.startingLevel,
    required this.contentPool,
    required this.contentPoolLabel,
    required this.scorePercentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'startingLevel': startingLevel,
      'contentPool': contentPool,
      'contentPoolLabel': contentPoolLabel,
      'scorePercentage': scorePercentage,
    };
  }

  @override
  String toString() {
    return 'PlacementResult(category: $category, startingLevel: $startingLevel, scorePercentage: ${scorePercentage.toStringAsFixed(1)}%, contentPoolLabel: $contentPoolLabel)';
  }
}
