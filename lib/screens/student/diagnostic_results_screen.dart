import 'package:flutter/material.dart';
import '../../core/models/placement_result.dart';
import '../../core/theme/app_colors.dart';
import 'adventure_map_screen.dart';

/// Diagnostic Results Screen - displays comprehensive placement results
///
/// Shows:
/// - Student score and percentage
/// - Placement category with description
/// - Starting level
/// - Content pool access
/// - Performance indicators
/// - Start Adventure button to proceed to the Adventure Map
class DiagnosticResultsScreen extends StatefulWidget {
  final PlacementResult placement;
  final int correctAnswers;
  final int totalQuestions;
  final String studentName;
  final VoidCallback? onContinue;

  const DiagnosticResultsScreen({
    super.key,
    required this.placement,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.studentName,
    this.onContinue,
  });

  @override
  State<DiagnosticResultsScreen> createState() =>
      _DiagnosticResultsScreenState();
}

class _DiagnosticResultsScreenState extends State<DiagnosticResultsScreen> {
  void _onStartLevel() {
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdventureMapScreen(),
          settings: RouteSettings(
            name: '/adventure_map',
            // Pass the placement data so AdventureMapScreen can show the
            // one-time Welcome Modal with real student info.
            arguments: {
              'fromDiagnostic': true,
              'studentName': widget.studentName,
              'placementCategory': widget.placement.category,
              'startingLevel': widget.placement.startingLevel,
            },
          ),
        ),
      );
    }
  }

  // ─── Category helpers ─────────────────────────────────────────────────────

  Color _getCategoryColor() {
    switch (widget.placement.category.toLowerCase()) {
      case 'advanced':
      case 'mastery':
        return const Color(0xFF2196F3);
      case 'intermediate':
        return const Color(0xFF4CAF50);
      case 'foundation':
      case 'beginner':
      default:
        return const Color(0xFFFF9800);
    }
  }

  String _getCategoryEmoji() {
    switch (widget.placement.category.toLowerCase()) {
      case 'advanced':
      case 'mastery':
        return '🏆';
      case 'intermediate':
        return '⭐';
      case 'foundation':
      case 'beginner':
      default:
        return '🌱';
    }
  }

  String _getCategoryDescription() {
    switch (widget.placement.category.toLowerCase()) {
      case 'advanced':
      case 'mastery':
        return 'Outstanding work! You demonstrated advanced math mastery — starting at Level ${widget.placement.startingLevel}!';
      case 'intermediate':
        return 'Great job! You have solid foundational skills — starting at Level ${widget.placement.startingLevel}!';
      case 'foundation':
      case 'beginner':
      default:
        return 'Good start! You will build strong math fundamentals — starting at Level ${widget.placement.startingLevel}!';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: categoryColor.withValues(alpha: 0.1),
              elevation: 0,
              title: const Text(
                'Assessment Results',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Score circle
                    _buildScoreCircle(categoryColor),
                    const SizedBox(height: 32),

                    // Category badge
                    _buildCategoryBadge(categoryColor),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      _getCategoryDescription(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Detailed breakdown card
                    _buildDetailCard(),
                    const SizedBox(height: 24),

                    // Content pool card
                    _buildContentPoolCard(),
                    const SizedBox(height: 32),

                    // ── START LEVEL Rive animated button ─────────────────
                    _buildStartLevelButton(categoryColor),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Button redirecting the student to the Adventure Map with their assessment results.
  Widget _buildStartLevelButton(Color categoryColor) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _onStartLevel,
        style: ElevatedButton.styleFrom(
          backgroundColor: categoryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: categoryColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_rounded, size: 22, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'START ADVENTURE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildScoreCircle(Color color) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 3),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getCategoryEmoji(),
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.placement.scorePercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.correctAnswers}/${widget.totalQuestions} Correct',
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        widget.placement.category.toUpperCase(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Category & Starting Level
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '📍',
                  label: 'Placement',
                  value: widget.placement.category,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  icon: '🎯',
                  label: 'Starting Level',
                  value: 'Level ${widget.placement.startingLevel}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Correct / Incorrect
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '✅',
                  label: 'Correct',
                  value: '${widget.correctAnswers}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  icon: '❌',
                  label: 'Incorrect',
                  value: '${widget.totalQuestions - widget.correctAnswers}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildContentPoolCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📚', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Your Learning Path',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "You'll have access to these content levels:",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.placement.contentPool.map((grade) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
