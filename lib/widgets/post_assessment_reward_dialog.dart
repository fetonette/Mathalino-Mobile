import 'package:flutter/material.dart';

import '../core/models/post_assessment_result.dart';
import '../core/theme/app_colors.dart';

/// Modal dialog celebrating milestone achievement and displaying post-assessment
/// results, growth percentage, domain mastery breakdown, and unlocked badges.
class PostAssessmentRewardDialog extends StatelessWidget {
  final PostAssessmentResult result;
  final VoidCallback onContinue;

  const PostAssessmentRewardDialog({
    super.key,
    required this.result,
    required this.onContinue,
  });

  /// Static helper to display the dialog with smooth scale animation.
  static Future<void> show(
    BuildContext context, {
    required PostAssessmentResult result,
    required VoidCallback onContinue,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'PostAssessmentDialog',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => PostAssessmentRewardDialog(
        result: result,
        onContinue: onContinue,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value,
          child: child,
        );
      },
    );
  }

  String get _milestoneTitle {
    switch (result.levelMilestone) {
      case 20:
        return 'Zone 1 Conquered! 🌲';
      case 40:
        return 'Zone 2 Mastered! 🏜️';
      case 60:
        return 'Mathalino Champion! 👑';
      default:
        return 'Zone Milestone Complete! 🏆';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'MASTERED':
        return const Color(0xFF2E7D32); // Green
      case 'PROFICIENT':
        return const Color(0xFF1976D2); // Blue
      case 'DEVELOPING':
        return const Color(0xFFF57C00); // Orange
      case 'NEEDS_PRACTICE':
      default:
        return const Color(0xFFD32F2F); // Red
    }
  }

  String _formatBadgeName(String badgeId) {
    switch (badgeId) {
      case 'zone_1_master':
        return 'Zone 1 Master 🏅';
      case 'zone_2_master':
        return 'Zone 2 Master 🎖️';
      case 'math_wizard':
        return 'Math Wizard 🧙‍♂️';
      case 'boss_slayer':
        return 'Boss Slayer ⚔️';
      default:
        return badgeId.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositiveGrowth = result.growthPercentage >= 0;
    final growthSign = isPositiveGrowth ? '+' : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3F51B5), Color(0xFF7986CB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🎉 MILESTONE ACHIEVED 🎉',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _milestoneTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Score & Growth Metrics
                    Row(
                      children: [
                        // Post-Assessment Score Box
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD0D9FF)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Post-Test Score',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${result.percentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '${result.score}/${result.maxScore} Correct',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Growth Percentage Box
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isPositiveGrowth
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPositiveGrowth
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFFFCC80),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Growth vs Diagnostic',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$growthSign${result.growthPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: isPositiveGrowth
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFEF6C00),
                                  ),
                                ),
                                Text(
                                  'Baseline: ${result.preAssessmentPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Domain Mastery Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Domain Mastery Overview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Domain List
                    ...result.domainPerformances.values.map((domainPerf) {
                      final statusColor = _getStatusColor(domainPerf.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      domainPerf.domain,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${domainPerf.correctCount}/${domainPerf.totalCount} correct (${domainPerf.percentage.toStringAsFixed(0)}%)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  domainPerf.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Unlocked Badges Section
                    if (result.earnedBadges.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Newly Unlocked Badges',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: result.earnedBadges.map((badgeId) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFD54F)),
                            ),
                            child: Text(
                              _formatBadgeName(badgeId),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8D6E63),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Continue Journey 🚀',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
