import '../models/placement_result.dart';

/// Placement Service for Mathalino Student Diagnostic Assessment
/// Determines student diagnostic tier/category, starting level, and accessible content pool.
class PlacementService {
  /// Calculate Placement Result based on points earned vs total possible points
  PlacementResult calculatePlacement(int pointsEarned, int totalPossiblePoints) {
    if (totalPossiblePoints <= 0) {
      return const PlacementResult(
        category: 'Foundation',
        startingLevel: 1,
        contentPool: ['Grade 1', 'Grade 2', 'Grade 3'],
        contentPoolLabel: 'Grade 1-3',
        scorePercentage: 0.0,
      );
    }

    final double percentage = (pointsEarned / totalPossiblePoints) * 100.0;

    if (percentage >= 80.0) {
      // Rule III: S >= 80 -> Advanced Tier (Level 41, Grade 1-6 Advanced)
      return PlacementResult(
        category: 'Advanced',
        startingLevel: 41,
        contentPool: const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6 Advanced'
        ],
        contentPoolLabel: 'Grade 1-6 Advanced',
        scorePercentage: percentage,
      );
    } else if (percentage >= 50.0) {
      // Rule II: 50 <= S <= 79 -> Intermediate Tier (Level 21, Grade 1-6)
      return PlacementResult(
        category: 'Intermediate',
        startingLevel: 21,
        contentPool: const [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6'
        ],
        contentPoolLabel: 'Grade 1-6 Shuffled',
        scorePercentage: percentage,
      );
    } else {
      // Rule I: S < 50 -> Foundation Tier (Level 1, Grade 1-3)
      return PlacementResult(
        category: 'Foundation',
        startingLevel: 1,
        contentPool: const ['Grade 1', 'Grade 2', 'Grade 3'],
        contentPoolLabel: 'Grade 1-3',
        scorePercentage: percentage,
      );
    }
  }
}

