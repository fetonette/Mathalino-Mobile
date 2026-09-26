import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Visual treatment for each Mathalino difficulty label (§6 UI guidelines).
///
/// Zone 2's 'Moderate' and 'Moderate (Multi-Step)' must read as "harder than
/// Preparation" WITHOUT borrowing the Hard/Super-Hardcore boss iconography
/// (no padlock-gate visuals, no star/boss icon): Intermediate levels unlock
/// in a straight line.
class DifficultyPresentation {
  final IconData icon;
  final Color color;
  final String tooltip;

  const DifficultyPresentation({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  static const Map<String, DifficultyPresentation> _byDifficulty = {
    'Preparation': DifficultyPresentation(
      icon: Icons.edit_note,
      color: AppColors.info,
      tooltip: 'Practice level',
    ),
    // Zone 2 — harder than Preparation, still gate-free.
    'Moderate': DifficultyPresentation(
      icon: Icons.trending_up,
      color: AppColors.warning,
      tooltip: 'Moderate — multi-grade practice, unlocks straight away',
    ),
    'Moderate (Multi-Step)': DifficultyPresentation(
      icon: Icons.stairs,
      color: AppColors.accentDark,
      tooltip: 'Multi-step challenge — combines several skills, no gate',
    ),
    // Boss tiers keep their dedicated iconography.
    'Hard': DifficultyPresentation(
      icon: Icons.local_fire_department,
      color: AppColors.error,
      tooltip: 'Hard gate — failure starts remediation',
    ),
    'Super Hardcore': DifficultyPresentation(
      icon: Icons.star,
      color: Color(0xFF7C3AED), // deep violet boss accent
      tooltip: 'Super Hardcore boss — failure starts remediation',
    ),
    'Final Boss': DifficultyPresentation(
      icon: Icons.workspace_premium,
      color: AppColors.errorDark,
      tooltip: 'Final Boss of Mathalino',
    ),
  };

  /// Fallback for unknown labels renders as a neutral Preparation-style chip.
  static DifficultyPresentation of(String difficulty) =>
      _byDifficulty[difficulty] ?? _byDifficulty['Preparation']!;
}

/// Small rounded chip showing a level's difficulty label with its icon and
/// colour treatment. Used by the gameplay screens' app bars.
class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final presentation = DifficultyPresentation.of(difficulty);
    return Tooltip(
      message: presentation.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: presentation.color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(presentation.icon, size: 16, color: presentation.color),
            const SizedBox(width: 5),
            Text(
              difficulty,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: presentation.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}