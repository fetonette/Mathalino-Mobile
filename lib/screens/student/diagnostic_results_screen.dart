import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/placement_result.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/diagnostic_provider.dart';
import 'adventure_map_screen.dart';

/// Diagnostic Results Screen - displays placement results in one of 3 themes:
/// Beginner (Orange), Intermediate (Green), or Advanced (Blue).
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
    try {
      context.read<DiagnosticProvider>().resetDiagnostic();
    } catch (_) {}
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdventureMapScreen(),
          settings: RouteSettings(
            name: '/adventure_map',
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

  @override
  Widget build(BuildContext context) {
    final theme = _ResultTheme.fromCategory(widget.placement.category);
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = math.min(1.0, screenWidth / 390.0);

    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 96, // Ensure space for pinned bottom button
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Top Bar
                        _buildTopBar(),
                        const SizedBox(height: 12),

                        // 2. Score Ring + Top Badge + Stars + Mascot Area
                        _buildScoreHeader(theme, scale),
                        const SizedBox(height: 16),

                        // 3. Category Level Badge
                        _buildLevelBadge(theme),
                        const SizedBox(height: 14),

                        // 4. Message Description
                        _buildMessage(theme),
                        const SizedBox(height: 20),

                        // 5. "Your Performance" Card
                        _buildPerformanceCard(theme),
                        const SizedBox(height: 16),

                        // 6. "Your Learning Path" Card
                        _buildLearningPathCard(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Pinned Bottom Action Button ("Start Adventure")
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: theme.buttonShadow,
                          offset: const Offset(0, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _onStartLevel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.buttonBg,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Adventure',
                            style: AppTokens.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Round 44px Back button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE0E7FF),
                width: 2,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTokens.primaryIndigo,
                size: 22,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  _onStartLevel();
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),

          // Title
          Text(
            'Assessment Results',
            style: AppTokens.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTokens.bodyText,
            ),
          ),

          // Spacer for centering
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ─── Score Header Area ───────────────────────────────────────────────────
  Widget _buildScoreHeader(_ResultTheme theme, double scale) {
    const ringSize = 176.0;

    return SizedBox(
      height: 205,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Decorative Stars
          Positioned(
            left: 28 * scale,
            top: 45,
            child: Icon(
              Icons.star_rounded,
              size: 18 * scale,
              color: theme.starPrimary,
            ),
          ),
          Positioned(
            left: 56 * scale,
            top: 140,
            child: Icon(
              Icons.star_rounded,
              size: 14 * scale,
              color: theme.starSecondary,
            ),
          ),

          // Center Score Ring
          Positioned(
            top: 12,
            child: Container(
              width: ringSize,
              height: ringSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  percentage: widget.placement.scorePercentage,
                  trackColor: theme.ringTrack,
                  progressColor: theme.accent,
                  strokeWidth: 12,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        '${widget.placement.scorePercentage.toStringAsFixed(1)}%',
                        style: AppTokens.baloo2(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: theme.dark,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.correctAnswers}/${widget.totalQuestions} Correct',
                        style: AppTokens.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 56px Top Badge (sitting directly on top of ring)
          Positioned(
            top: 0,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: theme.dark,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  theme.badgeIcon,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Result Mascot (Right of Ring)
          Positioned(
            right: 12 * scale,
            top: 36,
            child: SizedBox(
              width: 72 * scale,
              height: 110 * scale,
              child: Image.asset(
                theme.mascotAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  theme.mascotFallback,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'image/MLOGO.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Level Badge ──────────────────────────────────────────────────────────
  Widget _buildLevelBadge(_ResultTheme theme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: theme.softTint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 22,
            color: theme.dark,
          ),
          const SizedBox(width: 6),
          Text(
            theme.categoryName,
            style: AppTokens.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.dark,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Text ─────────────────────────────────────────────────────────
  Widget _buildMessage(_ResultTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTokens.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTokens.secondaryText,
            height: 1.4,
          ),
          children: [
            TextSpan(text: theme.messagePrefix),
            TextSpan(
              text: 'Level ${widget.placement.startingLevel}',
              style: AppTokens.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: theme.dark,
              ),
            ),
            const TextSpan(text: '!'),
          ],
        ),
      ),
    );
  }

  // ─── Performance Card ─────────────────────────────────────────────────────
  Widget _buildPerformanceCard(_ResultTheme theme) {
    final incorrectCount = widget.totalQuestions - widget.correctAnswers;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE0E7FF),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Performance',
            style: AppTokens.baloo2(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTokens.bodyText,
            ),
          ),
          const SizedBox(height: 10),

          // 2x2 Grid with gap 8
          Row(
            children: [
              // Placement Tile
              Expanded(
                flex: 12,
                child: _buildTile(
                  theme: theme,
                  iconWidget: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.softTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: theme.dark,
                    ),
                  ),
                  label: 'Placement',
                  value: widget.placement.category,
                  valueColor: theme.dark,
                ),
              ),
              const SizedBox(width: 8),

              // Starting Level Tile
              Expanded(
                flex: 11,
                child: _buildTile(
                  theme: theme,
                  iconWidget: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      size: 16,
                      color: AppTokens.primaryIndigo,
                    ),
                  ),
                  label: 'Starting level',
                  value: 'Level ${widget.placement.startingLevel}',
                  valueColor: AppTokens.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Correct Tile
              Expanded(
                flex: 12,
                child: _buildTile(
                  theme: theme,
                  iconWidget: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Color(0xFF047857),
                    ),
                  ),
                  label: 'Correct',
                  value: '${widget.correctAnswers}',
                  valueColor: const Color(0xFF047857),
                ),
              ),
              const SizedBox(width: 8),

              // Incorrect Tile
              Expanded(
                flex: 11,
                child: _buildTile(
                  theme: theme,
                  iconWidget: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  label: 'Incorrect',
                  value: '$incorrectCount',
                  valueColor: const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required _ResultTheme theme,
    required Widget iconWidget,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.tileBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.tileBorder,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.secondaryText,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Learning Path Card ───────────────────────────────────────────────────
  Widget _buildLearningPathCard(_ResultTheme theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.pathCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.tileBorder,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: theme.dark,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Learning Path',
                style: AppTokens.baloo2(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "You'll have access to these content levels:",
            style: AppTokens.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.placement.contentPool.map((grade) {
              return Container(
                height: 32,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.accent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      grade,
                      style: AppTokens.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: theme.dark,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter for Score Ring ──────────────────────────────────────────
class _ScoreRingPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ScoreRingPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    if (percentage > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle =
          (percentage.clamp(0.0, 100.0) / 100.0) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ─── Theme Data Model ───────────────────────────────────────────────────────
class _ResultTheme {
  final String categoryName;
  final Color accent;
  final Color dark;
  final Color softTint;
  final Color ringTrack;
  final Color tileBg;
  final Color tileBorder;
  final Color pathCardBg;
  final Color buttonBg;
  final Color buttonShadow;
  final Color starPrimary;
  final Color starSecondary;
  final IconData badgeIcon;
  final String mascotAsset;
  final String mascotFallback;
  final String messagePrefix;

  const _ResultTheme({
    required this.categoryName,
    required this.accent,
    required this.dark,
    required this.softTint,
    required this.ringTrack,
    required this.tileBg,
    required this.tileBorder,
    required this.pathCardBg,
    required this.buttonBg,
    required this.buttonShadow,
    required this.starPrimary,
    required this.starSecondary,
    required this.badgeIcon,
    required this.mascotAsset,
    required this.mascotFallback,
    required this.messagePrefix,
  });

  static _ResultTheme fromCategory(String category) {
    final cat = category.toLowerCase().trim();
    if (cat == 'advanced' || cat == 'mastery') {
      return const _ResultTheme(
        categoryName: 'ADVANCED',
        accent: Color(0xFF2B7FE8),
        dark: Color(0xFF0B4FA8),
        softTint: Color(0xFFDBEAFE),
        ringTrack: Color(0xFFCFE3FB),
        tileBg: Color(0xFFF3F8FF),
        tileBorder: Color(0xFFCFE3FB),
        pathCardBg: Color(0xFFEFF6FF),
        buttonBg: Color(0xFF1473E6),
        buttonShadow: Color(0xFF0B4FA8),
        starPrimary: Color(0xFFBFDBFE),
        starSecondary: Color(0xFF93C5FD),
        badgeIcon: Icons.emoji_events_rounded,
        mascotAsset: 'assets/mascots/mascot-result-advanced.png',
        mascotFallback: 'assets/mascots/mascot_lightbulb.png',
        messagePrefix:
            'Outstanding work! You demonstrated advanced math mastery — starting at ',
      );
    } else if (cat == 'intermediate') {
      return const _ResultTheme(
        categoryName: 'INTERMEDIATE',
        accent: Color(0xFF10B981),
        dark: Color(0xFF047857),
        softTint: Color(0xFFD1FAE5),
        ringTrack: Color(0xFFCFF5E3),
        tileBg: Color(0xFFF3FCF8),
        tileBorder: Color(0xFFCFF5E3),
        pathCardBg: Color(0xFFECFDF5),
        buttonBg: Color(0xFF047857),
        buttonShadow: Color(0xFF064E3B),
        starPrimary: Color(0xFFA7F3D0),
        starSecondary: Color(0xFF6EE7B7),
        badgeIcon: Icons.rocket_launch_rounded,
        mascotAsset: 'assets/mascots/mascot-result-intermediate.png',
        mascotFallback: 'assets/mascots/mascot_thumbs_up.png',
        messagePrefix:
            'Great job! You have solid math skills — starting at ',
      );
    } else {
      // Beginner / Foundation
      return const _ResultTheme(
        categoryName: 'BEGINNER',
        accent: Color(0xFFF59E0B),
        dark: Color(0xFFB45309),
        softTint: Color(0xFFFEF3C7),
        ringTrack: Color(0xFFFDE9C4),
        tileBg: Color(0xFFFFFBF2),
        tileBorder: Color(0xFFFDE9C4),
        pathCardBg: Color(0xFFFFF7E6),
        buttonBg: Color(0xFFD97706),
        buttonShadow: Color(0xFF92400E),
        starPrimary: Color(0xFFFDE68A),
        starSecondary: Color(0xFFFBBF24),
        badgeIcon: Icons.eco_rounded,
        mascotAsset: 'assets/mascots/mascot-result-beginner.png',
        mascotFallback: 'assets/mascots/mascot_pencil.png',
        messagePrefix:
            'Good start! You will build strong math fundamentals — starting at ',
      );
    }
  }
}
